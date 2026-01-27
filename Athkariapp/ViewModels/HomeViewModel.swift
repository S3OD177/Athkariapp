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
                // Stop location updates after getting initial location (energy optimization)
                self?.locationService.stopUpdatingLocation()
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
                // Request a single location update (not continuous) if not available
                locationService.startUpdatingLocation()
                // Will be stopped automatically in setupLocationBindings callback
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
        
        // 2. Check for "After Prayer" priority if active AND timely
        if let afterPrayerItem = dailySummary.first(where: { $0.id == "prayers" && $0.status != .completed }) {
            // Only prioritize in Hero Card if it's actually the active time
            // (Since we made the item persistent, we must check isPostPrayerReady or similar)
            if let times = prayerTimes, let prayer = times.currentAdhan(at: Date()) {
                let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
                let isReady = times.isPostPrayerReady(for: prayer, at: Date(), offsetMinutes: offset)
                // Also check if we are in the countdown phase (it's "next" but not ready yet)
                // If ready or counting down, show it.
                // If it's totally outside window (e.g. sunrise), don't show as main item
                if isReady || times.countdownToPostPrayer(at: Date(), offsetMinutes: offset) != nil {
                    return afterPrayerItem
                }
            }
        }
        
        // 3. Check for upcoming priority based on time
        let hour = Calendar.current.component(.hour, from: Date())
        let settings = try? settingsRepository.getSettings()
        
        // Defaults if settings not loaded
        let wakingStart = settings?.wakingUpStart ?? 3
        let wakingEnd = settings?.wakingUpEnd ?? 6
        let morningStart = settings?.morningStart ?? 6
        let morningEnd = settings?.morningEnd ?? 11
        let eveningStart = settings?.eveningStart ?? 15
        let eveningEnd = settings?.eveningEnd ?? 20
        let sleepStart = settings?.sleepStart ?? 20
        let sleepEnd = settings?.sleepEnd ?? 3
        
        // Helper to check time range
        func isInRange(hour: Int, start: Int, end: Int) -> Bool {
            if start < end {
                return hour >= start && hour < end
            } else {
                // Crosses midnight (e.g. 20 to 3)
                return hour >= start || hour < end
            }
        }
        
        // Refined timing
        if isInRange(hour: hour, start: wakingStart, end: wakingEnd) {
            return dailySummary.first(where: { $0.id == "waking_up" })
        } else if isInRange(hour: hour, start: morningStart, end: morningEnd) {
            return dailySummary.first(where: { $0.id == "morning" })
        } else if isInRange(hour: hour, start: eveningStart, end: eveningEnd) {
            return dailySummary.first(where: { $0.id == "evening" })
        } else if isInRange(hour: hour, start: sleepStart, end: sleepEnd) {
            return dailySummary.first(where: { $0.id == "sleep" })
        }
        
        // 3. Fallback to first non-completed
        return dailySummary.first(where: { $0.status != .completed }) ?? dailySummary.first
    }

    var currentSlot: SlotKey? {
        activeSummaryItem?.slots.first
    }

    // New persistent accessor for After Prayer button
    var afterPrayerSummaryItem: DailySummaryItem? {
        dailySummary.first(where: { $0.id == "prayers" })
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

        // After prayers (Always show)
        let persistentSlot: SlotKey
        if let current = prayerTimes?.currentPrayer() {
            if let slot = current.afterPrayerSlot {
                persistentSlot = slot
            } else if current == .sunrise {
                persistentSlot = .afterDhuhr
            } else {
                persistentSlot = .afterFajr // Fallback
            }
        } else {
            persistentSlot = .afterFajr // Default fallback
        }

        let afterPrayerStatus = getStatusForSlots([persistentSlot], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "prayers",
            title: "أذكار بعد \(persistentSlot.shortName)",
            icon: "hands.and.sparkles.fill",
            slots: [persistentSlot],
            status: afterPrayerStatus.status,
            completedCount: afterPrayerStatus.completed,
            totalCount: afterPrayerStatus.total
        ))

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
    
    var timeToNextDhikr: String? {
        let now = Date()
        let calendar = Calendar.current
        var nextEventDate: Date?
        var eventName: String = ""
        
        // 1. Check Next Prayer
        if let nextPrayer = nextPrayerTime {
            nextEventDate = nextPrayer
            eventName = "الصلاة القادمة"
        }
        
        // 2. Check Static Times (Morning, Evening, etc.)
        if let settings = try? settingsRepository.getSettings() {
            let candidates: [(String, Int)] = [
                ("أذكار الصباح", settings.morningStart),
                ("أذكار المساء", settings.eveningStart),
                ("أذكار النوم", settings.sleepStart),
                ("أذكار الاستيقاظ", settings.wakingUpStart)
            ]
            
            for (name, startHour) in candidates {
                // Construct date for this start hour today
                if let date = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now) {
                    var targetDate = date
                    if targetDate <= now {
                        // If passed today, verify if it's closer tomorrow than current nextEvent
                        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetDate) {
                            targetDate = tomorrow
                        } else {
                            continue
                        }
                    }
                    
                    // If this target is sooner than current nextEvent (or if nextEvent is nil)
                    if let currentNext = nextEventDate {
                        if targetDate < currentNext {
                            nextEventDate = targetDate
                            eventName = name
                        }
                    } else {
                        nextEventDate = targetDate
                        eventName = name
                    }
                }
            }
        }
        
        guard let target = nextEventDate else { return nil }
        
        let diff = target.timeIntervalSince(now)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        
        if hours > 0 {
            return "متبقي على \(eventName): \(hours)س \(minutes)د"
        } else {
            return "متبقي على \(eventName): \(minutes)د"
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
