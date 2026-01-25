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
                    .foregroundStyle(.gray)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Notifications
                } label: {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.gray)
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
            Text("أذكاري")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
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
                    Text("الذكر الحالي")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    Text("أذكار بعد العصر")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            Text("لم يبدأ بعد")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.9, blue: 0.8), Color(red: 0.9, green: 0.85, blue: 0.75)],
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
                    Text("ابدأ الذكر")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
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
                    Text("صليت الآن")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Daily Summary Section
    private var dailySummarySection: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Text("ملخص اليوم")
                .font(.title2.bold())
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                // Prayers completed
                SummaryCard(
                    title: "الصلوات المكتملة",
                    value: "٣/٥",
                    subtitle: "جيد جداً",
                    icon: "checkmark.circle.fill",
                    iconColor: .green
                )

                // Reading time
                SummaryCard(
                    title: "وقت القراءة",
                    value: "١٥ د",
                    subtitle: "سورة الكهف",
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
                    Text("عرض الكل")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text("روتين اليوم")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                RoutineRow(
                    title: "صلاة الفجر",
                    time: "٠٥:١٢ ص",
                    status: .completed,
                    icon: "checkmark.circle.fill"
                )

                RoutineRow(
                    title: "أذكار الصباح",
                    subtitle: "بعد الفجر",
                    status: .completed,
                    icon: "checkmark.circle.fill"
                )

                RoutineRow(
                    title: "صلاة العصر",
                    subtitle: "الآن",
                    status: .current,
                    icon: "clock.fill",
                    showPrayedButton: true
                ) {
                    if let slot = viewModel.handlePrayedNow() {
                        navigationPath.append(slot)
                    }
                }

                RoutineRow(
                    title: "أذكار المساء",
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
                    .foregroundStyle(.gray)

                Spacer()

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.1))
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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                if let time = time {
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(status == .current ? .green : .gray)
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
                .fill(Color(white: 0.1))
                .stroke(status == .current ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if showPrayedButton {
            Button {
                onPrayed?()
            } label: {
                Text("صليت؟")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .stroke(Color.green, lineWidth: 1)
                    )
            }
        } else {
            Text(statusText)
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
        case .completed: return "مكتمل"
        case .current: return "الآن"
        case .notStarted: return "لم يبدأ"
        }
    }

    private var statusTextColor: Color {
        switch status {
        case .completed: return .green
        case .current: return .green
        case .notStarted: return .gray
        }
    }

    private var statusBackgroundColor: Color {
        switch status {
        case .completed: return .green.opacity(0.2)
        case .current: return .green.opacity(0.2)
        case .notStarted: return .gray.opacity(0.2)
        }
    }

    private var iconBackgroundColor: Color {
        switch status {
        case .completed: return .green
        case .current: return .blue
        case .notStarted: return Color(white: 0.2)
        }
    }

    private var iconForegroundColor: Color {
        switch status {
        case .completed, .current: return .white
        case .notStarted: return .gray
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
