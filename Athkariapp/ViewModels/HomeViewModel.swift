import Foundation
import SwiftUI
import SwiftData
import UserNotifications

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
    
    // Post-Prayer Status
    var currentAdhan: Prayer?
    var postPrayerCountdown: String?

    // MARK: - Dependencies
    private let sessionRepository: SessionRepository
    private let dhikrRepository: DhikrRepository
    private let prayerTimeService: PrayerTimeService
    private let settingsRepository: SettingsRepository
    private let locationService: LocationService

    // MARK: - Initialization
    init(
        sessionRepository: SessionRepository,
        dhikrRepository: DhikrRepository,
        prayerTimeService: PrayerTimeService,
        settingsRepository: SettingsRepository,
        locationService: LocationService
    ) {
        self.sessionRepository = sessionRepository
        self.dhikrRepository = dhikrRepository
        self.prayerTimeService = prayerTimeService
        self.settingsRepository = settingsRepository
        self.locationService = locationService
        
        setupLocationBindings()
    }

    private func setupLocationBindings() {
        locationService.onLocationUpdate = { [weak self] _ in
            Task { @MainActor in
                await self?.loadData()
            }
        }
        
        // Initial permission request
        locationService.requestPermission()
    }

    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load prayer times using location
            if let location = locationService.currentLocation {
                prayerTimes = try? await prayerTimeService.fetchPrayerTimes(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    method: 4
                )
            } else {
                // Try to start updating if not available
                locationService.startUpdatingLocation()
                prayerTimes = prayerTimeService.getDefaultPrayerTimes()
            }
            
            if let times = prayerTimes {
                currentPrayer = times.currentPrayer()
                if let next = times.nextPrayer() {
                    nextPrayerTime = next.time
                }
                
                // Schedule notifications
                let settings = try? settingsRepository.getSettings()
                if settings?.notificationsEnabled == true {
                    let offset = settings?.afterPrayerOffset ?? 15
                    await NotificationService.shared.schedulePostPrayerNotifications(prayerTimes: times, offsetMinutes: offset)
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


    func getSessionForSlot(_ slotKey: SlotKey) throws -> SessionState {
        let session = try sessionRepository.fetchOrCreateSession(date: Date(), slotKey: slotKey)
        
        // If it's a post-prayer slot, tag with metadata if not already completed
        if slotKey.isAfterPrayer && session.sessionStatus != .completed {
            if let prayer = prayerTimes?.currentAdhan() {
                session.prayerName = prayer.rawValue
                session.shownMode = "timeBased"
                session.offsetUsedMinutes = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
                
                // Store the adhan time for on-time verification
                switch prayer {
                case .fajr: session.adhanTime = prayerTimes?.fajr
                case .dhuhr: session.adhanTime = prayerTimes?.dhuhr
                case .asr: session.adhanTime = prayerTimes?.asr
                case .maghrib: session.adhanTime = prayerTimes?.maghrib
                case .isha: session.adhanTime = prayerTimes?.isha
                case .sunrise: break
                }
            }
        }
        
        return session
    }

    func markSessionCompleted(_ session: SessionState) {
        session.sessionStatus = .completed
        session.completedAt = Date()
        try? sessionRepository.update(session)
        
        Task {
            try? await loadDailySummary()
        }
    }

    var dailyProgress: Double {
        let total = dailySummary.reduce(0) { $0 + $1.totalCount }
        guard total > 0 else { return 0 }
        let completed = dailySummary.reduce(0) { $0 + $1.completedCount }
        return Double(completed) / Double(total)
    }

    var formattedProgress: String {
        let percentage = Int(dailyProgress * 100)
        return "\(percentage)%"
    }

    var activeSummaryItem: DailySummaryItem? {
        // 1. Check for in-progress first
        if let inProgress = dailySummary.first(where: { $0.status == .partial }) {
            return inProgress
        }
        
        // 2. Check for "After Prayer" priority if active
        if let afterPrayerItem = dailySummary.first(where: { $0.id == "prayers" && $0.status != .completed }) {
            return afterPrayerItem
        }
        
        // 3. Check for upcoming priority based on time
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Refined timing for Waking Up / Morning
        if hour >= 3 && hour < 6 {
            return dailySummary.first(where: { $0.id == "waking_up" })
        } else if hour >= 6 && hour < 11 {
            return dailySummary.first(where: { $0.id == "morning" })
        } else if hour >= 15 && hour < 20 {
            return dailySummary.first(where: { $0.id == "evening" })
        } else if hour >= 20 || hour < 3 {
            return dailySummary.first(where: { $0.id == "sleep" })
        }
        
        // 3. Fallback to first non-completed
        return dailySummary.first(where: { $0.status != .completed }) ?? dailySummary.first
    }

    var currentSlot: SlotKey? {
        activeSummaryItem?.slots.first
    }

    // MARK: - Private Methods
    private func loadDailySummary() async throws {
        let sessions = try sessionRepository.fetchTodaySessions()
        let sessionsBySlot = Dictionary(grouping: sessions) { $0.slotKey }

        // Create summary items
        var summaryItems: [DailySummaryItem] = []

        // Waking Up
        let wakingUpStatus = getStatusForSlots([.wakingUp], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "waking_up",
            title: "أذكار الاستيقاظ",
            icon: "sunrise.fill",
            slots: [.wakingUp],
            status: wakingUpStatus.status,
            completedCount: wakingUpStatus.completed,
            totalCount: wakingUpStatus.total
        ))

        // Morning
        let morningStatus = getStatusForSlots([.morning], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "morning",
            title: "أذكار الصباح",
            icon: "sun.max.fill",
            slots: [.morning],
            status: morningStatus.status,
            completedCount: morningStatus.completed,
            totalCount: morningStatus.total
        ))

        // After prayers (dynamic current slot)
        let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 0
        if let afterSlot = prayerTimes?.afterPrayerSlot(offsetMinutes: offset) {
            let afterPrayerStatus = getStatusForSlots([afterSlot], sessionsBySlot: sessionsBySlot)
            summaryItems.append(DailySummaryItem(
                id: "prayers",
                title: "أذكار بعد \(afterSlot.shortName)",
                icon: "hands.and.sparkles.fill",
                slots: [afterSlot],
                status: afterPrayerStatus.status,
                completedCount: afterPrayerStatus.completed,
                totalCount: afterPrayerStatus.total
            ))
        }

        // Evening
        let eveningStatus = getStatusForSlots([.evening], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "evening",
            title: "أذكار المساء",
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
            title: "أذكار النوم",
            icon: "moon.zzz.fill",
            slots: [.sleep],
            status: sleepStatus.status,
            completedCount: sleepStatus.completed,
            totalCount: sleepStatus.total
        ))

        dailySummary = summaryItems
        updateAdhanStatus()
    }

    private func updateAdhanStatus() {
        guard let times = prayerTimes else { return }
        let now = Date()
        currentAdhan = times.currentAdhan(at: now)
        
        let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
        
        if let adhan = currentAdhan {
            // Check if post-prayer is ready
            let isReady = times.isPostPrayerReady(for: adhan, at: now, offsetMinutes: offset)
            
            // Handle countdown
            if !isReady {
                if let countdown = times.countdownToPostPrayer(at: now, offsetMinutes: offset) {
                    let minutes = Int(countdown.remaining / 60)
                    let seconds = Int(countdown.remaining.truncatingRemainder(dividingBy: 60))
                    postPrayerCountdown = String(format: "%02d:%02d", minutes, seconds)
                }
            } else {
                postPrayerCountdown = nil
            }
        } else {
            postPrayerCountdown = nil
        }
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
