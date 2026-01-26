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
    let onFinished: () -> Void

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
        .ignoresSafeArea()
        .background(Color.black)
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

    var body: some View {
        ZStack {
            // Background & Blobs
            AppColors.onboardingBackground.ignoresSafeArea()
            
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(AppColors.onboardingPrimary.opacity(0.1))
                        .frame(width: 400, height: 400)
                        .blur(radius: 120)
                        .position(x: 0, y: 0)
                    
                    Circle()
                        .fill(AppColors.onboardingPrimary.opacity(0.05))
                        .frame(width: 400, height: 400)
                        .blur(radius: 100)
                        .position(x: proxy.size.width, y: proxy.size.height)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero Visual
                ZStack {
                    // Outer Ring
                    Circle()
                        .stroke(AppColors.onboardingPrimary.opacity(0.2), lineWidth: 1)
                        .scaleEffect(1.1)
                        .frame(width: 250, height: 250)

                    // Glow Container
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.onboardingPrimary.opacity(0.1),
                                    AppColors.onboardingPrimary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 250, height: 250)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 20)
                        .overlay {
                             Image(systemName: "circle.grid.hex")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.1)
                                .mask(Circle())
                        }
                    
                    // Floating Badge
                    VStack {
                        Spacer()
                        Circle()
                            .fill(AppColors.onboardingBackground)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(radius: 8)
                            .overlay(
                                Image(systemName: "building.columns.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppColors.onboardingPrimary)
                            )
                            .offset(y: 28)
                    }
                    .frame(height: 250)
                }
                .padding(.bottom, 60)

                // Typography
                Text("اذكاري")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.white)
                
                Text("رفيقك اليومي للذكر")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textGray)
                    .padding(.top, 12)

                Spacer()
                Spacer()

                // Action
                VStack(spacing: 20) {
                    Button(action: onContinue) {
                        HStack {
                            Text("متابعة")
                            Spacer().frame(width: 8)
                            Image(systemName: "arrow.left") // RTL Arrow
                        }
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: AppColors.onboardingPrimary.opacity(0.25), radius: 10, y: 5)
                    }
                    
                    Text("باستمرارك، أنت توافق على شروط الاستخدام")
                        .font(.caption)
                        .foregroundStyle(Color.gray.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
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
            VStack(alignment: .leading, spacing: 8) {
                Text("اختر روتينك")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("اختر مستوى الأذكار الذي يناسب يومك. يمكنك تغيير هذا الإعداد لاحقاً.")
                    .font(.body)
                    .foregroundStyle(AppColors.textGray)
                    .multilineTextAlignment(.leading)
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // Options List
            VStack(spacing: 16) {
                RoutineOptionCard(
                    title: "أذكار الصباح والمساء",
                    description: "الأذكار الأساسية اليومية فقط",
                    icon: "sun.max.fill",
                    isSelected: selectedIntensity == .light,
                    onTap: { onSelect(.light) }
                )

                RoutineOptionCard(
                    title: "أذكار اليوم والليلة",
                    description: "أذكار الصباح والمساء",
                    icon: "cloud.sun.fill",
                    isSelected: selectedIntensity == .moderate,
                    onTap: { onSelect(.moderate) }
                )

                RoutineOptionCard(
                    title: "أذكار المسلم اليومية",
                    description: "أذكار النوم والاستيقاظ وكافة الأذكار",
                    icon: "book.fill", // Using book.fill as per design 'menu_book'
                    isSelected: selectedIntensity == .complete,
                    onTap: { onSelect(.complete) }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue Button (Sticky Bottom)
            VStack {
                Button(action: onContinue) {
                    Text("متابعة")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: AppColors.onboardingPrimary.opacity(0.25), radius: 10, y: 5)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.onboardingBackground)
    }
}

struct RoutineOptionCard: View {
    let title: String
    let description: String
    let icon: String // SF Symbol Name
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .bold()
                        .foregroundStyle(isSelected ? AppColors.onboardingPrimary : .white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(AppColors.textGray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Icon Box
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.onboardingPrimary : Color(hex: "25252c"))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundStyle(isSelected ? .white : .gray)
                    }

                // Checkmark (Circle Indicator) - Left side
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.onboardingPrimary : AppColors.onboardingBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(AppColors.onboardingPrimary)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColors.onboardingPrimary.opacity(0.05) : AppColors.onboardingSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? AppColors.onboardingPrimary : AppColors.onboardingBorder, lineWidth: 2)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions managed in AppColors.swift
// Color extensions moved to Utilities/AppColors.swift to avoid duplication


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
            VStack(alignment: .leading, spacing: 16) {
                Text("الموقع والتنبيهات")
                    .font(.system(size: 30, weight: .bold)) // text-3xl
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text("نحتاج إلى هذه الأذونات لتقديم تجربة روحانية متكاملة، بما في ذلك أوقات الصلاة الدقيقة وتذكيرات الأذكار.")
                    .font(.system(size: 16)) // text-base
                    .foregroundStyle(Color(hex: "94a3b8")) // slate-400
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
            }
            .padding(.top, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Cards
            VStack(spacing: 16) {
                PermissionCard(
                    title: "تفعيل الموقع",
                    description: "لمعرفة أوقات الصلاة واتجاه القبلة بدقة.",
                    icon: "location.fill", // material: location_on
                    isEnabled: $locationToggle,
                    onToggle: {
                        if locationToggle {
                            onLocationToggle()
                        }
                    }
                )

                PermissionCard(
                    title: "تفعيل التنبيهات",
                    description: "لتذكيرك بالأذكار اليومية ومواقيت الصلاة.",
                    icon: "bell.fill", // material: notifications_active
                    isEnabled: $notificationToggle,
                    onToggle: {
                        onNotificationsToggle(notificationToggle)
                    }
                )
            }

            Spacer()

            // Buttons
            VStack(spacing: 16) {
                Button(action: onComplete) {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("ابدأ الاستخدام")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56) // h-14
                    .background(Color.onboardingPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // rounded-xl
                    .shadow(color: Color.onboardingPrimary.opacity(0.2), radius: 10, y: 4)
                }
                .disabled(isLoading)

                Button(action: onSkip) {
                    Text("تخطي الآن")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "64748b")) // slate-500
                }
                .padding(.bottom, 8)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.onboardingBackground)
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ContainerRelativeShape()
                .fill(Color.onboardingIconBg)
                .frame(width: 48, height: 48) // h-12 w-12
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12)) // rounded-xl

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold)) // text-base
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 14)) // text-sm
                    .foregroundStyle(Color(hex: "94a3b8")) // slate-400
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(Color.onboardingPrimary)
                .onChange(of: isEnabled) { _, _ in
                    onToggle()
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16) // rounded-2xl
                .fill(Color.onboardingCard)
                .stroke(Color.onboardingBorder, lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
