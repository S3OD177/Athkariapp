import SwiftUI
import CoreLocation
import Charts

enum AppTab: String, CaseIterable {
    case home = "home"
    case athkar = "athkar"
    case tools = "tools"
    case settings = "settings"

    var title: String {
        switch self {
        case .home: return "الرئيسية"
        case .athkar: return "الأذكار"
        case .tools: return "الأدوات"
        case .settings: return "الإعدادات"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .athkar: return "book"
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var navigationPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep all views alive, show/hide with opacity
            ZStack {
                NavigationStack(path: $navigationPath) {
                    HomeView(navigationPath: $navigationPath)
                }
                .opacity(selectedTab == .home ? 1 : 0)
                .zIndex(selectedTab == .home ? 1 : 0)
                
                NavigationStack {
                    HisnLibraryView()
                }
                .opacity(selectedTab == .athkar ? 1 : 0)
                .zIndex(selectedTab == .athkar ? 1 : 0)
                
                NavigationStack {
                    ToolsView()
                }
                .opacity(selectedTab == .tools ? 1 : 0)
                .zIndex(selectedTab == .tools ? 1 : 0)
                
                NavigationStack {
                    SettingsView()
                }
                .opacity(selectedTab == .settings ? 1 : 0)
                .zIndex(selectedTab == .settings ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            
            // Custom Floating Tab Bar
            customTabBar
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarItem(icon: "house", title: "الرئيسية", isSelected: selectedTab == .home)
                .onTapGesture {
                    if selectedTab == .home {
                        // Already on home, pop to root
                        navigationPath = NavigationPath()
                    } else {
                        selectedTab = .home
                    }
                }
            
            TabBarItem(icon: "book", title: "الأذكار", isSelected: selectedTab == .athkar)
                .onTapGesture { selectedTab = .athkar }
            
            TabBarItem(icon: "wrench.and.screwdriver", title: "الأدوات", isSelected: selectedTab == .tools)
                .onTapGesture { selectedTab = .tools }
            
            TabBarItem(icon: "gearshape", title: "الإعدادات", isSelected: selectedTab == .settings)
                .onTapGesture { selectedTab = .settings }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(AppColors.onboardingSurface.opacity(0.9))
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        .padding(.horizontal, 16)
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if isSelected {
                HStack(spacing: 8) {
                    Image(systemName: "\(icon).fill")
                        .font(.system(size: 18))
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.onboardingPrimary)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            } else {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    MainTabView()
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}

// MARK: - Tools Section

struct ToolsView: View {
    @State private var showingQibla = false
    @State private var showingTasbih = false
    @State private var showingHijri = false
    @State private var showingZakat = false
    @State private var showingStats = false
    @State private var showingPrayerTimes = false
    
    // Stable chart heights for the weekly progress visualization
    private let chartHeights: [CGFloat] = [65, 85, 55, 95, 70, 80, 60]
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Text("أدوات إضافية")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        
                        Button {
                            // Settings/Profile action
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundStyle(AppColors.onboardingPrimary)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
                    
                    // Tools Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ToolCard(
                            title: "اتجاه القبلة",
                            subtitle: "البوصلة",
                            icon: "compass.drawing",
                            iconBg: Color(hex: "E6F7F0"),
                            iconColor: AppColors.onboardingPrimary,
                            isComingSoon: true
                        ) {
                            showingQibla = true
                        }
                        
                        ToolCard(
                            title: "المسبحة الإلكترونية",
                            subtitle: "تسابيح ذكية",
                            icon: "number.circle.fill",
                            iconBg: Color(hex: "E6F1FF"),
                            iconColor: Color(hex: "3B82F6")
                        ) {
                            showingTasbih = true
                        }
                        
                        ToolCard(
                            title: "التقويم الهجري",
                            subtitle: "التاريخ الهجري",
                            icon: "calendar",
                            iconBg: Color(hex: "F0FDF4"),
                            iconColor: Color(hex: "22C55E")
                        ) {
                            showingHijri = true
                        }
                        
                        ToolCard(
                            title: "حاسبة الزكاة",
                            subtitle: "حساب النصاب",
                            icon: "banknote.fill", // Or generic finance icon
                            iconBg: Color(hex: "F0FDF4"),
                            iconColor: Color(hex: "22C55E")
                        ) {
                            showingZakat = true
                        }
                        
                        ToolCard(
                            title: "مواقيت الصلاة",
                            subtitle: "متابعة الأوقات",
                            icon: "clock.fill",
                            iconBg: Color(hex: "F0FDF4"),
                            iconColor: Color(hex: "22C55E")
                        ) {
                            showingPrayerTimes = true
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Statistics Section (clickable)
                    Button {
                        showingStats = true
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("إحصائيات")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .foregroundStyle(.gray)
                            }
                            .padding(.horizontal, 24)
                            
                            VStack(spacing: 20) {
                                // Weekly Progress Placeholder
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("التقدم الأسبوعي")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.gray)
                                    
                                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                                        Text("١,٢٥٠")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text("ذكر")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.gray)
                                        
                                        Spacer()
                                        
                                        Text("+١٢%")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.onboardingPrimary.opacity(0.1))
                                            .foregroundStyle(AppColors.success)
                                            .clipShape(Capsule())
                                    }
                                    
                                    // Simplified Chart Placeholder
                                    HStack(alignment: .bottom, spacing: 12) {
                                        ForEach(0..<7, id: \.self) { index in
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(AppColors.onboardingPrimary)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: chartHeights[index])
                                        }
                                    }
                                    .padding(.top, 10)
                                }
                                .padding(24)
                                .background(AppColors.onboardingSurface)
                                .cornerRadius(32)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Tip Card
                    HStack(spacing: 16) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.onboardingPrimary)
                        
                        Text("هل تعلم؟ الحفاظ على وردك اليومي من الأذكار يزيد من السكينة والطمأنينة في يومك.")
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .foregroundStyle(.white)
                    }
                    .padding(20)
                    .background(AppColors.onboardingSurface.opacity(0.5))
                    .cornerRadius(24)
                    .padding(.horizontal, 16)
                    
                    Spacer().frame(height: 100)
                }
            }
        }
        .fullScreenCover(isPresented: $showingQibla) {
            QiblaView()
        }
        .fullScreenCover(isPresented: $showingTasbih) {
            TasbihView()
        }
        .fullScreenCover(isPresented: $showingHijri) {
            HijriCalendarView()
        }
        .fullScreenCover(isPresented: $showingZakat) {
            ZakatCalculatorView()
        }
        .fullScreenCover(isPresented: $showingStats) {
            StatisticsView()
        }
        .fullScreenCover(isPresented: $showingPrayerTimes) {
            PrayerTimesView()
        }
    }
}








struct ToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconBg: Color
    let iconColor: Color
    var isComingSoon: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button {
            if !isComingSoon {
                action()
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if isComingSoon {
                        Text("قريباً")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.onboardingPrimary.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(iconBg)
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(isComingSoon ? "متوفر في الإصدار القادم" : subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.gray)
                }
            }
            .padding(16)
            .background(AppColors.onboardingSurface)
            .opacity(isComingSoon ? 0.6 : 1.0)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isComingSoon ? Color.clear : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}










