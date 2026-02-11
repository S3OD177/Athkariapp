import SwiftUI
import UIKit

struct SessionView: View {
    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionViewModel?
    @Binding var pendingLaunchAction: SessionLaunchAction

    let slotKey: SlotKey

    init(slotKey: SlotKey, pendingLaunchAction: Binding<SessionLaunchAction>) {
        self.slotKey = slotKey
        self._pendingLaunchAction = pendingLaunchAction
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                SessionContent(
                    viewModel: viewModel,
                    pendingLaunchAction: $pendingLaunchAction,
                    onDismiss: { dismiss() }
                )
            } else {
                ZStack {
                    AppColors.homeBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
                .task { setupViewModel() }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .environment(\.locale, Locale(identifier: "en")) // Force Western numerals (123) for counters
    }

    private func setupViewModel() {
        let settings = try? container.makeSettingsRepository().getSettings()
        viewModel = SessionViewModel(
            slotKey: slotKey,
            sessionRepository: container.makeSessionRepository(),
            dhikrRepository: container.makeDhikrRepository(),
            settingsRepository: container.makeSettingsRepository(),
            hapticsService: container.hapticsService,
            liveActivityCoordinator: container.liveActivityCoordinator,
            widgetSnapshotCoordinator: container.widgetSnapshotCoordinator,
            hapticsEnabled: settings?.hapticsEnabled ?? true
        )
    }
}

struct SessionContent: View {
    @Bindable var viewModel: SessionViewModel
    @Binding var pendingLaunchAction: SessionLaunchAction
    let onDismiss: () -> Void
    
    // Animation State
    @State private var contentId: String = ""
    
    // Font Size State
    @AppStorage("sessionFontSize") private var fontSize: Double = 22.0
    
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
                    .padding(.bottom, 20)
                
                Spacer()
                
                // Main Content Area
                VStack(spacing: 24) {
                    dhikrCard
                        .padding(.horizontal, 16) // Expanded card width
                        .frame(maxWidth: 600) // Max width for iPad
                    
                    counterSection
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                bottomActions
            }
        }
        .task {
            await viewModel.loadSession()
            applyPendingLaunchActionIfNeeded()
        }
        .onChange(of: pendingLaunchAction) { _, _ in
            applyPendingLaunchActionIfNeeded()
        }
        .onChange(of: viewModel.currentDhikr?.id) { _, newValue in
            if let id = newValue {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    contentId = id.uuidString
                }
            }
        }
        .sheet(isPresented: $viewModel.showDhikrSwitcher) {
            DhikrSwitcherSheet(
                dhikrList: viewModel.dhikrList,
                currentDhikr: viewModel.currentDhikr,
                onSelect: viewModel.switchDhikr
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("إعادة ضبط", isPresented: $viewModel.showResetConfirmation) {
            Button("إلغاء", role: .cancel) { }
            Button("إعادة ضبط", role: .destructive) {
                withAnimation { viewModel.reset() }
            }
        } message: {
            Text("هل تريد إعادة ضبط العداد إلى الصفر؟")
        }
        .safeAreaTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                viewModel.increment()
            }
        }
        .overlay {
            overlays
        }
    }
    
    // MARK: - Sub-views
    
    private var backgroundView: some View {
        ZStack {
            AppColors.sessionBackground.ignoresSafeArea()
            
            AmbientBackground()
                .opacity(0.8)
                .blur(radius: 60)
        }
    }
    
    private var topBar: some View {
        HStack {
            Button {
                viewModel.endSession()
                onDismiss()
            } label: {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    .overlay(
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            
            Spacer()
            
            if !viewModel.dhikrList.isEmpty {
                HStack(spacing: 8) {
                    Text("\(viewModel.currentIndex + 1) / \(viewModel.totalItems)")
                        .font(.custom("Menlo", size: 14).bold()) // Monospaced numbers
                        .foregroundStyle(.white)
                    
                    ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(viewModel.totalItems))
                        .progressViewStyle(LinearProgressViewStyle(tint: AppColors.onboardingPrimary))
                        .frame(width: 50)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 5)
            }
            
            Spacer()
            
            Button {
                viewModel.showDhikrSwitcher = true
            } label: {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 5)
                    .overlay(
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var dhikrCard: some View {
        ZStack {
            // Glassmorphism Card
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack(spacing: 16) {
                if let dhikr = viewModel.currentDhikr {
                    // Header removed as per user request (Basmala is in text if needed)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Dhikr Text
                            Text(dhikr.text)
                                .font(.system(size: fontSize, weight: .semibold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .lineSpacing(10)
                                .minimumScaleFactor(0.8) // Reduced scaling to respect user font choice
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                                .id(dhikr.id)
                                .transition(.opacity)
                                .padding(.horizontal, 4)
                            
                            // Metadata
                            VStack(spacing: 12) {
                                if let benefit = dhikr.benefit, !benefit.isEmpty {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(AppColors.onboardingPrimary)
                                            .font(.caption)
                                            .padding(.top, 4)
                                        
                                        Text(benefit)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.9))
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                
                                if let reference = dhikr.reference, !reference.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "book.closed.fill")
                                            .font(.caption2)
                                        Text(reference)
                                            .font(.caption.bold())
                                    }
                                    .foregroundStyle(AppColors.textGray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Divider().background(.white.opacity(0.2))
                    
                    // Font Controls
                    HStack(spacing: 32) {
                        Button {
                            withAnimation {
                                if fontSize > 20 { fontSize -= 2 }
                            }
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                                .font(.title3)
                                .foregroundStyle(AppColors.textGray)
                        }

                        // Font size indicator
                        Text("\(Int(fontSize))")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.onboardingPrimary)
                            .frame(width: 40)
                            .environment(\.locale, Locale(identifier: "en")) // Force 123
                        
                        Button {
                            withAnimation {
                                if fontSize < 60 { fontSize += 2 }
                            }
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .font(.title3)
                                .foregroundStyle(AppColors.textGray)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(24) // Reduced padding from 32 to give more space
        }
        .frame(minHeight: 350) // Ensure substantial height
        .layoutPriority(1)
    }
    
    private var counterSection: some View {
        HStack(spacing: 24) {
            // Previous Button
            Button {
                withAnimation { viewModel.moveToPrevious() }
            } label: {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "arrow.backward")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
            .disabled(viewModel.currentDhikrIndex == 0)
            .opacity(viewModel.currentDhikrIndex == 0 ? 0.3 : 1.0)
            
            // Main Counter
            CounterCircle(
                currentCount: viewModel.currentCount,
                targetCount: viewModel.targetCount,
                size: 140, // Reduced size
                accentColor: AppColors.onboardingPrimary
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    viewModel.increment()
                }
            }
            .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 20, x: 0, y: 0) // Glow effect
            
            // Next Button
            Button {
                withAnimation { viewModel.moveToNext() }
            } label: {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "arrow.forward")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
            .disabled(viewModel.currentDhikrIndex >= viewModel.dhikrList.count - 1)
            .opacity(viewModel.currentDhikrIndex >= viewModel.dhikrList.count - 1 ? 0.3 : 1.0)
        }
    }
    
    // Bottom actions remain simple
    private var bottomActions: some View {
        HStack(spacing: 40) {
            Button {
                viewModel.showResetConfirmation = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .symbolEffect(.bounce, value: viewModel.showResetConfirmation)
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
        }
    }

    private func applyPendingLaunchActionIfNeeded() {
        guard pendingLaunchAction != .none else { return }

        switch pendingLaunchAction {
        case .none:
            break
        case .next:
            withAnimation {
                viewModel.moveToNext()
            }
        }

        pendingLaunchAction = .none
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



// struct AmbientBackground is already defined in AppColors.swift or elsewhere, 
// but the user provided a version here. I'll include it inside the file if needed, 
// or assume it's global. The original SessionView had it too.

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
    // Note: AppContainer would be needed for a real preview, but this serves as a placeholder
    Text("Session Preview")
}
