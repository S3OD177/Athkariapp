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
            // Content
            ZStack {
                switch viewModel.currentStep {
                case 0:
                    WelcomeStep(onContinue: viewModel.nextStep)
                        .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                case 1:
                    NameInputStep(
                        userName: $viewModel.userName,
                        onContinue: viewModel.nextStep
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                case 2:
                    TimeConfigurationStep(viewModel: viewModel, onContinue: viewModel.nextStep)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                case 3:
                    PermissionsStep(
                        isLoading: viewModel.isLoading,
                        locationEnabled: viewModel.locationEnabled,
                        notificationsEnabled: viewModel.notificationsEnabled,
                        onLocationToggle: { viewModel.requestLocationPermission() },
                        onNotificationsToggle: { viewModel.setNotificationsEnabled($0) },
                        onComplete: viewModel.completeOnboarding,
                        onSkip: viewModel.skipOnboarding
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                default:
                    EmptyView()
                }
            }
            .animation(.snappy(duration: 0.6), value: viewModel.currentStep)
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

// MARK: - Name Input Step
struct NameInputStep: View {
    @Binding var userName: String
    let onContinue: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("ما اسمك؟")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("لنتعرف عليك ونخاطبك باسمك في التطبيق")
                    .font(.body)
                    .foregroundStyle(AppColors.textGray)
                    .lineSpacing(4)
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Input Field
            VStack {
                TextField("الاسم", text: $userName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(height: 70)
                    .background(AppColors.onboardingSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.onboardingPrimary.opacity(isFocused ? 0.8 : 0.2), lineWidth: 2)
                    )
                    .focused($isFocused)
                    .submitLabel(.continue)
                    .onSubmit {
                        if !userName.isEmpty {
                            isFocused = false
                            onContinue()
                        }
                    }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Continue Button
            Button(action: {
                isFocused = false
                onContinue()
            }) {
                Text("متابعة")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(userName.isEmpty ? Color.gray.opacity(0.3) : AppColors.onboardingPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: userName.isEmpty ? .clear : AppColors.onboardingPrimary.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(userName.isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Time Configuration Step
struct TimeConfigurationStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("أوقاتك المفضلة")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("حدد الأوقات التي تناسب روتين يومك لنذكرك بالأذكار في الوقت المناسب.")
                    .font(.body)
                    .foregroundStyle(AppColors.textGray)
                    .lineSpacing(4)
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Waking Up
                    OnboardingTimeSection(
                        title: "أذكار الاستيقاظ",
                        icon: "sunrise.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "F59E0B"),
                        startBinding: $viewModel.wakingUpStart,
                        endBinding: $viewModel.wakingUpEnd
                    )
                    
                    // Morning
                    OnboardingTimeSection(
                        title: "أذكار الصباح",
                        icon: "sun.max.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "FBBF24"),
                        startBinding: $viewModel.morningStart,
                        endBinding: $viewModel.morningEnd
                    )
                    
                    // Evening
                    OnboardingTimeSection(
                        title: "أذكار المساء",
                        icon: "sunset.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "F97316"),
                        startBinding: $viewModel.eveningStart,
                        endBinding: $viewModel.eveningEnd
                    )
                    
                    // Sleep
                    OnboardingTimeSection(
                        title: "أذكار النوم",
                        icon: "moon.zzz.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "4F46E5"),
                        startBinding: $viewModel.sleepStart,
                        endBinding: $viewModel.sleepEnd
                    )
                    
                    // After Prayer
                    OnboardingDurationSection(
                        title: "أذكار بعد الصلاة",
                        subtitle: "تذكير بالأذكار بعد الأذان بمدة...",
                        icon: "hands.and.sparkles.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "0EA5E9"), // Sky Blue
                        minutesBinding: $viewModel.afterPrayerOffset
                    )
                    
                    Spacer().frame(height: 100) // Spacing for button
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .overlay(alignment: .bottom) {
                // Continue Button (Fixed at bottom)
                VStack {
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
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .padding(.top, 20)
                .background(
                    LinearGradient(
                        colors: [AppColors.onboardingBackground.opacity(0), AppColors.onboardingBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

struct OnboardingTimeSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let iconBg: Color
    @Binding var startBinding: Int
    @Binding var endBinding: Int
    
    private func formatTime(_ hour: Int) -> String {
        let period = hour < 12 ? "ص" : "م"
        let hour12 = hour == 0 || hour == 12 ? 12 : hour % 12
        return "\(hour12):00 \(period)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(iconColor)
                    )
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            
            HStack(spacing: 12) {
                // Start Time
                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatTime(hour)) {
                            startBinding = hour
                        }
                    }
                } label: {
                    HStack {
                        Text("من")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatTime(startBinding))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(AppColors.onboardingSurface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                // End Time
                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatTime(hour)) {
                            endBinding = hour
                        }
                    }
                } label: {
                    HStack {
                        Text("إلى")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatTime(endBinding))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(AppColors.onboardingSurface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct OnboardingDurationSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let iconBg: Color
    @Binding var minutesBinding: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
             // Header
             HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(iconColor)
                    )
                
                 VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                 }
            }
            .padding(.horizontal, 8)
            
            // Picker
            Menu {
                ForEach([0, 5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { min in
                    Button("\(min) دقيقة") {
                        minutesBinding = min
                    }
                }
            } label: {
                HStack {
                    Text("مدة الانتظار")
                         .font(.caption)
                         .foregroundStyle(.gray)
                    Spacer()
                    Text("\(minutesBinding) دقيقة")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(AppColors.onboardingSurface)
                .cornerRadius(12)
                .overlay(
                     RoundedRectangle(cornerRadius: 12)
                         .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}


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
