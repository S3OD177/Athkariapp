import Foundation
import SwiftUI
import SwiftData
import UserNotifications

@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Published State
    var settings: AppSettings?
    var theme: AppTheme = .system
    var hapticsEnabled: Bool = true
    var notificationsEnabled: Bool = false
    var routineIntensity: RoutineIntensity = .moderate
    var calculationMethod: CalculationMethod = .ummAlQura
    var iCloudEnabled: Bool = false
    var fontSize: Double = 1.0
    var afterPrayerOffset: Int = 15
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
    private let modelContext: ModelContext

    // MARK: - Initialization
    init(
        settingsRepository: SettingsRepository,
        locationService: LocationService,
        hapticsService: HapticsService,
        prayerTimeService: PrayerTimeService,
        modelContext: ModelContext
    ) {
        self.settingsRepository = settingsRepository
        self.locationService = locationService
        self.hapticsService = hapticsService
        self.prayerTimeService = prayerTimeService
        self.modelContext = modelContext
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
                routineIntensity = s.intensity
                calculationMethod = s.calculation
                iCloudEnabled = s.iCloudEnabled
                fontSize = s.fontSize
                locationCity = s.lastLocationCity
                afterPrayerOffset = s.afterPrayerOffset ?? 15
            }

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
        notificationsEnabled = enabled
        settings?.notificationsEnabled = enabled
        saveSettings()
        
        if enabled {
            Task {
                _ = try? await NotificationService.shared.requestAuthorization()
                await rescheduleNotifications()
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    func updateRoutineIntensity(_ intensity: RoutineIntensity) {
        routineIntensity = intensity
        settings?.intensity = intensity
        saveSettings()
    }

    func updateCalculationMethod(_ method: CalculationMethod) {
        calculationMethod = method
        settings?.calculation = method
        saveSettings()
    }

    func updateiCloudEnabled(_ enabled: Bool) {
        iCloudEnabled = enabled
        settings?.iCloudEnabled = enabled
        saveSettings()
        // TODO: Implement iCloud sync
    }

    func updateFontSize(_ size: Double) {
        fontSize = size
        settings?.fontSize = size
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
    }

    func clearAllData() {
        do {
            // Delete all sessions
            let sessions = try modelContext.fetch(FetchDescriptor<SessionState>())
            for session in sessions {
                modelContext.delete(session)
            }
            
            // Delete all favorites
            let favorites = try modelContext.fetch(FetchDescriptor<FavoriteItem>())
            for favorite in favorites {
                modelContext.delete(favorite)
            }
            
            try modelContext.save()
            
            // Trigger haptic feedback
            hapticsService.playImpact(.heavy)
            
            // Notify other views
            NotificationCenter.default.post(name: .didClearData, object: nil)
        } catch {
            print("Error clearing data: \(error)")
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
