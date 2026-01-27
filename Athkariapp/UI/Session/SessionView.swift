import SwiftUI
import UIKit

struct SessionView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionViewModel?

    let slotKey: SlotKey

    var body: some View {
        Group {
            if let viewModel = viewModel {
                SessionContent(viewModel: viewModel, onDismiss: { dismiss() })
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func setupViewModel() {
        let settings = try? container.makeSettingsRepository().getSettings()
        viewModel = SessionViewModel(
            slotKey: slotKey,
            sessionRepository: container.makeSessionRepository(),
            dhikrRepository: container.makeDhikrRepository(),
            settingsRepository: container.makeSettingsRepository(),
            hapticsService: container.hapticsService,
            hapticsEnabled: settings?.hapticsEnabled ?? true
        )
    }
}

struct SessionContent: View {
    @Bindable var viewModel: SessionViewModel
    let onDismiss: () -> Void
    
    // Share function using UIKit activity controller
    private func shareCurrentDhikr() {
        let text = viewModel.shareText()
        guard !text.isEmpty else { return }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                topBar
                
                Spacer()
                
                VStack(spacing: 32) {
                    dhikrCard
                    counterSection
                }
                
                Spacer()
                
                bottomActions
            }
        }
        .task {
            await viewModel.loadSession()
        }
        .sheet(isPresented: $viewModel.showDhikrSwitcher) {
            DhikrSwitcherSheet(
                dhikrList: viewModel.dhikrList,
                currentDhikr: viewModel.currentDhikr,
                onSelect: viewModel.switchDhikr
            )
            .presentationDetents([.medium, .large])
        }
        .alert("إعادة ضبط", isPresented: $viewModel.showResetConfirmation) {
            Button("إلغاء", role: .cancel) { }
            Button("إعادة ضبط", role: .destructive) {
                viewModel.reset()
            }
        } message: {
            Text("هل تريد إعادة ضبط العداد إلى الصفر؟")
        }
        .contentShape(Rectangle()) // Ensure empty areas are tappable
        .onTapGesture {
            viewModel.increment()
        }
        .overlay {
            overlays
        }
    }
    
    // MARK: - Sub-views
    
    private var backgroundView: some View {
        ZStack {
            AppColors.sessionBackground.ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.onboardingPrimary.opacity(0.15),
                    AppColors.sessionBackground.opacity(0)
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            AmbientBackground()
                .opacity(0.6)
                .blur(radius: 60)
        }
    }
    
    private var topBar: some View {
        HStack {
            Button {
                viewModel.isCompleted ? onDismiss() : (viewModel.showFinishConfirmation = true)
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
            }
            
            Spacer()
            
            if !viewModel.dhikrList.isEmpty {
                HStack(spacing: 6) {
                    Text("الذكر \(viewModel.currentDhikrIndex + 1) من \(viewModel.dhikrList.count)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2)).frame(width: 30, height: 4)
                        Capsule()
                            .fill(AppColors.onboardingPrimary)
                            .frame(width: 30 * (Double(viewModel.currentDhikrIndex + 1) / Double(viewModel.dhikrList.count)), height: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Material.ultraThin)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            
            Spacer()
            
            Button {
                viewModel.showDhikrSwitcher = true
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "list.bullet")
                            .font(.headline)
                            .foregroundStyle(.white)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var dhikrCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            VStack(spacing: 24) {
                if let dhikr = viewModel.currentDhikr {
                    Spacer(minLength: 0)
                    
                    Text(dhikr.text)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.4)
                        .padding(.horizontal, 4)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                        .id(dhikr.id)
                    
                    Spacer(minLength: 0)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    VStack(spacing: 12) {
                        if let benefit = dhikr.benefit, !benefit.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(AppColors.onboardingPrimary)
                                    .font(.caption)
                                    .padding(.top, 2)
                                
                                Text(benefit)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        if let reference = dhikr.reference, !reference.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "book.closed.fill")
                                    .font(.caption2)
                                Text(reference)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(AppColors.textGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(24)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
    }
    
    private var counterSection: some View {
        HStack(spacing: 32) {
            Button {
                withAnimation { viewModel.moveToPrevious() }
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "arrow.backward")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }
            
            CounterCircle(
                currentCount: viewModel.currentCount,
                targetCount: viewModel.targetCount,
                size: 200,
                accentColor: AppColors.onboardingPrimary
            ) {
                viewModel.increment()
            }
            
            Button {
                withAnimation { viewModel.moveToNext() }
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }
        }
    }
    
    private var bottomActions: some View {
        HStack(spacing: 40) {
            Button {
                viewModel.showResetConfirmation = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                    Text("إعادة")
                        .font(.caption2)
                }
                .foregroundStyle(AppColors.textGray)
            }
            
            Button {
                shareCurrentDhikr()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text("مشاركة")
                        .font(.caption2)
                }
                .foregroundStyle(AppColors.textGray)
            }
        }
        .padding(.bottom, 50)
    }
    
    @ViewBuilder
    private var overlays: some View {
        ZStack {
            if viewModel.showCompletionCelebration {
                CompletionCelebration {
                    viewModel.showCompletionCelebration = false
                    onDismiss()
                }
                .zIndex(2)
            }
            
            if viewModel.showFinishConfirmation {
                ExitConfirmationView(
                    onResume: { viewModel.showFinishConfirmation = false },
                    onExit: {
                        viewModel.showFinishConfirmation = false
                        viewModel.endSession()
                        onDismiss()
                    }
                )
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showFinishConfirmation)
        .animation(.easeOut(duration: 0.2), value: viewModel.showCompletionCelebration)
    }
}


// MARK: - Helper Views

struct CompletionCelebration: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(AppColors.appPrimary)

                Text("أحسنت!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("لقد أكملت أذكارك")
                    .font(.title3)
                    .foregroundStyle(.gray)

                Button {
                    onDismiss()
                } label: {
                    Text("إنهاء")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 16)
            }
        }
        .transition(.opacity)
    }
}

struct ExitConfirmationView: View {
    let onResume: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onResume() }
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.onboardingPrimary)
                        .padding(.top, 8)
                    
                    Text("هل تريد إنهاء الجلسة؟")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Text("لم تكمل جميع الأذكار بعد.\nسيتم حفظ تقدمك الحالي.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineSpacing(4)
                }
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button(action: onExit) {
                        Text("نعم، خروج")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    Button(action: onResume) {
                        Text("متابعة")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.onboardingPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(AppColors.sessionSurface.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
            .padding(24)
        }
        .transition(.opacity)
    }
}

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            // Blob 1
             Circle()
                .fill(AppColors.sessionPrimary.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(y: 100)
        }
    }
}


 
// Dummy struct to fix compilation if Constants not defined
enum Constants {
    static let showLockScreenHint = true
}

// MARK: - Dhikr Switcher Sheet
struct DhikrSwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    let dhikrList: [DhikrItem]
    let currentDhikr: DhikrItem?
    let onSelect: (DhikrItem) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(dhikrList) { dhikr in
                        Button {
                            onSelect(dhikr)
                            dismiss()
                        } label: {
                            DhikrSwitcherRow(dhikr: dhikr, isSelected: dhikr.id == currentDhikr?.id)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(AppColors.homeBackground.ignoresSafeArea())
            .navigationTitle("اختر الذكر")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.textGray)
                    }
                }
            }
            .toolbarBackground(AppColors.homeBackground, for: .navigationBar)
        }
    }
}

private struct DhikrSwitcherRow: View {
    let dhikr: DhikrItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Count Badge (Icon equivalent)
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppColors.onboardingPrimary.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 50, height: 50)
                
                Text("\(dhikr.repeatCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? AppColors.onboardingPrimary : .white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) { // Leading alignment for text
                Text(dhikr.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let reference = dhikr.reference, !reference.isEmpty {
                    Text(reference)
                        .font(.caption)
                        .foregroundStyle(AppColors.textGray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Selection Indicator with Checkmark
            ZStack {
                Circle()
                    .fill(isSelected ? AppColors.onboardingPrimary : Color.clear)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .strokeBorder(isSelected ? AppColors.onboardingPrimary : Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.onboardingSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? AppColors.onboardingPrimary.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: isSelected ? AppColors.onboardingPrimary.opacity(0.15) : Color.clear, radius: 10)
    }
}



#Preview {
    NavigationStack {
        SessionView(slotKey: .morning)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
