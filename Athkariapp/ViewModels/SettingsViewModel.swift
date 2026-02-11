import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation

@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Published State
    var settings: AppSettings?
    var theme: AppTheme = .system
    var hapticsEnabled: Bool = true
    var notificationsEnabled: Bool = false
    var calculationMethod: CalculationMethod = .ummAlQura
    var hapticIntensity: HapticIntensity = .medium
    var autoAdvance: Bool = false
    var afterPrayerOffset: Int = 15
    var iCloudSyncEnabled: Bool = false
    var liveActivityDismissMinutes: Int = 30
    
    // Time Configuration State
    var wakingUpStart: Int = 3
    var wakingUpEnd: Int = 6
    var morningStart: Int = 6
    var morningEnd: Int = 11
    var eveningStart: Int = 15
    var eveningEnd: Int = 20
    var sleepStart: Int = 20
    var sleepEnd: Int = 3
    
    var isLoading: Bool = false
    var errorMessage: String?

    // Location state
    var locationPermissionGranted: Bool = false
    var locationCity: String?

    // MARK: - Dependencies
    private let settingsRepository: SettingsRepository
    private let locationService: LocationService
    private let hapticsService: HapticsService
    private let prayerTimeService: PrayerTimeService
    private let liveActivityCoordinator: LiveActivityCoordinator
    private let modelContext: ModelContext
    private let modelContainer: ModelContainer
    private let geocoder = CLGeocoder()

    // MARK: - Initialization
    init(
        settingsRepository: SettingsRepository,
        locationService: LocationService,
        hapticsService: HapticsService,
        prayerTimeService: PrayerTimeService,
        liveActivityCoordinator: LiveActivityCoordinator,
        modelContext: ModelContext,
        modelContainer: ModelContainer
    ) {
        self.settingsRepository = settingsRepository
        self.locationService = locationService
        self.hapticsService = hapticsService
        self.prayerTimeService = prayerTimeService
        self.liveActivityCoordinator = liveActivityCoordinator
        self.modelContext = modelContext
        self.modelContainer = modelContainer
        
        setupLocationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods
    func loadSettings() async {
        isLoading = true
        errorMessage = nil

        do {
            settings = try settingsRepository.getSettings()

            if let s = settings {
                theme = s.appTheme
                hapticsEnabled = s.hapticsEnabled
                notificationsEnabled = s.notificationsEnabled
                calculationMethod = s.calculation
                iCloudSyncEnabled = s.iCloudSyncEnabled
                hapticIntensity = HapticIntensity(rawValue: s.hapticIntensity) ?? .medium
                autoAdvance = s.autoAdvance
                locationCity = s.lastLocationCity
                afterPrayerOffset = s.afterPrayerOffset ?? 15
                liveActivityDismissMinutes = LiveActivityCoordinator.sanitizeDismissPreset(
                    s.liveActivityDismissMinutes
                )
                
                // Load Time Configuration
                wakingUpStart = s.wakingUpStart
                wakingUpEnd = s.wakingUpEnd
                morningStart = s.morningStart
                morningEnd = s.morningEnd
                eveningStart = s.eveningStart
                eveningEnd = s.eveningEnd
                sleepStart = s.sleepStart
                sleepEnd = s.sleepEnd
            }

            liveActivityCoordinator.updateDismissPreset(minutes: liveActivityDismissMinutes)

            // Update location permission state
            updateLocationPermissionState()
        } catch {
            errorMessage = "حدث خطأ في تحميل الإعدادات"
            print("Error loading settings: \(error)")
        }

        isLoading = false
    }

    func updateTheme(_ newTheme: AppTheme) {
        theme = newTheme
        settings?.appTheme = newTheme
        saveSettings()
    }

    func updateHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        settings?.hapticsEnabled = enabled
        hapticsService.setEnabled(enabled)
        saveSettings()
    }

    func updateNotificationsEnabled(_ enabled: Bool) {
        if enabled {
            Task { @MainActor in
                let granted = (try? await NotificationService.shared.requestAuthorization()) ?? false
                notificationsEnabled = granted
                settings?.notificationsEnabled = granted
                saveSettings()
                
                if granted {
                    await rescheduleNotifications()
                }
            }
        } else {
            notificationsEnabled = false
            settings?.notificationsEnabled = false
            saveSettings()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }



    func updateCalculationMethod(_ method: CalculationMethod) {
        calculationMethod = method
        settings?.calculation = method
        saveSettings()
    }

    func updateICloudSyncEnabled(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
        settings?.iCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "iCloudSyncEnabled")
        saveSettings()
    }


    func updateHapticIntensity(_ intensity: HapticIntensity) {
        hapticIntensity = intensity
        settings?.hapticIntensity = intensity.rawValue
        #if os(iOS)
        hapticsService.setIntensity(intensity.feedbackStyle)
        #endif
        saveSettings()
    }

    func updateAutoAdvance(_ enabled: Bool) {
        autoAdvance = enabled
        settings?.autoAdvance = enabled
        saveSettings()
    }





    func updateAfterPrayerOffset(_ offset: Int) {
        afterPrayerOffset = offset
        settings?.afterPrayerOffset = offset
        saveSettings()
        
        if notificationsEnabled {
            Task {
                await rescheduleNotifications()
            }
        }
    }

    func updateLiveActivityDismissMinutes(_ minutes: Int) {
        let sanitizedMinutes = LiveActivityCoordinator.sanitizeDismissPreset(minutes)
        liveActivityDismissMinutes = sanitizedMinutes
        settings?.liveActivityDismissMinutes = sanitizedMinutes
        liveActivityCoordinator.updateDismissPreset(minutes: sanitizedMinutes)
        saveSettings()
    }
    
    // Time Configuration Updates
    func updateWakingUpStart(_ hour: Int) {
        wakingUpStart = hour
        settings?.wakingUpStart = hour
        saveSettings()
    }

    func updateWakingUpEnd(_ hour: Int) {
        wakingUpEnd = hour
        settings?.wakingUpEnd = hour
        saveSettings()
    }
    
    func updateMorningStart(_ hour: Int) {
        morningStart = hour
        settings?.morningStart = hour
        saveSettings()
    }

    func updateMorningEnd(_ hour: Int) {
        morningEnd = hour
        settings?.morningEnd = hour
        saveSettings()
    }
    
    func updateEveningStart(_ hour: Int) {
        eveningStart = hour
        settings?.eveningStart = hour
        saveSettings()
    }

    func updateEveningEnd(_ hour: Int) {
        eveningEnd = hour
        settings?.eveningEnd = hour
        saveSettings()
    }
    
    func updateSleepStart(_ hour: Int) {
        sleepStart = hour
        settings?.sleepStart = hour
        saveSettings()
    }

    func updateSleepEnd(_ hour: Int) {
        sleepEnd = hour
        settings?.sleepEnd = hour
        saveSettings()
    }

    private func rescheduleNotifications() async {
        // Fetch current prayer times from the service
        // (This assumes the service already has coordinates or default calculation method set)
        if let times = prayerTimeService.currentPrayerTimes {
            await NotificationService.shared.schedulePostPrayerNotifications(
                prayerTimes: times, 
                offsetMinutes: afterPrayerOffset
            )
        }
    }

    func requestLocationPermission() {
        locationService.requestPermission()
        // Observer "didChangeLocationAuthorization" will handle the update
    }

    func refreshLocation() {
        locationService.startUpdatingLocation()
    }
    
    private func setupLocationObservers() {
        // Handle Authorization Changes
        NotificationCenter.default.addObserver(
            forName: .didChangeLocationAuthorization,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateLocationPermissionState()
                
                // If authorized, verify/refresh location
                if self.locationPermissionGranted {
                    self.refreshLocation()
                }
            }
        }
        
        // Handle Location Updates
        NotificationCenter.default.addObserver(
            forName: .didUpdateLocation,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let location = notification.userInfo?["location"] as? CLLocation else { return }
            let coordinate = location.coordinate
            
            Task { @MainActor in
                // Stop updating to save battery (one-shot update)
                self.locationService.stopUpdatingLocation()
                await self.updateLocationAndCity(coordinate)
            }
        }
    }

    private func updateLocationAndCity(_ coordinate: CLLocationCoordinate2D) async {
        settings?.lastLocationLatitude = coordinate.latitude
        settings?.lastLocationLongitude = coordinate.longitude
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            if let city = placemarks.first?.locality {
                self.locationCity = city
                self.settings?.lastLocationCity = city
            }
            saveSettings()
            
            // Trigger haptic feedback
            hapticsService.playImpact(.medium)
        } catch {
            print("Error reverse geocoding: \(error)")
        }
    }

    func clearAllData() {
        isLoading = true
        
        Task {
            // 1. Perform heavy session deletion on a background thread
            let container = self.modelContainer
            await Task.detached(priority: .userInitiated) {
                let bgContext = ModelContext(container)
                // Fetch only IDs to minimize memory usage if possible, but SwiftData fetches objects.
                // We fetch batches or all. Since loop delete is the only way in basic SwiftData:
                do {
                    let descriptor = FetchDescriptor<SessionState>()
                    let sessions = try bgContext.fetch(descriptor)
                    for session in sessions {
                        bgContext.delete(session)
                    }
                    try bgContext.save()
                } catch {
                    print("Error clearing sessions in background: \(error)")
                }
            }.value

            // 2. Perform remaining cleanup on Main Actor (lightweight)
            do {
                // Delete Onboarding State
                let onboardingStates = try modelContext.fetch(FetchDescriptor<OnboardingState>())
                for state in onboardingStates {
                    modelContext.delete(state)
                }
                
                // Reset Settings to Defaults
                settings = try settingsRepository.resetToDefaults()
                
                try modelContext.save()
                
                // Trigger haptic feedback
                hapticsService.playImpact(.heavy)
                
                // Notify other views
                NotificationCenter.default.post(name: .didClearData, object: nil)
            } catch {
                print("Error clearing data on main thread: \(error)")
            }
            
            isLoading = false
        }
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func resetToDefaults() async {
        do {
            settings = try settingsRepository.resetToDefaults()
            await loadSettings()
        } catch {
            errorMessage = "حدث خطأ في إعادة الضبط"
            print("Error resetting settings: \(error)")
        }
    }

    // MARK: - Private Methods
    private func saveSettings() {
        guard let settings = settings else { return }

        do {
            try settingsRepository.updateSettings(settings)
        } catch {
            print("Error saving settings: \(error)")
        }
    }

    private func updateLocationPermissionState() {
        let status = locationService.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionGranted = true
            settings?.locationState = .authorized
        case .denied, .restricted:
            locationPermissionGranted = false
            settings?.locationState = .denied
        case .notDetermined:
            locationPermissionGranted = false
            settings?.locationState = .notDetermined
        @unknown default:
            locationPermissionGranted = false
        }
    }
}
// MARK: - Constants
extension Notification.Name {
    static let didClearData = Notification.Name("didClearData")
}
