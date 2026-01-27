import SwiftUI
import Charts
import SwiftData

@MainActor
@Observable
final class StatisticsViewModel {
    enum TimeRange: String, CaseIterable {
        case week = "الأسبوعي"
        case month = "شهري"
        case year = "سنوي"
    }
    
    // MARK: - Published State
    var selectedRange: TimeRange = .week
    var totalDhikrs: Int = 0
    var currentStreak: Int = 0
    var chartData: [(label: String, count: Int)] = []
    var distributionData: [(category: String, count: Int, color: Color)] = []
    var heatmapData: [Date: Int] = [:]
    var bestTime: String = "—"
    var growthPercentage: Double = 0
    var isLoading: Bool = false
    var consistencyScore: Int = 0
    
    // MARK: - Dependencies
    private let repository: SessionRepository
    private let haptics: HapticsService
    
    init(repository: SessionRepository, haptics: HapticsService) {
        self.repository = repository
        self.haptics = haptics
    }
    
    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await calculateStats()
        } catch {
            print("Error calculating statistics: \(error)")
        }
    }
    
    func setRange(_ range: TimeRange) {
        guard selectedRange != range else { return }
        haptics.playSelection()
        selectedRange = range
        Task { await loadData() }
    }
    
    // MARK: - Calculation Logic
    private func calculateStats() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let allSessions = try modelContextFetchAll()
        totalDhikrs = allSessions.reduce(0) { $0 + $1.totalDhikrsCount }
        
        // 1. Calculate Chart Data based on range
        try calculateChartData(allSessions: allSessions, calendar: calendar, today: today)
        
        // 2. Calculate Distribution
        calculateDistribution(sessions: allSessions)
        
        // 3. Activity Heatmap
        heatmapData = Dictionary(grouping: allSessions, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { $0.reduce(0) { $1.sessionStatus == .completed ? $0 + 1 : $0 } }
        
        // 4. Consistency & Growth
        calculateConsistencyAndGrowth(allSessions: allSessions, calendar: calendar, today: today)
        
        // 5. Current Streak
        currentStreak = calculateStreak(sessions: allSessions, calendar: calendar, today: today)
        
        // 6. Best Time
        bestTime = calculateBestTime(sessions: allSessions)
    }
    
    private func calculateChartData(allSessions: [SessionState], calendar: Calendar, today: Date) throws {
        switch selectedRange {
        case .week:
            let weekdays = ["س", "ح", "ن", "ث", "ر", "خ", "ج"]
            var weeklyCounts: [Int] = Array(repeating: 0, count: 7)
            for i in 0..<7 {
                let targetDate = calendar.date(byAdding: .day, value: -6 + i, to: today)!
                let dayStart = calendar.startOfDay(for: targetDate)
                weeklyCounts[i] = allSessions.filter { calendar.startOfDay(for: $0.date) == dayStart }
                    .reduce(0) { $0 + $1.totalDhikrsCount }
            }
            chartData = zip(weekdays, weeklyCounts).map { (label: $0, count: $1) }
            
        case .month:
            // Group by 4 weeks
            chartData = (0..<4).reversed().map { weekOffset in
                let end = calendar.date(byAdding: .day, value: -weekOffset * 7, to: today)!
                let start = calendar.date(byAdding: .day, value: -6, to: end)!
                let count = allSessions.filter { $0.date >= start && $0.date <= end }
                    .reduce(0) { $0 + $1.totalDhikrsCount }
                return (label: "أسبوع \(4-weekOffset)", count: count)
            }
            
        case .year:
            let months = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
            chartData = months.enumerated().map { index, name in
                let count = allSessions.filter { calendar.component(.month, from: $0.date) == index + 1 }
                    .reduce(0) { $0 + $1.totalDhikrsCount }
                return (label: name, count: count)
            }
        }
    }
    
    private func calculateDistribution(sessions: [SessionState]) {
        let counts = sessions.reduce(into: [String: Int]()) { dict, session in
            let name = SlotKey(rawValue: session.slotKey)?.arabicName ?? "أخرى"
            dict[name, default: 0] += session.totalDhikrsCount
        }
        
        let colors: [Color] = [AppColors.onboardingPrimary, .orange, .cyan, .purple, .pink, .indigo]
        distributionData = counts.enumerated().map { index, pair in
            (category: pair.key, count: pair.value, color: colors[index % colors.count])
        }
        .sorted { $0.count > $1.count }
        .prefix(5).map { $0 }
    }
    
    private func calculateConsistencyAndGrowth(allSessions: [SessionState], calendar: Calendar, today: Date) {
        // Last 30 days consistency
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let sessionDays = Set(allSessions.filter { $0.date >= thirtyDaysAgo }.map { calendar.startOfDay(for: $0.date) })
        consistencyScore = Int(Double(sessionDays.count) / 30.0 * 100)
        
        // Growth calculation for chart label
        let currentWeekTotal = chartData.reduce(0) { $0 + $1.count }
        let lastWeekEnd = calendar.date(byAdding: .day, value: -7, to: today)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -13, to: lastWeekEnd)!
        let previousWeekTotal = allSessions.filter { $0.date >= lastWeekStart && $0.date <= lastWeekEnd }
            .reduce(0) { $0 + $1.totalDhikrsCount }
            
        if previousWeekTotal > 0 {
            growthPercentage = Double(currentWeekTotal - previousWeekTotal) / Double(previousWeekTotal) * 100
        } else {
            growthPercentage = currentWeekTotal > 0 ? 100 : 0
        }
    }
    
    private func modelContextFetchAll() throws -> [SessionState] {
        return try repository.fetchSessionsForDateRange(from: .distantPast, to: .distantFuture)
    }
    
    private func calculatePreviousWeekTotal(calendar: Calendar, today: Date) throws -> Int {
        let lastWeekEnd = calendar.date(byAdding: .day, value: -7, to: today)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -13, to: today)!
        let sessions = try repository.fetchSessionsForDateRange(from: lastWeekStart, to: lastWeekEnd)
        return sessions.reduce(0) { $0 + $1.totalDhikrsCount }
    }
    
    private func calculateStreak(sessions: [SessionState], calendar: Calendar, today: Date) -> Int {
        let completedDays = Set(sessions.filter { $0.sessionStatus == .completed }.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var checkDate = today
        
        if !completedDays.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        }
        
        while completedDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        
        return streak
    }
    
    private func calculateBestTime(sessions: [SessionState]) -> String {
        let counts = sessions.reduce(into: [String: Int]()) { dict, session in
            let name = SlotKey(rawValue: session.slotKey)?.arabicName ?? "—"
            dict[name, default: 0] += 1
        }
        
        return counts.max { $0.value < $1.value }?.key ?? "—"
    }
}

@MainActor
struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container
    @State private var viewModel: StatisticsViewModel?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                StatisticsContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .task { setupViewModel() }
            }
        }
    }
    
    private func setupViewModel() {
        viewModel = StatisticsViewModel(
            repository: container.makeSessionRepository(),
            haptics: container.hapticsService
        )
    }
}

struct StatisticsContent: View {
    @Bindable var viewModel: StatisticsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.homeBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    
                    Spacer()
                    
                    Text("إحصائيات الذكر")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Empty space for balance
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Summary Grid (Top Stats)
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "إجمالي الأذكار",
                                    value: viewModel.totalDhikrs.formatted(),
                                    icon: "sparkles",
                                    color: .white
                                )
                                
                                StatCard(
                                    title: "سلسلة الأيام",
                                    value: "\(viewModel.currentStreak) أيام",
                                    icon: "flame.fill",
                                    color: AppColors.onboardingPrimary
                                )
                            }
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "نسبة الالتزام",
                                    value: "\(viewModel.consistencyScore)%",
                                    icon: "target",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "أكثر وقت",
                                    value: viewModel.bestTime,
                                    icon: "clock.fill",
                                    color: .cyan
                                )
                            }
                        }
                        
                        // 2. Trend Analytics Chart
                        VStack(spacing: 20) {
                            HStack(spacing: 0) {
                                ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                                    TimeSegmentItem(
                                        title: range.rawValue,
                                        isSelected: viewModel.selectedRange == range
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring()) {
                                            viewModel.setRange(range)
                                        }
                                    }
                                    
                                    if range != StatisticsViewModel.TimeRange.allCases.last {
                                        Spacer()
                                    }
                                }
                            }
                            .padding(6)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )

                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("الأذكار المكتملة")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppColors.textGray)
                                    
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(viewModel.totalDhikrs.formatted())
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(.white)
                                            .contentTransition(.numericText())
                                        
                                        HStack(spacing: 2) {
                                            Image(systemName: viewModel.growthPercentage >= 0 ? "arrow.up" : "arrow.down")
                                                .font(.caption)
                                            Text("\(Int(abs(viewModel.growthPercentage)))%")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                        .foregroundStyle(viewModel.growthPercentage >= 0 ? AppColors.onboardingPrimary : .red)
                                        .opacity(viewModel.selectedRange == .week ? 1 : 0)
                                    }
                                }
                                
                                Chart {
                                    ForEach(viewModel.chartData, id: \.label) { item in
                                        if viewModel.selectedRange == .year {
                                            BarMark(
                                                x: .value("Day", item.label),
                                                y: .value("Count", item.count)
                                            )
                                            .foregroundStyle(AppColors.onboardingPrimary.gradient)
                                            .cornerRadius(4)
                                        } else {
                                            AreaMark(
                                                x: .value("Day", item.label),
                                                y: .value("Count", item.count)
                                            )
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [AppColors.onboardingPrimary.opacity(0.3), AppColors.onboardingPrimary.opacity(0)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .interpolationMethod(.catmullRom)

                                            LineMark(
                                                x: .value("Day", item.label),
                                                y: .value("Count", item.count)
                                            )
                                            .foregroundStyle(AppColors.onboardingPrimary)
                                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                            .interpolationMethod(.catmullRom)
                                        }
                                    }
                                }
                                .frame(height: 180)
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel()
                                            .foregroundStyle(AppColors.textGray)
                                            .font(.caption2)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisValueLabel()
                                            .foregroundStyle(AppColors.textGray)
                                            .font(.system(size: 8))
                                    }
                                }
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(AppColors.onboardingSurface.opacity(0.4))
                                    .background(.ultraThinMaterial)
                            )
                            .cornerRadius(32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.15), .white.opacity(0.02)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        }

                        // 3. Category Distribution
                        VStack(alignment: .leading, spacing: 20) {
                            Text("توزيع الأذكار")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 24) {
                                Chart(viewModel.distributionData, id: \.category) { item in
                                    SectorMark(
                                        angle: .value("Count", item.count),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(item.color)
                                    .cornerRadius(4)
                                }
                                .frame(width: 140, height: 140)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(viewModel.distributionData, id: \.category) { item in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(item.color)
                                                .frame(width: 8, height: 8)
                                            Text(item.category)
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textGray)
                                            Spacer()
                                            Text("\(item.count)")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(AppColors.onboardingSurface.opacity(0.4))
                                .background(.ultraThinMaterial)
                        )
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .white.opacity(0.02)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        
                        // 4. Activity Heatmap
                        VStack(alignment: .leading, spacing: 16) {
                            Text("نشاط الذكر")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            ContributionHeatmap(data: viewModel.heatmapData)
                                .frame(height: 120)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(AppColors.onboardingSurface.opacity(0.4))
                                .background(.ultraThinMaterial)
                        )
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.15), .white.opacity(0.02)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .overlay(alignment: .top) {
                    // Subtle fade-out at the top of scroll
                    LinearGradient(
                        colors: [AppColors.homeBackground, AppColors.homeBackground.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 12)
                    .allowsHitTesting(false)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct TimeSegmentItem: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(isSelected ? .black : AppColors.tertiaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(Capsule())
    }
}

struct ContributionHeatmap: View {
    let data: [Date: Int]
    private let calendar = Calendar.current
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<140) { index in
                    let date = calendar.date(byAdding: .day, value: -139 + index, to: Date())!
                    let count = data[calendar.startOfDay(for: date)] ?? 0
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(for: count))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 4)
        }
        .flipsForRightToLeftLayoutDirection(true)
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private func heatmapColor(for count: Int) -> Color {
        if count == 0 { return Color.white.opacity(0.05) }
        if count == 1 { return AppColors.onboardingPrimary.opacity(0.3) }
        if count == 2 { return AppColors.onboardingPrimary.opacity(0.6) }
        return AppColors.onboardingPrimary
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.2), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.textGray)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                AppColors.onboardingSurface.opacity(0.8)
                
                // Subtle mesh-like glow
                RadialGradient(
                    colors: [color.opacity(0.12), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 100
                )
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
    }
}
