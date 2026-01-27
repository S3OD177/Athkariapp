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
        viewModel = OnboardingViewModel(
            onboardingRepository: container.makeOnboardingRepository(),
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService
        )
    }
}

struct OnboardingContent: View {
    @Bindable var viewModel: OnboardingViewModel
    let onFinished: () -> Void
    @Namespace private var animation // For matched geometry effects if needed

    var body: some View {
        ZStack {
            // Global Background
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.onboardingPrimary.opacity(0.15),
                    AppColors.onboardingBackground
                ]),
                center: .topLeading,
                startRadius: 100,
                endRadius: 800
            )
            .ignoresSafeArea()
            
            // Content
            TabView(selection: $viewModel.currentStep) {
                WelcomeStep(onContinue: viewModel.nextStep)
                    .tag(0)

                RoutineSelectionStep(
                    selectedIntensity: viewModel.routineIntensity,
                    onSelect: viewModel.selectRoutineIntensity,
                    onContinue: viewModel.nextStep
                )
                .tag(1)

                PermissionsStep(
                    isLoading: viewModel.isLoading,
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
            .animation(.easeInOut(duration: 0.5), value: viewModel.currentStep)
        }
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed {
                onFinished()
            }
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    let onContinue: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero Visual
            ZStack {
                // Outer Glow Rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(AppColors.onboardingPrimary.opacity(0.2), lineWidth: 1)
                        .scaleEffect(isAnimating ? 1.2 + Double(i) * 0.2 : 1)
                        .opacity(isAnimating ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 3)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.5),
                            value: isAnimating
                        )
                }
                .frame(width: 250, height: 250)

                // Main Glow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.onboardingPrimary.opacity(0.3),
                                AppColors.onboardingPrimary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                // Icon
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.5), radius: 20, x: 0, y: 0)
            }
            .padding(.bottom, 60)
            .scaleEffect(isAnimating ? 1 : 0.9)
            .opacity(isAnimating ? 1 : 0)

            // Typography
            VStack(spacing: 16) {
                Text("اذكاري")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10)
                
                Text("رَحلةُ الطمأنينةِ تبدأُ من هنا")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(AppColors.textGray)
                    .multilineTextAlignment(.center)
            }
            .offset(y: isAnimating ? 0 : 20)
            .opacity(isAnimating ? 1 : 0)

            Spacer()
            Spacer()

            // Action
            VStack(spacing: 24) {
                Button(action: onContinue) {
                    HStack {
                        Text("ابدأ الرحلة")
                        Spacer().frame(width: 8)
                        Image(systemName: "arrow.left")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppColors.onboardingPrimary, AppColors.onboardingPrimary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.4), radius: 15, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
            .offset(y: isAnimating ? 0 : 20)
            .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
        .onDisappear {
            // Stop repeating animations when view is not visible (energy optimization)
            isAnimating = false
        }
    }
}

// MARK: - Routine Selection Step
struct RoutineSelectionStep: View {
    let selectedIntensity: RoutineIntensity
    let onSelect: (RoutineIntensity) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("اختر وردك اليومي")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("اختر مستوى الأذكار الذي يناسب وقتك. يمكنك تغييره في أي وقت من الإعدادات.")
                    .font(.body)
                    .foregroundStyle(AppColors.textGray)
                    .lineSpacing(4)
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Options List
            VStack(spacing: 16) {
                RoutineOptionCard(
                    title: "أذكار الصباح والمساء",
                    description: "الأذكار الأساسية لبداية ونهاية يومك",
                    icon: "sun.max.fill",
                    color: .orange,
                    isSelected: selectedIntensity == .light,
                    onTap: { withAnimation { onSelect(.light) } }
                )

                RoutineOptionCard(
                    title: "أذكار اليوم والليلة",
                    description: "تشمل الصباح، المساء، وما بينهما",
                    icon: "cloud.sun.fill",
                    color: .blue,
                    isSelected: selectedIntensity == .moderate,
                    onTap: { withAnimation { onSelect(.moderate) } }
                )

                RoutineOptionCard(
                    title: "أذكار المسلم الكاملة",
                    description: "كل الأذكار من الاستيقاظ حتى النوم",
                    icon: "book.fill",
                    color: AppColors.onboardingPrimary,
                    isSelected: selectedIntensity == .complete,
                    onTap: { withAnimation { onSelect(.complete) } }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue Button
            Button(action: onContinue) {
                Text("متابعة")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(AppColors.onboardingPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
}

struct RoutineOptionCard: View {
    let title: String
    let description: String
    let icon: String // SF Symbol Name
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(isSelected ? 0.25 : 0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textGray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection Indicator - Enhanced with checkmark
                ZStack {
                    Circle()
                        .fill(isSelected ? color : Color.clear)
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .strokeBorder(isSelected ? color : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.onboardingSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? color.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .shadow(color: isSelected ? color.opacity(0.15) : Color.clear, radius: 10)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Permissions Step
struct PermissionsStep: View {
    let isLoading: Bool
    let locationEnabled: Bool
    let notificationsEnabled: Bool
    let onLocationToggle: () -> Void
    let onNotificationsToggle: (Bool) -> Void
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var locationToggle = false
    @State private var notificationToggle = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("لأفضل تجربة")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("نحتاج لبعض الصلاحيات لنقوم بخدمتك بشكل أفضل، يمكنك تغييرها لاحقًا.")
                    .font(.body)
                    .foregroundStyle(AppColors.textGray)
                    .lineSpacing(4)
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Cards
            VStack(spacing: 20) {
                PermissionCard(
                    title: "تنبيهات الأذكار",
                    description: "لنذكرك بأذكارك في أوقاتها المستحبة",
                    icon: "bell.badge.fill",
                    color: .red,
                    isEnabled: $notificationToggle,
                    onToggle: {
                        onNotificationsToggle(notificationToggle)
                    }
                )

                PermissionCard(
                    title: "الموقع الجغرافي",
                    description: "لتحديد القبلة ومواقيت الصلاة بدقة",
                    icon: "location.fill",
                    color: .blue,
                    isEnabled: $locationToggle,
                    onToggle: {
                        if locationToggle {
                            onLocationToggle()
                        }
                    }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Button - Skip removed, only main action
            VStack(spacing: 20) {
                Button(action: onComplete) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("ابدأ الرحلة")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(AppColors.onboardingPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .onAppear {
            notificationToggle = notificationsEnabled
            locationToggle = locationEnabled
        }
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @Binding var isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppColors.textGray)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(color)
                .onChange(of: isEnabled) { _, _ in
                    onToggle()
                }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.onboardingSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
