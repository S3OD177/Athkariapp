import SwiftUI

struct HomeView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: HomeViewModel?
    @Binding var navigationPath: NavigationPath
    @Binding var pendingSessionAction: SessionLaunchAction

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
            SessionView(
                slotKey: slotKey,
                pendingLaunchAction: $pendingSessionAction
            )
        }
    }

    private func setupViewModel() {
        viewModel = HomeViewModel(
            sessionRepository: container.makeSessionRepository(),
            dhikrRepository: container.makeDhikrRepository(),
            prayerTimeService: container.prayerTimeService,
            settingsRepository: container.makeSettingsRepository(),
            locationService: container.locationService,
            liveActivityCoordinator: container.liveActivityCoordinator,
            widgetSnapshotCoordinator: container.widgetSnapshotCoordinator
        )
    }
}

struct HomeContent: View {
    let viewModel: HomeViewModel
    @Binding var navigationPath: NavigationPath
    
    // Sticky Header Properties
    @State private var scrollOffset: CGFloat = 0
    @State private var hasLoadedInitialData = false
    private let stickyHeaderHeight: CGFloat = 118

    var body: some View {
        ZStack {
            // Background
            AppColors.homeBackground.ignoresSafeArea()
            
            ZStack(alignment: .top) {
                // Main Scroll Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Spacer for Header
                        Color.clear.frame(height: stickyHeaderHeight)
                        
                        // Location Warning
                        if viewModel.showLocationWarning {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "location.slash.fill")
                                        .foregroundStyle(.white)
                                    
                                    Text("يرجى تفعيل الموقع للحصول على مواقيت الصلاة")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.left")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
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
            guard !hasLoadedInitialData else { return }
            hasLoadedInitialData = true
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
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.userName.isEmpty ? "أذكاري" : "مرحباً، \(viewModel.userName)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(viewModel.todayHijriDate.isEmpty ? "وردك اليومي" : viewModel.todayHijriDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textGray)
                }

                Spacer()

                if let progress = viewModel.dailySummary.isEmpty ? nil : Optional(viewModel.formattedProgress) {
                    Text(progress)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.onboardingPrimary.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.onboardingPrimary.opacity(0.35), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)
            
            // Date Row Removed
            
            Divider()
                .background(Color.white.opacity(0.1))
        }
        .padding(.bottom, 0)
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
                        VStack(alignment: .leading, spacing: 0) {
                            Text(viewModel.hasActiveEvent ? "الذكر الحالي" : "الذكر القادم")
                                .font(.system(size: 14, weight: .semibold))
                                .opacity(0.7)

                            if viewModel.hasActiveEvent {
                                heroTitle(viewModel.activeSummaryItem?.title ?? "أذكار المسلم")
                            } else if let next = viewModel.nextUpcomingEvent {
                                heroTitle(next.name)
                            } else {
                                heroTitle("لا يوجد ذكر حالي")
                            }
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: viewModel.hasActiveEvent ? (viewModel.activeSummaryItem?.icon ?? "hand.raised.fill") : "clock.fill")
                                    .foregroundStyle(Color(hex: "2C261F"))
                            )
                    }
                    
                    VStack(spacing: 8) {
                        // Progress Bar (Only show if active)
                        if viewModel.hasActiveEvent {
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
                        } else {
                            // Divider or simple spacer for gap mode
                            Divider()
                                .background(Color.black.opacity(0.1))
                        }
                        
                        HStack {
                            if let remaining = viewModel.currentEventRemainingTime {
                                // Active Session Mode
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ينتهي الذكر الحالي خلال \(remaining)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.6))
                                    
                                    if let next = viewModel.nextEventName {
                                        Text("التالي: \(next)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.black.opacity(0.4))
                                    }
                                }
                            } else if let nextTime = viewModel.nextEventRemainingTime {
                                // Gap Mode
                                Text("يبدأ بعد \(nextTime)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            if viewModel.hasActiveEvent {
                                Text(statusText(for: viewModel.activeSummaryItem))
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.6)
                            }
                        }
                    }

                    HStack {
                        Spacer()

                        Text(viewModel.hasActiveEvent ? "ابدأ الآن" : "استعد للذكر")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "2C261F"))
                            .clipShape(Capsule())
                    }
                }
                .padding(24)
                .foregroundStyle(Color(hex: "2C261F"))
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 10))
    }

    private func heroTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .heavy))
            .padding(.top, -4)
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
        HStack(spacing: 0) {
            // Hijri Date Section
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.onboardingPrimary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColors.onboardingPrimary)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("التاريخ الهجري")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                    Text(viewModel.todayHijriDate)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 40)
                .padding(.horizontal, 16)
            
            // Next Prayer Section
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.onboardingPrimary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "clock.fill")
                        .foregroundStyle(AppColors.onboardingPrimary)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.nextPrayerName ?? "الصلاة القادمة")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                    
                    if let nextTime = viewModel.nextPrayerTime {
                        Text(nextTime, style: .time)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("--:--")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

                Text(viewModel.formattedProgress)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.onboardingPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.onboardingPrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            
            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                routineMessageCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "تعذر تحميل الأذكار",
                    message: errorMessage,
                    actionTitle: "إعادة المحاولة"
                ) {
                    Task { await viewModel.refreshData() }
                }
            } else if viewModel.dailySummary.isEmpty {
                routineMessageCard(
                    icon: "book.closed.fill",
                    title: "لا توجد أذكار يومية",
                    message: "اسحب للأسفل لتحديث البيانات أو افتح حصن المسلم للتصفح."
                )
            } else {
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
                                color: item.status == .completed ? AppColors.onboardingPrimary : (item.status == .partial || viewModel.activeSummaryItem?.id == item.id ? AppColors.onboardingPrimary : .gray)
                            )
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(DragGesture(minimumDistance: 10))
                    }
                }
            }
        }
    }

    private func routineMessageCard(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppColors.onboardingPrimary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.onboardingPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppColors.onboardingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
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
        HomeView(
            navigationPath: .constant(NavigationPath()),
            pendingSessionAction: .constant(.none)
        )
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
