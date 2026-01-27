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
            hapticsService: container.hapticsService,
            hapticsEnabled: settings?.hapticsEnabled ?? true,
            fontSize: settings?.fontSize ?? 1.0
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
            // Background
            ZStack {
                AppColors.sessionBackground.ignoresSafeArea()
                
                // Subtle Gradient to match Onboarding premium feel
                RadialGradient(
                    gradient: Gradient(colors: [
                        AppColors.sessionPrimary.opacity(0.15),
                        AppColors.sessionBackground.opacity(0)
                    ]),
                    center: .top,
                    startRadius: 100,
                    endRadius: 600
                )
                .ignoresSafeArea()
            }
            
            // Ambient Blobs
            AmbientBackground()

            VStack(spacing: 0) {
                // Header
                sessionHeader

                Spacer()

                // Main Content (Dhikr + Counter)
                VStack(spacing: 32) {
                    
                    // Dhikr Text
                    if let dhikr = viewModel.currentDhikr {
                        Text(dhikr.text)
                            .font(.system(size: 32 * viewModel.fontSize, weight: .bold)) // Scaled Font Size
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .lineSpacing(10)
                            .padding(.horizontal, 24)
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    }
                    
                    // Counter Ring (Centerpiece)
                    GeometryReader { geometry in
                        let ringSize = min(geometry.size.width * 0.7, 280)
                        ZStack {
                            // Enhanced Glow behind
                            Circle()
                                .fill(AppColors.sessionPrimary.opacity(0.15))
                                .frame(width: ringSize * 0.9, height: ringSize * 0.9)
                                .blur(radius: 50)
                            
                            // Track
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 4)
                                .frame(width: ringSize, height: ringSize)
                            
                            // Progress with enhanced shadow
                            Circle()
                                .trim(from: 0, to: viewModel.progress)
                                .stroke(
                                    AppColors.sessionPrimary,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: ringSize, height: ringSize)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: AppColors.sessionPrimary.opacity(0.4), radius: 15, x: 0, y: 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.progress)
                            
                            // Inner Info
                            VStack(spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(viewModel.currentCount.arabicNumeral)
                                        .font(.system(size: ringSize * 0.27, weight: .bold))
                                        .foregroundStyle(.white)
                                        .contentTransition(.numericText())
                                    
                                    Text("/ \(viewModel.targetCount.arabicNumeral)")
                                        .font(.system(size: ringSize * 0.1, weight: .medium))
                                        .foregroundStyle(Color.gray)
                                }
                                
                                Text("اضغط للعد")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppColors.sessionPrimary.opacity(0.8))
                                    .tracking(2)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Circle())
                        .onTapGesture {
                            viewModel.increment()
                        }
                    }
                    .frame(height: 280)
                }

                Spacer()

                // Actions & Hint
                VStack(spacing: 24) {
                    // Hint with design-compliant style
                    if Constants.showLockScreenHint {
                         HStack(spacing: 8) {
                            Image(systemName: "lock.circle")
                                .font(.caption)
                            Text("يظهر هذا الذكر في شاشة القفل أثناء القراءة")
                        }
                        .font(.caption)
                        .foregroundStyle(AppColors.textGray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Grid Controls
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        SessionControlButton(icon: "xmark", title: "إنهاء") {
                            // Check if session is truly complete (all dhikr done, not just current)
                            if viewModel.isCompleted {
                                onDismiss()
                            } else {
                                viewModel.showFinishConfirmation = true
                            }
                        }
                        
                        SessionControlButton(icon: "arrow.counterclockwise", title: "إعادة ضبط") {
                            viewModel.showResetConfirmation = true
                        }
                        
                        SessionControlButton(icon: "arrow.left.arrow.right", title: "تبديل") {
                            viewModel.showDhikrSwitcher = true
                        }
                        
                        // Share button
                        SessionControlButton(icon: "square.and.arrow.up", title: "مشاركة") {
                            shareCurrentDhikr()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 120) // Extra padding for tab bar
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
        .alert("إنهاء الجلسة", isPresented: $viewModel.showFinishConfirmation) {
            Button("إلغاء", role: .cancel) { }
            Button("إنهاء", role: .destructive) {
                viewModel.showCompletionCelebration = false // Ensure celebration doesn't show
                viewModel.endSession()
                onDismiss()
            }
        } message: {
            Text("لم تكمل جميع الأذكار. هل تريد الإنهاء على أي حال؟")
        }
        .contentShape(Rectangle()) // Ensure empty areas are tappable
        .onTapGesture {
            viewModel.increment()
        }

        .overlay {
            if viewModel.showCompletionCelebration {
                CompletionCelebration {
                    viewModel.showCompletionCelebration = false
                    onDismiss()
                }
            }
        }
    }

    // MARK: - Header
    private var sessionHeader: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chevron.right") // Match design RTL
                            .foregroundStyle(AppColors.textGray)
                    )
            }
            // In RTL design, back button is on Right usually?
            // code.html has chevron_right on the left... actually `dir="rtl"` so first button is Right visually?
            // HTML: <header class="flex ... justify-between"> <button chevron_right> </button> ... <button volume> </button> </header>
            // In RTL, the first child is on the Right. Wait.
            // Flex direction default is row.
            // First child (chevron_right) -> Right side.
            // Text center.
            // Last child (volume) -> Left side.
            // So my SwiftUI HStack will be Right-to-Left automatically if usage environment is RTL.
            // So Button 1 (Dismiss) is first in code -> Right side.
            
            Spacer()

            Text("جلسة ذكر")
                .font(.caption)
                .bold()
                .foregroundStyle(AppColors.sessionPrimary)
                .textCase(.uppercase)
                .tracking(1)

            Spacer()
            
            // Empty spacer to balance header (sound icon removed)
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

// MARK: - Helper Views

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

struct SessionControlButton: View {
    let icon: String
    let title: String
    var color: Color = AppColors.textGray
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.sessionSurface)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(title == "إنهاء" ? .red : .white)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textGray)
            }
        }
        .buttonStyle(ScaleButtonStyle())
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

// MARK: - Completion Celebration
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

#Preview {
    NavigationStack {
        SessionView(slotKey: .morning)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
