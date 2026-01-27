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
            modelContext: container.modelContainer.mainContext,
            modelContainer: container.modelContainer
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
                        preferencesSection
                        timeConfigurationSection
                        locationSection
                    }
                    .padding(.horizontal, 24)
                    
                    dataManagementSection
                        .padding(.horizontal, 24)
                    
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


    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("التفضيلات")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                // iCloud Sync
                SettingsRow(
                    title: "مزامنة iCloud",
                    icon: "cloud.fill",
                    iconColor: .white,
                    iconBg: .blue
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.iCloudSyncEnabled },
                        set: { viewModel.updateICloudSyncEnabled($0) }
                    ))
                    .labelsHidden()
                    .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Auto Advance
                SettingsRow(
                    title: "الانتقال التلقائي",
                    icon: "forward.frame.fill",
                    iconColor: .white,
                    iconBg: .green
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.autoAdvance },
                        set: { viewModel.updateAutoAdvance($0) }
                    ))
                    .labelsHidden()
                    .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Haptics Toggle
                SettingsRow(
                    title: "اللمس الاهتزازي",
                    icon: "hand.tap.fill",
                    iconColor: .white,
                    iconBg: .orange
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.hapticsEnabled },
                        set: { viewModel.updateHapticsEnabled($0) }
                    ))
                    .labelsHidden()
                    .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Notifications Toggle
                SettingsRow(
                    title: "إشعارات الأذكار",
                    icon: "bell.badge.fill",
                    iconColor: .white,
                    iconBg: .red
                ) {
                    Toggle("", isOn: Binding(
                        get: { viewModel.notificationsEnabled },
                        set: { viewModel.updateNotificationsEnabled($0) }
                    ))
                    .labelsHidden()
                    .tint(.blue)
                }
                
                if viewModel.hapticsEnabled {
                    Divider().background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("شدة الاهتزاز")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Picker("الشدة", selection: Binding(
                            get: { viewModel.hapticIntensity },
                            set: { viewModel.updateHapticIntensity($0) }
                        )) {
                            ForEach(HapticIntensity.allCases, id: \.self) { intensity in
                                Text(intensity.arabicName).tag(intensity)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                }
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

    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الموقع والمنطقة")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.horizontal, 8)
            
            VStack(spacing: 0) {
                SettingsRow(
                    title: "المدينة الحالية",
                    icon: "mappin.and.ellipse",
                    iconColor: .white,
                    iconBg: .cyan,
                    valueText: viewModel.locationCity ?? "غير محدد"
                )
                
                Divider().background(Color.white.opacity(0.1))
                
                Button {
                    if viewModel.locationPermissionGranted {
                        // In a real app we might trigger a refresh
                        viewModel.requestLocationPermission()
                    } else {
                        viewModel.openAppSettings()
                    }
                } label: {
                    SettingsRow(
                        title: viewModel.locationPermissionGranted ? "تحديث الموقع" : "تفعيل الوصول للموقع",
                        icon: "location.fill",
                        iconColor: .white,
                        iconBg: .blue,
                        showChevron: !viewModel.locationPermissionGranted
                    )
                }
                .buttonStyle(.plain)
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
            
            VStack(spacing: 0) {
                // Header (Pinned)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("أوقاتك المفضلة")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("حدد الأوقات التي تناسب روتين يومك لنذكرك بالأذكار في الوقت المناسب.")
                            .font(.body)
                            .foregroundStyle(AppColors.textGray)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                    
                    // Back Button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 40) // Matched OnboardingView padding (was 20)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Waking Up Section
                        timeSection(
                            title: "أذكار الاستيقاظ",
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
                            title: "أذكار الصباح",
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
                            title: "أذكار المساء",
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
                            title: "أذكار النوم",
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
                        durationSection(
                            title: "أذكار بعد الصلاة",
                            subtitle: "تذكير بالأذكار بعد الأذان بمدة...",
                            icon: "hands.and.sparkles.fill",
                            iconColor: .white,
                            iconBg: Color(hex: "0EA5E9"), // Sky Blue
                            minutesBinding: Binding(
                                get: { viewModel.afterPrayerOffset },
                                set: { viewModel.updateAfterPrayerOffset($0) }
                            )
                        )
                        
                        Spacer().frame(height: 50)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
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
            
            HStack(spacing: 12) {
                // Start Time
                Menu {
                    ForEach(0..<24, id: \.self) { hour in
                        Button(formatTime(hour)) {
                            startBinding.wrappedValue = hour
                        }
                    }
                } label: {
                    HStack {
                        Text("من")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatTime(startBinding.wrappedValue))
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
                            endBinding.wrappedValue = hour
                        }
                    }
                } label: {
                    HStack {
                        Text("إلى")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text(formatTime(endBinding.wrappedValue))
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
    
    private func durationSection(title: String, subtitle: String, icon: String, iconColor: Color, iconBg: Color, minutesBinding: Binding<Int>) -> some View {
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
                        minutesBinding.wrappedValue = min
                    }
                }
            } label: {
                HStack {
                    Text("مدة الانتظار")
                         .font(.caption)
                         .foregroundStyle(.gray)
                    Spacer()
                    Text("\(minutesBinding.wrappedValue) دقيقة")
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

#Preview {
    let container = AppContainer.shared
    let viewModel = SettingsViewModel(
        settingsRepository: container.makeSettingsRepository(),
        locationService: container.locationService,
        hapticsService: container.hapticsService,
        prayerTimeService: container.prayerTimeService,
        modelContext: container.modelContainer.mainContext,
        modelContainer: container.modelContainer
    )
    
    TimeConfigSettingsView(viewModel: viewModel)
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
