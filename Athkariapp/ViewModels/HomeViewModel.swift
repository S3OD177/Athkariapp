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
    var userName: String = ""
    var prayerTimes: PrayerTimes?
    var currentPrayer: Prayer?
    var nextPrayerTime: Date?
    var todayHijriDate: String = ""
    var todayGregorianDate: String = ""
    var nextPrayerName: String?
    var isLoading = false
    var errorMessage: String?
    var showLocationWarning: Bool = false
    var currentTime: Date = Date() // Triggers UI updates based on time
    
    // Post-Prayer Status
    var currentAdhan: Prayer?
    var postPrayerCountdown: String?
    
    // Timer Task
    // No explicit property needed as we rely on weak self for cancellation naturally

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
        startTimeUpdater()
    }
    
    private func startTimeUpdater() {
        // Update every minute to refresh time-based UI
        Task { [weak self] in
            while true {
                // Sleep for 60 seconds
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                
                guard let self = self else { return }
                
                await MainActor.run {
                    self.currentTime = Date()
                    
                    // Check if prayer changed to refresh "After Prayer" card
                    let oldPrayer = self.currentPrayer
                    if let times = self.prayerTimes {
                        let newPrayer = times.currentPrayer()
                        if newPrayer != oldPrayer {
                            self.currentPrayer = newPrayer
                            // Reload summary to update the "After Prayer" card title/logic
                            Task { try? await self.loadDailySummary() }
                        }
                        
                        // Also update next prayer info if changed
                        if let next = times.nextPrayer(includingSunrise: false) {
                            self.nextPrayerTime = next.time
                            self.nextPrayerName = "صلاة \(next.prayer.arabicName)"
                        }
                    }
                    
                    self.updateAdhanStatus()
                }
            }
        }
    }

    private func setupLocationBindings() {
        locationService.onLocationUpdate = { [weak self] _ in
            Task { @MainActor in
                // Stop location updates after getting initial location (energy optimization)
                self?.locationService.stopUpdatingLocation()
                await self?.loadData()
            }
        }
        
        locationService.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.showLocationWarning = (status == .denied || status == .restricted)
            }
        }
        
        // Initial permission check
        let status = locationService.authorizationStatus
        showLocationWarning = (status == .denied || status == .restricted)
        
        // Request if needed
        if status == .notDetermined {
             locationService.requestPermission()
        }
    }

    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        // Set dates immediately
        let today = Date()
        todayHijriDate = today.formatHijri()
        todayGregorianDate = today.formatDateArabic()

        do {
            // Load prayer times using location
            // Load prayer times
            if let location = locationService.currentLocation {
                do {
                    prayerTimes = try await prayerTimeService.fetchPrayerTimes(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        method: 4
                    )
                } catch {
                    print("API fetch failed, falling back to local calculation: \(error)")
                    // Fallback to manual calculation with current location
                    prayerTimes = prayerTimeService.getPrayerTimes(
                        date: Date(),
                        location: location,
                        method: .ummAlQura
                    )
                }
            } else {
                // Request a single location update (not continuous) if not available
                locationService.startUpdatingLocation()
                // Will be stopped automatically in setupLocationBindings callback
                prayerTimes = prayerTimeService.getDefaultPrayerTimes()
            }
            
            if let times = prayerTimes {
                currentPrayer = times.currentPrayer()
                if let next = times.nextPrayer(includingSunrise: false) {
                    nextPrayerTime = next.time
                    nextPrayerName = "صلاة \(next.prayer.arabicName)"
                }
                
                // Schedule notifications
                let settings = try? settingsRepository.getSettings()
                if let s = settings {
                    userName = s.userName
                    if s.notificationsEnabled {
                        let offset = s.afterPrayerOffset ?? 15
                        await NotificationService.shared.schedulePostPrayerNotifications(prayerTimes: times, offsetMinutes: offset)
                    }
                }
            }

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

    // MARK: - Event Timing Logic
    
    private struct EventTimeContext {
        let item: DailySummaryItem
        let endTime: Date?
        let nextEventName: String?
    }
    
    private var currentContext: EventTimeContext? {
        // Re-use logic to find active item AND its end time
        // 1. Check for "After Prayer" priority
        if let afterPrayerItem = dailySummary.first(where: { $0.id == "prayers" && $0.status != .completed }) {
            if let times = prayerTimes, let prayer = times.currentAdhan(at: currentTime) {
                let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
                let isReady = times.isPostPrayerReady(for: prayer, at: currentTime, offsetMinutes: offset)
                
                if isReady {
                    // Ends when next prayer starts (approximated)
                    let nextP = times.nextPrayer(includingSunrise: false)?.time
                    // Use stored next prayer name or dynamic fallback
                    let name = self.nextPrayerName ?? "الصلاة القادمة"
                    return EventTimeContext(item: afterPrayerItem, endTime: nextP, nextEventName: name)
                }
                // If not ready (counting down), we do NOT return a context.
                // This allows it to fall through to "No Active Dhikr" state,
                // and the "nextUpcomingEvent" logic will catch it as the next event.
            }
        }

        // 2. Time-based selection
        let now = currentTime
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let settings = try? settingsRepository.getSettings()
        
        // Defaults
        let wakingStart = settings?.wakingUpStart ?? 3
        let wakingEnd = settings?.wakingUpEnd ?? 6
        let morningStart = settings?.morningStart ?? 6
        let morningEnd = settings?.morningEnd ?? 11
        let eveningStart = settings?.eveningStart ?? 15
        let eveningEnd = settings?.eveningEnd ?? 20
        let sleepStart = settings?.sleepStart ?? 20
        let sleepEnd = settings?.sleepEnd ?? 3
        
        func getEndDate(endHour: Int) -> Date? {
            if let date = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: now) {
                return date <= now ? calendar.date(byAdding: .day, value: 1, to: date) : date
            }
            return nil
        }
        
        func isInRange(start: Int, end: Int) -> Bool {
            if start < end { return hour >= start && hour < end }
            else { return hour >= start || hour < end }
        }
        
        var selectedId: String?
        var endTime: Date?
        var nextName: String?

        if isInRange(start: wakingStart, end: wakingEnd) {
            selectedId = "waking_up"
            endTime = getEndDate(endHour: wakingEnd)
            nextName = "أذكار الصباح"
        } else if isInRange(start: morningStart, end: morningEnd) {
            selectedId = "morning"
            endTime = getEndDate(endHour: morningEnd)
            nextName = "أذكار المساء"
        } else if isInRange(start: eveningStart, end: eveningEnd) {
            selectedId = "evening"
            endTime = getEndDate(endHour: eveningEnd)
            nextName = "أذكار النوم"
        } else if isInRange(start: sleepStart, end: sleepEnd) {
            selectedId = "sleep"
            endTime = getEndDate(endHour: sleepEnd)
            nextName = "أذكار الاستيقاظ"
        }
        
        if let id = selectedId, let item = dailySummary.first(where: { $0.id == id }) {
            return EventTimeContext(item: item, endTime: endTime, nextEventName: nextName)
        }
        
        // Fallback for gap handling (Logic simplified to just return logic similar to before but without context if confusing)
        // If we are in a gap, we just fall back to standard logic WITHOUT endTime context
        return nil
    }

    var activeSummaryItem: DailySummaryItem? {
        if let context = currentContext {
            return context.item
        }

        // Fallback for gaps (same as old logic essentially)
        return dailySummary.first(where: { $0.status != .completed }) ?? dailySummary.first
    }
    
    var hasActiveEvent: Bool {
        currentContext != nil
    }
    
    var currentEventRemainingTime: String? {
        guard let endTime = currentContext?.endTime else { return nil }
        let diff = endTime.timeIntervalSince(currentTime)
        if diff <= 0 { return nil }
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)س \(minutes)د"
        } else {
            return "\(minutes)د"
        }
    }
    
    var nextEventName: String? {
        currentContext?.nextEventName 
            ?? (nextPrayerTime != nil ? (nextPrayerName ?? "الصلاة القادمة") : nil)
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
        let now = currentTime
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
    
    // MARK: - Gap Handling Logic
    
    struct UpcomingEvent {
        let name: String
        let date: Date
    }
    
    var nextUpcomingEvent: UpcomingEvent? {
        let now = currentTime
        let calendar = Calendar.current
        var nextEventDate: Date?
        var eventName: String = ""
        
        // 1. Check Pending After Prayer (Highest Priority Near Term)
        if let times = prayerTimes, let prayer = times.currentAdhan(at: now) {
            let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
            if let countdown = times.countdownToPostPrayer(at: now, offsetMinutes: offset) {
                // It is pending! This is definitely the next event.
                let targetDate = now.addingTimeInterval(countdown.remaining)
                return UpcomingEvent(name: "أذكار بعد \(prayer.arabicName)", date: targetDate)
            }
        }

        // 2. Check Next Prayer
        if let next = nextPrayerTime {
            nextEventDate = next
            eventName = nextPrayerName ?? "الصلاة القادمة"
        }
        
        // 2. Check Static Times (Morning, Evening, etc.)
        // Use defaults if settings fetch fails, matching currentContext logic
        let settings = try? settingsRepository.getSettings()
        
        let candidates: [(String, Int)] = [
            ("أذكار الصباح", settings?.morningStart ?? 6),
            ("أذكار المساء", settings?.eveningStart ?? 15),
            ("أذكار النوم", settings?.sleepStart ?? 20),
            ("أذكار الاستيقاظ", settings?.wakingUpStart ?? 3)
        ]
        
        for (name, startHour) in candidates {
            // Construct date for this start hour today
            if let date = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now) {
                var targetDate = date
                // If this hour already passed today, check tomorrow
                if targetDate <= now {
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
        
        guard let target = nextEventDate else { return nil }
        return UpcomingEvent(name: eventName, date: target)
    }
    
    // Kept for backward compatibility if needed, but updated to use new struct
    var timeToNextDhikr: String? {
        guard let event = nextUpcomingEvent else { return nil }
        
        let diff = event.date.timeIntervalSince(currentTime)
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        
        if hours > 0 {
            return "متبقي على \(event.name): \(hours)س \(minutes)د"
        } else {
            return "متبقي على \(event.name): \(minutes)د"
        }
    }
    
    var nextEventRemainingTime: String? {
        guard let event = nextUpcomingEvent else { return nil }
        let diff = event.date.timeIntervalSince(currentTime)
        if diff <= 0 { return nil }
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)س \(minutes)د"
        } else {
            return "\(minutes)د"
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
