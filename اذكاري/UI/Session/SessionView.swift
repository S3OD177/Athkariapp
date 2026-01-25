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
            hapticsEnabled: settings?.hapticsEnabled ?? true
        )
    }
}

struct SessionContent: View {
    @Bindable var viewModel: SessionViewModel
    let onDismiss: () -> Void

    @State private var isFavorite = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sessionHeader

            Spacer()

            // Dhikr text
            if let dhikr = viewModel.currentDhikr {
                dhikrTextSection(dhikr)
            }

            Spacer()

            // Counter
            counterSection

            Spacer()

            // Live Activity hint
            liveActivityHint

            // Action buttons
            actionButtons
        }
        .padding(.horizontal, 16)
        .background(Color.black)
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
                // Audio toggle
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Text("جلسة ذكر")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Dhikr Text
    private func dhikrTextSection(_ dhikr: DhikrItem) -> some View {
        VStack(spacing: 16) {
            Text(dhikr.text)
                .font(.system(size: 28, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(12)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Counter Section
    private var counterSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 16)
                    .frame(width: 220, height: 220)

                // Progress circle
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.progress)

                // Counter display
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("/ \(viewModel.targetCount)")
                            .font(.title2)
                            .foregroundStyle(.gray)

                        Text("\(viewModel.currentCount)")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }

                    Text("اضغط للعد")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .onTapGesture {
                viewModel.increment()
            }
            .accessibilityLabel("عداد التسبيح")
            .accessibilityValue("\(viewModel.currentCount) من \(viewModel.targetCount)")
            .accessibilityHint("اضغط مرتين للعد")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Live Activity Hint
    private var liveActivityHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.gray)

            Text("يظهر هذا الذكر في شاشة القفل أثناء القراءة")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(white: 0.1))
        )
        .padding(.bottom, 24)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Share
            ActionButton(
                title: "مشاركة",
                icon: "square.and.arrow.up",
                color: .gray
            ) {
                // Share action
            }

            // Switch dhikr
            ActionButton(
                title: "تبديل",
                icon: "arrow.left.arrow.right",
                color: .gray
            ) {
                viewModel.showDhikrSwitcher = true
            }

            // Reset
            ActionButton(
                title: "إعادة ضبط",
                icon: "arrow.counterclockwise",
                color: .gray
            ) {
                viewModel.showResetConfirmation = true
            }

            // Finish
            ActionButton(
                title: "إنهاء",
                icon: "xmark",
                color: .red
            ) {
                if viewModel.currentCount >= viewModel.targetCount {
                    viewModel.finishSession()
                    onDismiss()
                } else {
                    viewModel.showFinishConfirmation = true
                }
            }
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(color == .red ? .red : .white)
                    }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .buttonStyle(.plain)
    }
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
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(dhikr.title)
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("التكرار: \(dhikr.repeatCount)")
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
                    .foregroundStyle(.green)

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
                        .background(Color.blue)
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
