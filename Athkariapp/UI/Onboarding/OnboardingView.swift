import SwiftUI

struct OnboardingView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: OnboardingViewModel?
    let onFinished: () -> Void

    var body: some View {
        Group {
            if let viewModel = viewModel {
                OnboardingContent(viewModel: viewModel, onFinished: onFinished)
            } else {
                ZStack {
                    AppColors.onboardingBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
                .task { setupViewModel() }
            }
        }
    }

    private func setupViewModel() {
        let vm = OnboardingViewModel(
            onboardingRepository: container.makeOnboardingRepository(),
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService
        )

        viewModel = vm

        Task {
            await vm.checkOnboardingStatus()
        }
    }
}

struct OnboardingContent: View {
    @Bindable var viewModel: OnboardingViewModel
    let onFinished: () -> Void

    @FocusState private var isNameFocused: Bool

    private var progressValue: Double {
        Double(viewModel.currentStep + 1) / Double(viewModel.totalSteps)
    }

    private var primaryButtonTitle: String {
        switch viewModel.currentStep {
        case 0: return "ابدأ"
        case 1: return "متابعة"
        case 2: return "متابعة"
        case 3: return "ابدأ الاستخدام"
        default: return "متابعة"
        }
    }

    private var primaryButtonAction: () -> Void {
        switch viewModel.currentStep {
        case 3:
            return viewModel.completeOnboarding
        default:
            return viewModel.nextStep
        }
    }

    private var shouldShowSkipButton: Bool {
        viewModel.currentStep == 3
    }

    private var isPrimaryDisabled: Bool {
        viewModel.isLoading || !viewModel.canProceed
    }

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.onboardingPrimary.opacity(0.2),
                    AppColors.onboardingBackground
                ]),
                center: .topLeading,
                startRadius: 120,
                endRadius: 900
            )
            .ignoresSafeArea()

            AmbientBackground()

            VStack(spacing: 0) {
                header

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .onChange(of: viewModel.currentStep) { _, newStep in
            isNameFocused = newStep == 1
        }
        .onAppear {
            isNameFocused = viewModel.currentStep == 1
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                onFinished()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                if viewModel.currentStep > 0 {
                    Button(action: viewModel.previousStep) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppColors.onboardingSurface)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                } else {
                    Color.clear
                        .frame(width: 36, height: 36)
                }

                Spacer()

                Text("الخطوة \(viewModel.currentStep + 1) من \(viewModel.totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textGray)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(AppColors.onboardingPrimary)
                        .frame(width: geometry.size.width * progressValue)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var stepContent: some View {
        ZStack {
            switch viewModel.currentStep {
            case 0:
                WelcomeStep()
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            case 1:
                NameStep(
                    userName: Binding(
                        get: { viewModel.userName },
                        set: { viewModel.setUserName($0) }
                    ),
                    isFocused: $isNameFocused
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case 2:
                TimeConfigurationStep(viewModel: viewModel)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case 3:
                PermissionsStep(
                    notificationsEnabled: Binding(
                        get: { viewModel.notificationsEnabled },
                        set: { viewModel.setNotificationsEnabled($0) }
                    ),
                    locationEnabled: Binding(
                        get: { viewModel.locationEnabled },
                        set: { viewModel.setLocationEnabled($0) }
                    )
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentStep)
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            Button(action: primaryButtonAction) {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryButtonTitle)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    isPrimaryDisabled
                        ? Color.gray.opacity(0.3)
                        : AppColors.onboardingPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: AppColors.onboardingPrimary.opacity(isPrimaryDisabled ? 0 : 0.35), radius: 12, y: 6)
            }
            .buttonStyle(.scale)
            .disabled(isPrimaryDisabled)

            if shouldShowSkipButton {
                Button(action: viewModel.skipOnboarding) {
                    Text("تخطي الآن")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textGray)
                }
                .disabled(viewModel.isLoading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [
                    AppColors.onboardingBackground.opacity(0),
                    AppColors.onboardingBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .fill(AppColors.onboardingPrimary.opacity(0.18))
                    .frame(width: 190, height: 190)
                    .blur(radius: 14)

                Circle()
                    .stroke(AppColors.onboardingPrimary.opacity(0.3), lineWidth: 1)
                    .frame(width: 220, height: 220)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(.white)
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.45), radius: 16)
            }
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                Text("اذكاري")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("رفيقك اليومي للذكر")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textGray)

                Text("ابدأ إعدادًا سريعًا يطابق يومك خلال أقل من دقيقة.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColors.textGray.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 60)
        }
    }
}

struct NameStep: View {
    @Binding var userName: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ما اسمك؟")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("سنخاطبك باسمك داخل التطبيق.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColors.textGray)

            TextField("الاسم", text: $userName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(height: 64)
                .background(AppColors.onboardingSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.onboardingPrimary.opacity(isFocused.wrappedValue ? 0.8 : 0.2), lineWidth: 2)
                )
                .focused(isFocused)
                .submitLabel(.continue)

            Spacer()
        }
    }
}

struct TimeConfigurationStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("اختر أوقاتك")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("خصص النوافذ الزمنية التي تناسب يومك، ويمكنك تعديلها لاحقًا من الإعدادات.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColors.textGray)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    OnboardingTimeSection(
                        title: "أذكار الاستيقاظ",
                        icon: "sunrise.fill",
                        startBinding: $viewModel.wakingUpStart,
                        endBinding: $viewModel.wakingUpEnd
                    )

                    OnboardingTimeSection(
                        title: "أذكار الصباح",
                        icon: "sun.max.fill",
                        startBinding: $viewModel.morningStart,
                        endBinding: $viewModel.morningEnd
                    )

                    OnboardingTimeSection(
                        title: "أذكار المساء",
                        icon: "sunset.fill",
                        startBinding: $viewModel.eveningStart,
                        endBinding: $viewModel.eveningEnd
                    )

                    OnboardingTimeSection(
                        title: "أذكار النوم",
                        icon: "moon.zzz.fill",
                        startBinding: $viewModel.sleepStart,
                        endBinding: $viewModel.sleepEnd
                    )

                    OnboardingDurationSection(
                        title: "أذكار بعد الصلاة",
                        subtitle: "بعد الأذان بمدة",
                        icon: "hands.and.sparkles.fill",
                        minutesBinding: $viewModel.afterPrayerOffset
                    )

                    Spacer(minLength: 12)
                }
            }
        }
    }
}

struct OnboardingTimeSection: View {
    let title: String
    let icon: String
    @Binding var startBinding: Int
    @Binding var endBinding: Int

    private func formatTime(_ hour: Int) -> String {
        let period = hour < 12 ? "ص" : "م"
        let hour12 = hour == 0 || hour == 12 ? 12 : hour % 12
        return "\(hour12):00 \(period)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(AppColors.onboardingPrimary.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatTime(hour)) {
                            startBinding = hour
                        }
                    }
                } label: {
                    TimeMenuLabel(title: "من", value: formatTime(startBinding))
                }

                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatTime(hour)) {
                            endBinding = hour
                        }
                    }
                } label: {
                    TimeMenuLabel(title: "إلى", value: formatTime(endBinding))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.onboardingSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct TimeMenuLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppColors.textGray)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct OnboardingDurationSection: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var minutesBinding: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(AppColors.onboardingPrimary.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.textGray)
                }
            }

            Menu {
                ForEach([0, 5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { min in
                    Button("\(min) دقيقة") {
                        minutesBinding = min
                    }
                }
            } label: {
                HStack {
                    Text("المدة")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.textGray)

                    Spacer()

                    Text("\(minutesBinding) دقيقة")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.onboardingSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct PermissionsStep: View {
    @Binding var notificationsEnabled: Bool
    @Binding var locationEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("صلاحيات اختيارية")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("يمكنك المتابعة الآن وتغيير هذه الصلاحيات لاحقًا من الإعدادات.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColors.textGray)

            VStack(spacing: 12) {
                PermissionToggleCard(
                    title: "تنبيهات الأذكار",
                    description: "لتذكيرك بالأذكار في أوقاتها.",
                    icon: "bell.badge.fill",
                    color: .red,
                    isEnabled: $notificationsEnabled
                )

                PermissionToggleCard(
                    title: "الموقع الجغرافي",
                    description: "لتحسين دقة مواقيت الصلاة والقبلة.",
                    icon: "location.fill",
                    color: .blue,
                    isEnabled: $locationEnabled
                )
            }

            Spacer()
        }
    }
}

struct PermissionToggleCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppColors.textGray)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppColors.onboardingSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
