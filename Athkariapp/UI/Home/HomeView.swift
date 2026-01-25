import SwiftUI

struct HomeView: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: HomeViewModel?
    @Binding var navigationPath: NavigationPath

    var body: some View {
        Group {
            if let viewModel = viewModel {
                HomeContent(viewModel: viewModel, navigationPath: $navigationPath)
            } else {
                ProgressView()
                    .task { setupViewModel() }
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
            settingsRepository: container.makeSettingsRepository()
        )
    }
}

struct HomeContent: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with date
                headerSection

                // Current dhikr card
                currentDhikrCard

                // Action buttons
                actionButtons

                // Daily summary
                dailySummarySection

                // Today's routine
                routineSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(viewModel.todayHijriDate)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Notifications
                } label: {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("home_title")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 8)
    }

    // MARK: - Current Dhikr Card
    private var currentDhikrCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("current_dhikr")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)

                    Text("asr_athkar")
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.primaryText)
                }

                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(AppColors.secondaryText)
                    }
            }

            Divider()
                .background(AppColors.secondaryText.opacity(0.3))

            Text("not_started_yet")
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.appSecondary, Color.appSecondary.opacity(0.8)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
        )
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Start Dhikr button
            Button {
                if let slot = viewModel.handlePrayedNow() {
                    navigationPath.append(slot)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("start_dhikr")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Prayed Now button
            Button {
                if let slot = viewModel.handlePrayedNow() {
                    navigationPath.append(slot)
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("prayed_now")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.success)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Daily Summary Section
    private var dailySummarySection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Text("daily_summary")
                .font(.title2.bold())
                .foregroundStyle(AppColors.primaryText)

            HStack(spacing: 12) {
                // Prayers completed
                SummaryCard(
                    title: "completed_prayers",
                    value: "٣/٥",
                    subtitle: "very_good",
                    icon: "checkmark.circle.fill",
                    iconColor: AppColors.success
                )

                // Reading time
                SummaryCard(
                    title: "reading_time",
                    value: "١٥ د",
                    subtitle: "surat_alkahf",
                    icon: "book.fill",
                    iconColor: .purple
                )
            }
        }
    }

    // MARK: - Routine Section
    private var routineSection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            HStack {
                Button {
                    // Show all
                } label: {
                    Text("view_all")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.primary)
                }

                Spacer()

                Text("todays_routine")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.primaryText)
            }

            VStack(spacing: 12) {
                RoutineRow(
                    title: "fajr_prayer",
                    time: "٠٥:١٢ ص",
                    status: .completed,
                    icon: "checkmark.circle.fill"
                )

                RoutineRow(
                    title: "morning_athkar",
                    subtitle: "after_fajr",
                    status: .completed,
                    icon: "checkmark.circle.fill"
                )

                RoutineRow(
                    title: "asr_prayer",
                    subtitle: "now",
                    status: .current,
                    icon: "clock.fill",
                    showPrayedButton: true
                ) {
                    if let slot = viewModel.handlePrayedNow() {
                        navigationPath.append(slot)
                    }
                }

                RoutineRow(
                    title: "evening_athkar",
                    time: "٠٦:٤٥ م",
                    status: .notStarted,
                    icon: "moon.fill"
                )
            }
        }
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)

                Spacer()

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            Text(LocalDateTime(title))
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)

            Text(LocalizedStringKey(subtitle))
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
        )
    }
}

// MARK: - Routine Row
struct RoutineRow: View {
    let title: String
    var time: String? = nil
    var subtitle: String? = nil
    let status: RoutineStatus
    let icon: String
    var showPrayedButton: Bool = false
    var onPrayed: (() -> Void)? = nil

    enum RoutineStatus {
        case completed, current, notStarted
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIndicator

            Spacer()

            // Text content
            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)

                if let time = time {
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }

                if let subtitle = subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(.caption)
                        .foregroundStyle(status == .current ? AppColors.success : AppColors.secondaryText)
                }
            }

            // Icon
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: icon)
                        .foregroundStyle(iconForegroundColor)
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .stroke(status == .current ? AppColors.success.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if showPrayedButton {
            Button {
                onPrayed?()
            } label: {
                Text("did_you_pray")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(AppColors.success, lineWidth: 1)
                    )
            }
        } else {
            Text(LocalizedStringKey(statusText))
                .font(.caption.bold())
                .foregroundStyle(statusTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(statusBackgroundColor)
                )
        }
    }

    private var statusText: String {
        switch status {
        case .completed: return "completed"
        case .current: return "now"
        case .notStarted: return "not_started"
        }
    }

    private var statusTextColor: Color {
        switch status {
        case .completed: return AppColors.success
        case .current: return AppColors.success
        case .notStarted: return AppColors.notStarted
        }
    }

    private var statusBackgroundColor: Color {
        switch status {
        case .completed: return AppColors.success.opacity(0.2)
        case .current: return AppColors.success.opacity(0.2)
        case .notStarted: return AppColors.notStarted.opacity(0.2)
        }
    }

    private var iconBackgroundColor: Color {
        switch status {
        case .completed: return AppColors.success
        case .current: return AppColors.primary
        case .notStarted: return Color.cardBackground
        }
    }

    private var iconForegroundColor: Color {
        switch status {
        case .completed, .current: return AppColors.primaryText
        case .notStarted: return AppColors.secondaryText
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(navigationPath: .constant(NavigationPath()))
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
