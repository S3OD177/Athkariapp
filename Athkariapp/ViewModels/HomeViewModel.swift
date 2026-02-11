import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation

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
    
    // Timer Task
    // No explicit property needed as we rely on weak self for cancellation naturally

    // MARK: - Dependencies
    private let sessionRepository: SessionRepository
    private let dhikrRepository: DhikrRepository
    private let prayerTimeService: PrayerTimeService
    private let settingsRepository: SettingsRepository
    private let locationService: LocationService
    private let liveActivityCoordinator: LiveActivityCoordinator
    private let widgetSnapshotCoordinator: WidgetSnapshotCoordinator

    // MARK: - Initialization
    init(
        sessionRepository: SessionRepository,
        dhikrRepository: DhikrRepository,
        prayerTimeService: PrayerTimeService,
        settingsRepository: SettingsRepository,
        locationService: LocationService,
        liveActivityCoordinator: LiveActivityCoordinator,
        widgetSnapshotCoordinator: WidgetSnapshotCoordinator
    ) {
        self.sessionRepository = sessionRepository
        self.dhikrRepository = dhikrRepository
        self.prayerTimeService = prayerTimeService
        self.settingsRepository = settingsRepository
        self.locationService = locationService
        self.liveActivityCoordinator = liveActivityCoordinator
        self.widgetSnapshotCoordinator = widgetSnapshotCoordinator
        
        setupLocationObservers()
        setupLocationBindings()
        startTimeUpdater()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
                    self.syncPrayerWindowLiveActivity()
                }
            }
        }
    }

    private func setupLocationObservers() {
        NotificationCenter.default.addObserver(forName: .didUpdateLocation, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let _ = notification.userInfo?["location"] as? CLLocation else { return }
            
            Task { @MainActor in
                // Stop location updates after getting initial location (energy optimization)
                self.locationService.stopUpdatingLocation()
                await self.loadData()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .didChangeLocationAuthorization, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let rawStatus = notification.userInfo?["status"] as? Int32,
                  let status = CLAuthorizationStatus(rawValue: rawStatus) else { return }
            
            Task { @MainActor in
                self.showLocationWarning = (status == .denied || status == .restricted)
            }
        }
    }

    private func setupLocationBindings() {
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
            syncPrayerWindowLiveActivity()
        } catch {
            errorMessage = NSLocalizedString("error_loading_data", comment: "")
            print("Error loading home data: \(error)")
            liveActivityCoordinator.syncPrayerWindowState(nil)
            widgetSnapshotCoordinator.syncHeroCard(nil)
            widgetSnapshotCoordinator.syncPrayerWindow(nil)
            widgetSnapshotCoordinator.syncNextPrayer(name: nil, date: nil)
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
    
    /// Builds an after-prayer summary item on-the-fly for the hero card only.
    private var afterPrayerHeroItem: DailySummaryItem? {
        guard let times = prayerTimes,
              let prayer = times.currentAdhan(at: currentTime),
              let slot = prayer.afterPrayerSlot else { return nil }

        let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
        guard times.isPostPrayerReady(for: prayer, at: currentTime, durationMinutes: offset) else { return nil }

        // Build a lightweight item (counts are not shown in the hero card)
        return DailySummaryItem(
            id: "prayers",
            title: "أذكار بعد \(slot.shortName)",
            icon: "hands.and.sparkles.fill",
            slots: [slot],
            status: .notStarted,
            completedCount: 0,
            totalCount: 0
        )
    }

    private var currentContext: EventTimeContext? {
        // 1. Check for "After Prayer" priority (hero card only)
        if let afterPrayerItem = afterPrayerHeroItem {
            if let times = prayerTimes, let prayer = times.currentAdhan(at: currentTime) {
                let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
                if let adhanTime = times.timeForPrayer(prayer) {
                    let expiration = adhanTime.addingTimeInterval(Double(offset) * 60)
                    let name = self.nextPrayerName ?? "الصلاة القادمة"
                    return EventTimeContext(item: afterPrayerItem, endTime: expiration, nextEventName: name)
                }
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

    // MARK: - Private Methods
    private func loadDailySummary() async throws {
        let sessions = try sessionRepository.fetchTodaySessions()
        let sessionsBySlot = Dictionary(grouping: sessions) { $0.slotKey }

        // Create summary items
        var summaryItems: [DailySummaryItem] = []

        // Waking Up
        let wakingUpStatus = try await getStatusForSlots([.wakingUp], sessionsBySlot: sessionsBySlot)
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
        let morningStatus = try await getStatusForSlots([.morning], sessionsBySlot: sessionsBySlot)
        summaryItems.append(DailySummaryItem(
            id: "morning",
            title: "أذكار الصباح",
            icon: "sun.max.fill",
            slots: [.morning],
            status: morningStatus.status,
            completedCount: morningStatus.completed,
            totalCount: morningStatus.total
        ))


        // Evening
        let eveningStatus = try await getStatusForSlots([.evening], sessionsBySlot: sessionsBySlot)
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
        let sleepStatus = try await getStatusForSlots([.sleep], sessionsBySlot: sessionsBySlot)
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
            // Check if post-prayer is ready (used for UI display logic)
            _ = times.isPostPrayerReady(for: adhan, at: now, durationMinutes: offset)
        }
    }

    private func syncPrayerWindowLiveActivity() {
        let prayerWindowSnapshot = makePrayerWindowSnapshot()
        let heroSnapshot = makeHeroCardSnapshot()
        liveActivityCoordinator.syncPrayerWindowState(prayerWindowSnapshot)
        widgetSnapshotCoordinator.syncHeroCard(heroSnapshot)
        widgetSnapshotCoordinator.syncPrayerWindow(prayerWindowSnapshot)
        widgetSnapshotCoordinator.syncNextPrayer(
            name: nextPrayerName,
            date: nextPrayerTime
        )
    }

    private func makeHeroCardSnapshot() -> WidgetSnapshotCoordinator.HeroCardSnapshot? {
        let headerLabel = hasActiveEvent ? "الذكر الحالي" : "الذكر القادم"
        let title: String
        if hasActiveEvent {
            title = activeSummaryItem?.title ?? "أذكار المسلم"
        } else if let upcoming = nextUpcomingEvent {
            title = upcoming.name
        } else {
            title = "لا يوجد ذكر حالي"
        }

        let heroPrimaryLine: String
        let heroSecondaryLine: String?
        if let remaining = currentEventRemainingTime {
            heroPrimaryLine = "ينتهي الذكر الحالي خلال \(remaining)"
            if let next = nextEventName {
                heroSecondaryLine = "التالي: \(next)"
            } else {
                heroSecondaryLine = nil
            }
        } else if let nextTime = nextEventRemainingTime {
            heroPrimaryLine = "يبدأ بعد \(nextTime)"
            heroSecondaryLine = nil
        } else {
            heroPrimaryLine = "افتح التطبيق لمتابعة أذكارك"
            heroSecondaryLine = nil
        }

        let currentCount = hasActiveEvent ? (activeSummaryItem?.completedCount ?? 0) : 0
        let targetCount = hasActiveEvent ? (activeSummaryItem?.totalCount ?? 0) : 0
        let progress = hasActiveEvent ? (activeSummaryItem?.progress ?? 0) : 0
        let completionText = hasActiveEvent ? heroCompletionText(for: activeSummaryItem) : nil
        let slot = currentSlot
        let routeURL = slot.map { AthkariWidgetRoutes.session(slotKey: $0.rawValue) } ?? AthkariWidgetRoutes.home
        let nextTitle = nextEventName
        let iconSystemName = hasActiveEvent ? (activeSummaryItem?.icon ?? "hand.raised.fill") : "clock.fill"
        let windowEndDate = currentContext?.endTime ?? nextUpcomingEvent?.date

        return WidgetSnapshotCoordinator.HeroCardSnapshot(
            slotKey: slot?.rawValue,
            headerLabel: headerLabel,
            title: title,
            subtitle: heroPrimaryLine,
            heroPrimaryLine: heroPrimaryLine,
            heroSecondaryLine: heroSecondaryLine,
            completionText: completionText,
            currentCount: currentCount,
            targetCount: targetCount,
            progress: progress,
            windowEndDate: windowEndDate,
            nextTitle: nextTitle,
            iconSystemName: iconSystemName,
            routeURL: routeURL
        )
    }

    private func heroCompletionText(for item: DailySummaryItem?) -> String {
        guard let item else {
            return "0/0 مكتمل"
        }
        if item.status == .completed {
            return "مكتمل"
        }
        return "\(item.completedCount)/\(item.totalCount) مكتمل"
    }

    private func makePrayerWindowSnapshot() -> LiveActivityCoordinator.PrayerWindowSnapshot? {
        guard
            let times = prayerTimes,
            let prayer = times.currentAdhan(at: currentTime),
            let slot = prayer.afterPrayerSlot
        else {
            return nil
        }

        let offset = (try? settingsRepository.getSettings())?.afterPrayerOffset ?? 15
        guard
            times.isPostPrayerReady(for: prayer, at: currentTime, durationMinutes: offset),
            let adhanTime = times.timeForPrayer(prayer)
        else {
            return nil
        }

        let windowEndDate = adhanTime.addingTimeInterval(Double(offset) * 60)

        return LiveActivityCoordinator.PrayerWindowSnapshot(
            slotKey: slot.rawValue,
            title: "أذكار بعد \(slot.shortName)",
            subtitle: "نافذة ما بعد الأذان",
            prayerName: prayer.arabicName,
            windowStartDate: adhanTime,
            windowEndDate: windowEndDate
        )
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
        
        // 1. Check Next Prayer
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
    ) async throws -> (status: SessionStatus, completed: Int, total: Int) {
        var completedDhikrs = 0
        var totalDhikrs = 0
        var hasPartial = false

        for slot in slots {
            let category = slot.dhikrCategory
            let items: [DhikrItem]
            
            // Special handling for After Prayer to match SessionViewModel logic
            if slot.isAfterPrayer {
                items = try dhikrRepository.fetchByCategory(.afterPrayer)
            } else if slot == .wakingUp {
                items = try dhikrRepository.fetchByHisnCategory(.waking)
            } else {
                items = try dhikrRepository.fetchByCategory(category)
            }
            
            totalDhikrs += items.count
            
            if let session = sessionsBySlot[slot.rawValue]?.first {
                let sessionCompletedCount = session.completedDhikrIds.count
                completedDhikrs += sessionCompletedCount
                if session.sessionStatus == .partial || (sessionCompletedCount > 0 && sessionCompletedCount < items.count) {
                    hasPartial = true
                }
            }
        }

        let status: SessionStatus
        if totalDhikrs > 0 && completedDhikrs >= totalDhikrs {
            status = .completed
        } else if hasPartial || (completedDhikrs > 0) {
            status = .partial
        } else {
            status = .notStarted
        }

        return (status, completedDhikrs, totalDhikrs)
    }
}
