import SwiftUI

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
            favoritesRepository: container.makeFavoritesRepository(),
            hapticsService: container.hapticsService,
            hapticsEnabled: settings?.hapticsEnabled ?? true,
            fontSize: settings?.fontSize ?? 1.0
        )
    }
}

struct SessionContent: View {
    @Bindable var viewModel: SessionViewModel
    let onDismiss: () -> Void

    @State private var isFavorite = false

    var body: some View {
        ZStack {
            // Background
            AppColors.sessionBackground.ignoresSafeArea()
            
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
                        let ringSize = min(geometry.size.width * 0.65, 260)
                        ZStack {
                            // Glow behind
                            Circle()
                                .fill(AppColors.sessionPrimary.opacity(0.1))
                                .frame(width: ringSize * 0.85, height: ringSize * 0.85)
                                .blur(radius: 40)
                            
                            // Track
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 3)
                                .frame(width: ringSize, height: ringSize)
                            
                            // Progress
                            Circle()
                                .trim(from: 0, to: viewModel.progress)
                                .stroke(
                                    AppColors.sessionPrimary,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: ringSize, height: ringSize)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: AppColors.sessionPrimary.opacity(0.3), radius: 10, x: 0, y: 0)
                                .animation(.easeOut(duration: 0.2), value: viewModel.progress)
                            
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
                    // Hint with updated style
                    if Constants.showLockScreenHint { // Assume constant or ViewModel flag
                         HStack(spacing: 8) {
                            Image(systemName: "lock.circle")
                            Text("يظهر هذا الذكر في شاشة القفل أثناء القراءة")
                        }
                        .font(.caption)
                        .foregroundStyle(AppColors.textGray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                .background(Color.white.opacity(0.03))
                        )
                    }
                    
                    // Grid Controls
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        SessionControlButton(icon: "xmark", title: "إنهاء", color: .red) {
                            if viewModel.currentCount >= viewModel.targetCount {
                                viewModel.finishSession()
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
                        
                        SessionControlButton(icon: "square.and.arrow.up", title: "مشاركة") {
                            // Share
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 120) // Extra padding for tab bar
            }
        }
        .task {
            await viewModel.loadSession()
            isFavorite = (try? viewModel.isFavorite()) ?? false
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
                viewModel.forceFinish()
                onDismiss()
            }
        } message: {
            Text("لم تكمل جميع الأذكار. هل تريد الإنهاء على أي حال؟")
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

            Button {
                // Audio toggle
            } label: {
                 Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(AppColors.textGray)
                    )
            }
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
                    .fill(AppColors.sessionSurface) // #1c1e24
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(title == "إنهاء" ? .red : .white) // Apply red specifically for exit
                    )
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textGray)
            }
        }
        .buttonStyle(.plain)
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
            List(dhikrList) { dhikr in
                Button {
                    onSelect(dhikr)
                    dismiss()
                } label: {
                    HStack {
                        if dhikr.id == currentDhikr?.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.onboardingPrimary)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(dhikr.title)
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("التكرار: \(dhikr.repeatCount.arabicNumeral)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .navigationTitle("اختر الذكر")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إغلاق") {
                        dismiss()
                    }
                }
            }
        }
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
