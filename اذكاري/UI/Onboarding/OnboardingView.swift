import SwiftUI

struct OnboardingView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: OnboardingViewModel?
    @State private var currentPage = 0

    var body: some View {
        Group {
            if let viewModel = viewModel {
                OnboardingContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }

    private func setupViewModel() {
        viewModel = OnboardingViewModel(
            onboardingRepository: container.makeOnboardingRepository(),
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService
        )
    }
}

struct OnboardingContent: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        TabView(selection: Binding(
            get: { viewModel.currentStep },
            set: { _ in }
        )) {
            WelcomeStep(onContinue: viewModel.nextStep)
                .tag(0)

            RoutineSelectionStep(
                selectedIntensity: viewModel.routineIntensity,
                onSelect: viewModel.selectRoutineIntensity,
                onContinue: viewModel.nextStep
            )
            .tag(1)

            PermissionsStep(
                locationEnabled: viewModel.locationEnabled,
                notificationsEnabled: viewModel.notificationsEnabled,
                onLocationToggle: { viewModel.requestLocationPermission() },
                onNotificationsToggle: { viewModel.setNotificationsEnabled($0) },
                onComplete: viewModel.completeOnboarding,
                onSkip: viewModel.skipOnboarding
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .background(Color.black)
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo area
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 180, height: 180)

                // Placeholder for book/Quran image
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.brown.opacity(0.8))

                // Mosque icon at bottom of circle
                VStack {
                    Spacer()
                    Image(systemName: "building.columns.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .padding(.bottom, -10)
                }
                .frame(width: 200, height: 200)
            }
            .padding(.bottom, 40)

            // App title
            Text("اذكاري")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)

            Text("رفيقك اليومي للذكر")
                .font(.title3)
                .foregroundStyle(.gray)
                .padding(.top, 8)

            Spacer()
            Spacer()

            // Continue button
            Button(action: onContinue) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("متابعة")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            // Terms text
            Text("باستمرارك، أنت توافق على شروط الاستخدام")
                .font(.caption)
                .foregroundStyle(.gray)
                .padding(.top, 16)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.1, blue: 0.15), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Routine Selection Step
struct RoutineSelectionStep: View {
    let selectedIntensity: RoutineIntensity
    let onSelect: (RoutineIntensity) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Text("اختر روتينك")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)

            Text("اختر مستوى الأذكار الذي يناسب يومك. يمكنك تغيير هذا الإعداد لاحقاً.")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 20)

            VStack(spacing: 16) {
                RoutineOptionCard(
                    title: "الصلوات فقط",
                    description: "أذكار ما بعد الصلاة المفروضة",
                    icon: "building.columns.fill",
                    isSelected: selectedIntensity == .light,
                    onTap: { onSelect(.light) }
                )

                RoutineOptionCard(
                    title: "الصباح والمساء",
                    description: "أذكار الصباح، المساء، والصلاة",
                    icon: "sunrise.fill",
                    isSelected: selectedIntensity == .moderate,
                    onTap: { onSelect(.moderate) }
                )

                RoutineOptionCard(
                    title: "كامل الأذكار",
                    description: "النوم، الاستيقاظ، وجميع المناسبات",
                    icon: "book.fill",
                    isSelected: selectedIntensity == .complete,
                    onTap: { onSelect(.complete) }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onContinue) {
                Text("متابعة")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct RoutineOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Radio button
                Circle()
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.5), lineWidth: 2)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                        }
                    }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                // Icon
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.15))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.1))
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions Step
struct PermissionsStep: View {
    let locationEnabled: Bool
    let notificationsEnabled: Bool
    let onLocationToggle: () -> Void
    let onNotificationsToggle: (Bool) -> Void
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var locationToggle = false
    @State private var notificationToggle = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Text("الموقع والتنبيهات")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)

            Text("نحتاج إلى هذه الأذونات لتقديم تجربة روحانية متكاملة، بما في ذلك أوقات الصلاة الدقيقة وتذكيرات الأذكار.")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 20)

            VStack(spacing: 16) {
                PermissionCard(
                    title: "تفعيل الموقع",
                    description: "لمعرفة أوقات الصلاة واتجاه القبلة بدقة.",
                    icon: "location.fill",
                    iconColor: .white,
                    iconBackground: Color(white: 0.2),
                    isEnabled: $locationToggle,
                    onToggle: {
                        locationToggle.toggle()
                        if locationToggle {
                            onLocationToggle()
                        }
                    }
                )

                PermissionCard(
                    title: "تفعيل التنبيهات",
                    description: "لتذكيرك بالأذكار اليومية ومواقيت الصلاة.",
                    icon: "bell.fill",
                    iconColor: .white,
                    iconBackground: Color(white: 0.2),
                    isEnabled: $notificationToggle,
                    onToggle: {
                        notificationToggle.toggle()
                        onNotificationsToggle(notificationToggle)
                    }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onComplete) {
                Text("ابدأ الاستخدام")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Button(action: onSkip) {
                Text("تخطي الآن")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    @Binding var isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, _ in
                    onToggle()
                }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.trailing)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(iconBackground)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.1))
        )
    }
}

#Preview {
    OnboardingView()
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
