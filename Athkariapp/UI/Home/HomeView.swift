import SwiftUI

struct HomeView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: HomeViewModel?
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ZStack {
            // Show background immediately to avoid flash
            AppColors.homeBackground.ignoresSafeArea()
            
            if let viewModel = viewModel {
                HomeContent(viewModel: viewModel, navigationPath: $navigationPath)
            }
        }
        .onAppear {
            if viewModel == nil {
                setupViewModel()
            }
        }
        .navigationDestination(for: SlotKey.self) { slotKey in
            SessionView(slotKey: slotKey)
        }
    }

    private func setupViewModel() {
        viewModel = HomeViewModel(
            sessionRepository: container.makeSessionRepository(),
            dhikrRepository: container.makeDhikrRepository(),
            prayerTimeService: container.prayerTimeService,
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService
        )
    }
}

struct HomeContent: View {
    let viewModel: HomeViewModel
    @Binding var navigationPath: NavigationPath
    
    // Sticky Header Properties
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            AppColors.homeBackground.ignoresSafeArea()
            
            ZStack(alignment: .top) {
                // Main Scroll Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Spacer for Header
                        Color.clear.frame(height: 90)
                        
                        
                        heroCard
                        summaryGrid
                        routineSection
                        
                        // Bottom Spacer for Tab Bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                }
                
                // Sticky Header
                stickyHeader
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didClearData)) { _ in
            Task {
                await viewModel.refreshData()
            }
        }
    }

    // MARK: - Sticky Header
    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // Title Row with Notification Button
            HStack {
                Text("أذكاري")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                // Notifications Button
                Button {
                    // Action
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "bell")
                                .foregroundStyle(Color.white)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // Date Row
            HStack {
                Text(viewModel.todayHijriDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gray)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
        }
        .padding(.bottom, 8)
        .background(AppColors.homeBackground)
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        Button {
            if let slot = viewModel.currentSlot {
                navigationPath.append(slot)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(AppColors.homeBeigeCard)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("الذكر الحالي")
                                .font(.system(size: 14, weight: .semibold))
                                .opacity(0.7)
                            
                            Text(viewModel.activeSummaryItem?.title ?? "أذكار المسلم")
                                .font(.system(size: 24, weight: .heavy))
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: viewModel.activeSummaryItem?.icon ?? "hand.raised.fill")
                                    .foregroundStyle(Color(hex: "2C261F"))
                            )
                    }
                    
                    VStack(spacing: 8) {
                        // Progress Bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.black.opacity(0.1))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(Color(hex: "2C261F"))
                                    .frame(width: proxy.size.width * (viewModel.activeSummaryItem?.progress ?? 0), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        HStack {
                            if let countdown = viewModel.postPrayerCountdown {
                                Text("متاح بعد \(countdown)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Text(statusText(for: viewModel.activeSummaryItem))
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.6)
                        }
                    }
                }
                .padding(24)
                .foregroundStyle(Color(hex: "2C261F"))
            }
        }
        .buttonStyle(.plain)
    }

    private func statusText(for item: DailySummaryItem?) -> String {
        guard let item = item else { return "" }
        if item.status == .completed {
            return "مكتمل"
        } else {
            return "\(item.completedCount)/\(item.totalCount) مكتمل"
        }
    }


    // MARK: - Summary Grid
    private var summaryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ملخص اليوم")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            HStack(spacing: 12) {
                summaryCard(title: "أذكار اليوم", value: viewModel.formattedProgress, badge: "متفوق", icon: "sparkles", color: AppColors.appPrimary)
                summaryCard(title: "الورد الحالي", value: viewModel.activeSummaryItem?.title ?? "أذكار", badge: "الآن", icon: "book.fill", color: .purple)
            }
        }
    }

    private func summaryCard(title: String, value: String, badge: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon == "prayer_times" ? "bolt.fill" : "book.fill") // Map to proper icons
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Spacer()
                
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(AppColors.onboardingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Routine Section
    private var routineSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("أذكار المسلم اليومية")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.top, 8)
            
            VStack(spacing: 12) {
                ForEach(viewModel.dailySummary) { item in
                    Button {
                        if let firstSlot = item.slots.first {
                            navigationPath.append(firstSlot)
                        }
                    } label: {
                        RoutineListItem(
                            title: item.title,
                            subtitle: item.status == .completed ? "مكتمل" : (item.status == .partial ? "قيد القراءة" : "تحتاج للقراءة"),
                            status: mapStatus(item),
                            icon: item.icon,
                            color: item.status == .completed ? AppColors.appPrimary : (item.status == .partial || viewModel.activeSummaryItem?.id == item.id ? AppColors.onboardingPrimary : .gray)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    

    private func mapStatus(_ item: DailySummaryItem) -> RoutineListItem.RoutineStatus {
        switch item.status {
        case .completed: return .completed
        case .partial: return .inProgress
        case .notStarted:
            // Check against the dynamically calculated active item from ViewModel
            if let activeId = viewModel.activeSummaryItem?.id, item.id == activeId {
                return .active
            }
            return .notStarted
        }
    }
}

struct RoutineListItem: View {
    let title: String
    let subtitle: String
    let status: RoutineStatus
    let icon: String
    let color: Color
    
    enum RoutineStatus {
        case completed, inProgress, active, notStarted
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(status == .completed ? .gray : .primaryText)
                    .strikethrough(status == .completed, color: .gray)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle((status == .active || status == .inProgress) ? AppColors.onboardingPrimary : .gray)
            }
            
            Spacer()
            
            // Badge/Button
            if status == .active || status == .inProgress {
                Text(status == .inProgress ? "تابع القراءة" : "ابدأ الآن")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.onboardingPrimary)
                    .clipShape(Capsule())
            } else {
                Text(status == .completed ? "مكتمل" : "لم يبدأ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(AppColors.onboardingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke((status == .active || status == .inProgress) ? AppColors.onboardingPrimary.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Previews
#Preview {
    NavigationStack {
        HomeView(navigationPath: .constant(NavigationPath()))
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
