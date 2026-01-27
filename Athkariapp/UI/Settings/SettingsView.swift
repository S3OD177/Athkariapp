import SwiftUI

struct SettingsView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                SettingsContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }

    private func setupViewModel() {
        viewModel = SettingsViewModel(
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService,
            hapticsService: container.hapticsService,
            prayerTimeService: container.prayerTimeService,
            modelContext: container.modelContainer.mainContext
        )
    }
}

struct SettingsContent: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showClearDataAlert = false
    
    var body: some View {
        ZStack {
            // Background
            AppColors.settingsBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Title
                    HStack {
                        Text("الإعدادات")
                            .font(.system(size: 40, weight: .bold)) // Larger as per mockup
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 24)

                    // Sections
                    VStack(spacing: 24) {
                        appearanceSection
                        preferencesSection
                        timeConfigurationSection
                        prayerTimesSection
                    }
                    .padding(.horizontal, 24)
                    
                    // Data Management
                    dataManagementSection
                        .padding(.horizontal, 24)
                    
                    // Footer
                    appInfoSection
                    
                    Spacer().frame(height: 100)
                }
            }
        }
        .task {
            await viewModel.loadSettings()
        }
        .alert("مسح البيانات", isPresented: $showClearDataAlert) {
            Button("إلغاء", role: .cancel) { }
            Button("مسح", role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text("سيتم مسح جميع بيانات الجلسات والمفضلات. هذا الإجراء لا يمكن التراجع عنه.")
        }
    }

    // MARK: - Appearance Section
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("المظهر والعرض")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)

            VStack(spacing: 20) {
                // Font Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("الخط")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    // Preview Card
                    VStack {
                        Text("سبحان الله وبحمده")
                        Text("سبحان الله العظيم")
                    }
                    .font(.system(size: 20 * viewModel.fontSize, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .frame(height: 120)
                    .background(Color(hex: "2c2c2e"))
                    .cornerRadius(12)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.fontSize)
                    
                    // Custom Slider
                    HStack(spacing: 12) {
                        Text("أ")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)
                        
                        Slider(value: Binding(
                            get: { viewModel.fontSize },
                            set: { viewModel.updateFontSize($0) }
                        ), in: 0.8...1.5)
                        .tint(.white)
                        
                        Text("أ")
                            .font(.system(size: 24))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding(16)
            .background(AppColors.onboardingSurface)
            .cornerRadius(16)
        }
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("التفضيلات")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)
            
            VStack(spacing: 0) {
                SettingsRow(
                    title: "الاهتزاز عند التسبيح",
                    icon: "iphone.radiowaves.left.and.right",
                    iconColor: .white,
                    iconBg: AppColors.onboardingPrimary
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.hapticsEnabled },
                        set: { viewModel.updateHapticsEnabled($0) }
                    ))
                    .labelsHidden()
                    .tint(.blue)
                    .sensoryFeedback(.selection, trigger: viewModel.hapticsEnabled)
                }
                
                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                
                SettingsRow(
                    title: "التذكير",
                    icon: "bell.fill",
                    iconColor: .white,
                    iconBg: Color(hex: "FF3B30"), // Red
                    showChevron: true
                )
            }
            .background(AppColors.onboardingSurface)
            .cornerRadius(16)
        }
    }

    // MARK: - Time Configuration Section
    private var timeConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("تكوين الأوقات")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)
            
            VStack(spacing: 0) {
                NavigationLink(destination: TimeConfigSettingsView(viewModel: viewModel)) {
                    SettingsRow(
                        title: "تخصيص الأوقات",
                        icon: "clock.badge.exclamationmark.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "F59E0B"), // Amber
                        showChevron: true
                    )
                }
            }
            .background(AppColors.onboardingSurface)
            .cornerRadius(16)
        }
    }

    // MARK: - Prayer Times Section
    private var prayerTimesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مواقيت الصلاة")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)
            
            VStack(spacing: 0) {
                SettingsRow(
                    title: "طريقة الحساب",
                    icon: "clock.fill",
                    iconColor: .white,
                    iconBg: Color(hex: "5856D6"), // Indigo
                    valueText: viewModel.calculationMethod.arabicName,
                    showChevron: true
                )
            }
            .background(AppColors.onboardingSurface)
            .cornerRadius(16)
        }
    }

    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("إدارة البيانات")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)
            
            Button {
                showClearDataAlert = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text("مسح جميع البيانات")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.gray)
                }
                .padding(16)
                .background(AppColors.onboardingSurface)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(AppColors.onboardingPrimary)
                .cornerRadius(16)
                .shadow(color: AppColors.onboardingPrimary.opacity(0.3), radius: 10)
            
            VStack(spacing: 4) {
                Text("لا حسابات - لا إعلانات")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.gray)
                
                Text("الإصدار ١.٠.٠")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray.opacity(0.6))
            }
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Helper Views



struct SettingsRow<Accessory: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let iconBg: Color
    var valueText: String? = nil
    var showChevron: Bool = false
    let accessory: Accessory?

    // Initializer for simple row (no custom accessory)
    init(title: String, icon: String, iconColor: Color, iconBg: Color, valueText: String? = nil, showChevron: Bool = false) where Accessory == EmptyView {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.iconBg = iconBg
        self.valueText = valueText
        self.showChevron = showChevron
        self.accessory = nil
    }

    // Initializer with accessory
    init(title: String, icon: String, iconColor: Color, iconBg: Color, valueText: String? = nil, showChevron: Bool = false, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.iconBg = iconBg
        self.valueText = valueText
        self.showChevron = showChevron
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon (Right in RTL -> leading in HStack)
            RoundedRectangle(cornerRadius: 10)
                .fill(iconBg)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(iconColor)
                )
            
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            // Value or Accessory (Left in RTL -> trailing in HStack)
            if let accessory = accessory {
                accessory
            } else {
                HStack(spacing: 8) {
                    if let value = valueText {
                        Text(value)
                            .font(.system(size: 17))
                            .foregroundStyle(Color.gray)
                    }
                    
                    if showChevron {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                }
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}


struct TimeConfigSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            AppColors.settingsBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        Text("تكوين الأوقات")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 24)

                    // Waking Up Section
                    timeSection(
                        title: "وقت الاستيقاظ",
                        icon: "sunrise.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "F59E0B"), // Amber
                        startBinding: Binding(
                            get: { viewModel.wakingUpStart },
                            set: { viewModel.updateWakingUpStart($0) }
                        ),
                        endBinding: Binding(
                            get: { viewModel.wakingUpEnd },
                            set: { viewModel.updateWakingUpEnd($0) }
                        )
                    )
                    
                    // Morning Section
                    timeSection(
                        title: "وقت الصباح",
                        icon: "sun.max.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "FBBF24"), // Yellow
                        startBinding: Binding(
                            get: { viewModel.morningStart },
                            set: { viewModel.updateMorningStart($0) }
                        ),
                        endBinding: Binding(
                            get: { viewModel.morningEnd },
                            set: { viewModel.updateMorningEnd($0) }
                        )
                    )
                    
                    // Evening Section
                    timeSection(
                        title: "وقت المساء",
                        icon: "sunset.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "F97316"), // Orange
                        startBinding: Binding(
                            get: { viewModel.eveningStart },
                            set: { viewModel.updateEveningStart($0) }
                        ),
                        endBinding: Binding(
                            get: { viewModel.eveningEnd },
                            set: { viewModel.updateEveningEnd($0) }
                        )
                    )
                    
                    // Sleep Section
                    timeSection(
                        title: "وقت النوم",
                        icon: "moon.zzz.fill",
                        iconColor: .white,
                        iconBg: Color(hex: "4F46E5"), // Indigo
                        startBinding: Binding(
                            get: { viewModel.sleepStart },
                            set: { viewModel.updateSleepStart($0) }
                        ),
                        endBinding: Binding(
                            get: { viewModel.sleepEnd },
                            set: { viewModel.updateSleepEnd($0) }
                        )
                    )
                    
                    // After Prayer Section
                    afterPrayerSection
                    
                    Spacer().frame(height: 50)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Views
    
    private func formatTime(_ hour: Int) -> String {
        let period = hour < 12 ? "ص" : "م"
        let hour12 = hour == 0 || hour == 12 ? 12 : hour % 12
        return "\(hour12):00 \(period)"
    }
    
    private func timeSection(title: String, icon: String, iconColor: Color, iconBg: Color, startBinding: Binding<Int>, endBinding: Binding<Int>) -> some View {
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
            
            VStack(spacing: 0) {
                // Start Time
                SettingsRow(
                    title: "من",
                    icon: "clock.arrow.circlepath",
                    iconColor: .white,
                    iconBg: Color.gray.opacity(0.3)
                ) {
                    Picker("", selection: startBinding) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatTime(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)
                }
                
                Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                
                // End Time
                SettingsRow(
                    title: "إلى",
                    icon: "clock.arrow.circlepath",
                    iconColor: .white,
                    iconBg: Color.gray.opacity(0.3)
                ) {
                    Picker("", selection: endBinding) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatTime(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)
                }
            }
            .background(AppColors.onboardingSurface)
            .cornerRadius(16)
        }
    }
    
    private var afterPrayerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("إعدادات الأذان")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
            
            VStack(spacing: 0) {
                SettingsRow(
                    title: "انتظار بعد الأذان (النافذة)",
                    icon: "timer",
                    iconColor: .white,
                    iconBg: AppColors.onboardingPrimary
                ) {
                    Picker("", selection: Binding(
                        get: { viewModel.afterPrayerOffset },
                        set: { viewModel.updateAfterPrayerOffset($0) }
                    )) {
                        ForEach([0, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Text("\(minutes) دقيقة").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.gray)
                }
            }
            .background(AppColors.onboardingSurface)
            .cornerRadius(16)
        }
    }
}

#Preview {
    let container = AppContainer.shared
    let viewModel = SettingsViewModel(
        settingsRepository: container.makeSettingsRepository(),
        locationService: container.locationService,
        hapticsService: container.hapticsService,
        prayerTimeService: container.prayerTimeService,
        modelContext: container.modelContainer.mainContext
    )
    
    TimeConfigSettingsView(viewModel: viewModel)
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
