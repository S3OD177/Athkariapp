import Foundation
import SwiftUI
import SwiftData

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
    var isLoading: Bool = false
    var errorMessage: String?

    // Location state
    var locationPermissionGranted: Bool = false
    var locationCity: String?

    // MARK: - Dependencies
    private let settingsRepository: SettingsRepository
    private let locationService: LocationService
    private let hapticsService: HapticsService

    // MARK: - Initialization
    init(
        settingsRepository: SettingsRepository,
        locationService: LocationService,
        hapticsService: HapticsService
    ) {
        self.settingsRepository = settingsRepository
        self.locationService = locationService
        self.hapticsService = hapticsService
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
                locationCity = s.lastLocationCity
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
        // TODO: Schedule/cancel notifications
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

    func requestLocationPermission() {
        locationService.requestPermission()
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
