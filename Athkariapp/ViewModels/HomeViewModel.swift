import Foundation
import SwiftUI
import SwiftData

/// Daily summary item for home screen
struct DailySummaryItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let slots: [SlotKey]
    var status: SessionStatus
    var completedCount: Int
    var totalCount: Int

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

@MainActor
@Observable
final class HomeViewModel {
    // MARK: - Published State
    var dailySummary: [DailySummaryItem] = []
    var prayerTimes: PrayerTimes?
    var currentPrayer: Prayer?
    var nextPrayerTime: Date?
    var todayHijriDate: String = ""
    var todayGregorianDate: String = ""
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let sessionRepository: SessionRepository
    private let dhikrRepository: DhikrRepository
    private let prayerTimeService: PrayerTimeService
    private let settingsRepository: SettingsRepository

    // MARK: - Initialization
    init(
        sessionRepository: SessionRepository,
        dhikrRepository: DhikrRepository,
        prayerTimeService: PrayerTimeService,
        settingsRepository: SettingsRepository
    ) {
        self.sessionRepository = sessionRepository
        self.dhikrRepository = dhikrRepository
        self.prayerTimeService = prayerTimeService
        self.settingsRepository = settingsRepository
    }

    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load prayer times
            prayerTimes = prayerTimeService.getDefaultPrayerTimes()
            if let times = prayerTimes {
                currentPrayer = times.currentPrayer()
                if let next = times.nextPrayer() {
                    nextPrayerTime = next.time
                }
            }

            // Set dates
            let today = Date()
            todayHijriDate = today.formatHijri()
            todayGregorianDate = today.formatDateArabic()

            // Load daily summary
            try await loadDailySummary()
        } catch {
            errorMessage = NSLocalizedString("error_loading_data", comment: "")
            print("Error loading home data: \(error)")
        }

        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    /// Handle "صليت الآن" button tap
    func handlePrayedNow() -> SlotKey? {
        guard let times = prayerTimes else { return nil }
        return times.afterPrayerSlot()
    }

    func getSessionForSlot(_ slotKey: SlotKey) throws -> SessionState {
        try sessionRepository.fetchOrCreateSession(date: Date(), slotKey: slotKey)
    }

    // MARK: - Private Methods
    private func loadDailySummary() async throws {
        let sessions = try sessionRepository.fetchTodaySessions()
        let sessionsBySlot = Dictionary(grouping: sessions) { $0.slotKey }

        // Create summary items
        var summaryItems: [DailySummaryItem] = []

        // Morning
        let morningStatus = getStatusForSlots([.morning], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "morning",
            title: NSLocalizedString("morning_session", comment: ""),
            icon: "sunrise.fill",
            slots: [.morning],
            status: morningStatus.status,
            completedCount: morningStatus.completed,
            totalCount: morningStatus.total
        ))

        // After prayers (aggregated)
        let afterPrayerSlots: [SlotKey] = [.afterFajr, .afterDhuhr, .afterAsr, .afterMaghrib, .afterIsha]
        let afterPrayerStatus = getStatusForSlots(afterPrayerSlots, sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "prayers",
            title: NSLocalizedString("after_prayers_session", comment: ""),
            icon: "hands.and.sparkles.fill",
            slots: afterPrayerSlots,
            status: afterPrayerStatus.status,
            completedCount: afterPrayerStatus.completed,
            totalCount: afterPrayerStatus.total
        ))

        // Evening
        let eveningStatus = getStatusForSlots([.evening], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "evening",
            title: NSLocalizedString("evening_session", comment: ""),
            icon: "sunset.fill",
            slots: [.evening],
            status: eveningStatus.status,
            completedCount: eveningStatus.completed,
            totalCount: eveningStatus.total
        ))

        // Sleep
        let sleepStatus = getStatusForSlots([.sleep], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "sleep",
            title: NSLocalizedString("sleep_session", comment: ""),
            icon: "moon.zzz.fill",
            slots: [.sleep],
            status: sleepStatus.status,
            completedCount: sleepStatus.completed,
            totalCount: sleepStatus.total
        ))

        dailySummary = summaryItems
    }

    private func getStatusForSlots(
        _ slots: [SlotKey],
        sessionsBySlot: [String: [SessionState]]
    ) -> (status: SessionStatus, completed: Int, total: Int) {
        var completedCount = 0
        var partialCount = 0
        let totalCount = slots.count

        for slot in slots {
            if let sessions = sessionsBySlot[slot.rawValue] {
                for session in sessions {
                    if session.sessionStatus == .completed {
                        completedCount += 1
                    } else if session.sessionStatus == .partial {
                        partialCount += 1
                    }
                }
            }
        }

        let status: SessionStatus
        if completedCount == totalCount {
            status = .completed
        } else if completedCount > 0 || partialCount > 0 {
            status = .partial
        } else {
            status = .notStarted
        }

        return (status, completedCount, totalCount)
    }
}
