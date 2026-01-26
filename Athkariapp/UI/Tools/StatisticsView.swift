import SwiftUI
import Charts
import SwiftData

@MainActor
@Observable
final class StatisticsViewModel {
    // MARK: - Published State
    var totalDhikrs: Int = 0
    var currentStreak: Int = 0
    var weeklyData: [(day: String, count: Int)] = []
    var bestTime: String = "—"
    var growthPercentage: Double = 0
    var isLoading: Bool = false
    
    // MARK: - Dependencies
    private let repository: SessionRepository
    
    init(repository: SessionRepository) {
        self.repository = repository
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
    
    // MARK: - Calculation Logic
    private func calculateStats() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 1. Calculate Total Dhikrs
        let allSessions = try modelContextFetchAll() 
        totalDhikrs = allSessions.reduce(0) { $0 + $1.totalDhikrsCount }
        
        // 2. Calculate Weekly Data
        let weekdays = ["س", "ح", "ن", "ث", "ر", "خ", "ج"]
        var weeklyCounts: [Int] = Array(repeating: 0, count: 7)
        
        for i in 0..<7 {
            let targetDate = calendar.date(byAdding: .day, value: -6 + i, to: today)!
            let sessions = try repository.fetchSessionsForDateRange(from: targetDate, to: targetDate)
            weeklyCounts[i] = sessions.reduce(0) { $0 + $1.totalDhikrsCount }
        }
        
        weeklyData = zip(weekdays, weeklyCounts).map { (day: $0, count: $1) }
        
        // 3. Calculate Growth
        let previousWeekTotal = try calculatePreviousWeekTotal(calendar: calendar, today: today)
        let currentWeekTotal = weeklyCounts.reduce(0, +)
        
        if previousWeekTotal > 0 {
            growthPercentage = Double(currentWeekTotal - previousWeekTotal) / Double(previousWeekTotal) * 100
        } else {
            growthPercentage = currentWeekTotal > 0 ? 100 : 0
        }
        
        // 4. Calculate Current Streak
        currentStreak = calculateStreak(sessions: allSessions, calendar: calendar, today: today)
        
        // 5. Calculate Best Time
        bestTime = calculateBestTime(sessions: allSessions)
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
        viewModel = StatisticsViewModel(repository: container.makeSessionRepository())
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
                    Color.clear.frame(width: 40, height: 40)
                    Spacer()
                    Text("إحصائيات الذكر")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "xmark")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Main Summary Card
                        VStack(spacing: 24) {
                            HStack {
                                TimeSegmentItem(title: "الأسبوعي", isSelected: true)
                                Spacer()
                                TimeSegmentItem(title: "شهري", isSelected: false)
                                Spacer()
                                TimeSegmentItem(title: "سنوي", isSelected: false)
                            }
                            .padding(8)
                            .background(AppColors.onboardingSurface)
                            .clipShape(Capsule())
                            
                            // Weekly Chart
                            VStack(alignment: .leading, spacing: 8) {
                                Text("عدد الأذكار المكتملة")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.textGray)
                                
                                HStack(alignment: .firstTextBaseline) {
                                    Text(viewModel.totalDhikrs.arabicNumeral)
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundStyle(.white)
                                        .contentTransition(.numericText())
                                    
                                    HStack(spacing: 2) {
                                        Image(systemName: viewModel.growthPercentage >= 0 ? "arrow.up" : "arrow.down")
                                            .font(.caption)
                                        Text("\(Int(abs(viewModel.growthPercentage)).arabicNumeral)%")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(viewModel.growthPercentage >= 0 ? AppColors.appPrimary : .red)
                                }
                                
                                // Chart Implementation
                                Chart {
                                    ForEach(viewModel.weeklyData, id: \.day) { item in
                                        BarMark(
                                            x: .value("Day", item.day),
                                            y: .value("Count", item.count)
                                        )
                                        .foregroundStyle(AppColors.onboardingPrimary.gradient)
                                        .cornerRadius(4)
                                    }
                                }
                                .frame(height: 200)
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel()
                                            .foregroundStyle(AppColors.textGray)
                                    }
                                }
                                .chartYAxis(.hidden)
                            }
                            .padding(24)
                            .background(AppColors.onboardingSurface)
                            .cornerRadius(32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                        }
                        
                        // Summary Grid
                        HStack(spacing: 16) {
                            StatCard(
                                title: "إجمالي الأذكار",
                                value: viewModel.totalDhikrs.arabicNumeral,
                                icon: "sparkles",
                                color: .white
                            )
                            
                            StatCard(
                                title: "سلسلة الأيام",
                                value: "\(viewModel.currentStreak.arabicNumeral) أيام",
                                icon: "flame.fill",
                                color: AppColors.onboardingPrimary
                            )
                        }
                        
                        // Best Time Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("أكثر وقت للذكر")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.textGray)
                                Text(viewModel.bestTime)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(AppColors.onboardingPrimary.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "clock.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppColors.onboardingPrimary)
                            }
                        }
                        .padding(20)
                        .background(AppColors.onboardingSurface)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        
                        // Achievements
                        VStack(alignment: .leading, spacing: 16) {
                            Text("إنجازات أخيرة")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    AchievementBadge(title: "٧ أيام متتالية", icon: "seal.fill", isUnlocked: viewModel.currentStreak >= 7)
                                    AchievementBadge(title: "أذكار الصباح", icon: "sun.max.fill", isUnlocked: true)
                                    AchievementBadge(title: "١٠٠٠ تسبيحة", icon: "star.fill", isUnlocked: viewModel.totalDhikrs >= 1000)
                                }
                            }
                        }
                    }
                    .padding(24)
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
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(isSelected ? .black : AppColors.tertiaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(Capsule())
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.caption)
                }
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textGray)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppColors.onboardingSurface)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    var isUnlocked: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppColors.onboardingPrimary.opacity(isUnlocked ? 0.3 : 0.1), lineWidth: 2)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .stroke(isUnlocked ? AppColors.onboardingPrimary : AppColors.textGray.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: isUnlocked ? [] : [4]))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .foregroundStyle(isUnlocked ? AppColors.onboardingPrimary : AppColors.textGray.opacity(0.3))
                    .font(.title2)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(isUnlocked ? .white : AppColors.textGray)
        }
        .padding(16)
        .background(AppColors.onboardingSurface)
        .cornerRadius(20)
        .frame(width: 120)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
