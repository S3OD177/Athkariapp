import Foundation
import SwiftUI
import SwiftData

@MainActor
protocol NotificationAuthorizing {
    func requestAuthorization() async throws -> Bool
}

@MainActor
struct SystemNotificationAuthorizer: NotificationAuthorizing {
    func requestAuthorization() async throws -> Bool {
        try await NotificationService.shared.requestAuthorization()
    }
}

@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - Published State
    var currentStep: Int = 0
    var userName: String = ""
    var notificationsEnabled: Bool = false
    var locationEnabled: Bool = false
    var isCompleted: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    // Time Configuration State
    var wakingUpStart: Int = 3
    var wakingUpEnd: Int = 6
    var morningStart: Int = 6
    var morningEnd: Int = 11
    var eveningStart: Int = 15
    var eveningEnd: Int = 20
    var sleepStart: Int = 20
    var sleepEnd: Int = 3
    var afterPrayerOffset: Int = 15

    let totalSteps = 4

    var canProceed: Bool {
        switch currentStep {
        case 1:
            return !trimmedUserName.isEmpty
        default:
            return true
        }
    }

    var isLastStep: Bool {
        currentStep == totalSteps - 1
    }

    // MARK: - Dependencies
    private let onboardingRepository: any OnboardingRepositoryProtocol
    private let settingsRepository: any SettingsRepositoryProtocol
    private let locationService: any LocationServiceProtocol
    private let notificationAuthorizer: any NotificationAuthorizing

    private var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Initialization
    init(
        onboardingRepository: any OnboardingRepositoryProtocol,
        settingsRepository: any SettingsRepositoryProtocol,
        locationService: any LocationServiceProtocol,
        notificationAuthorizer: any NotificationAuthorizing = SystemNotificationAuthorizer()
    ) {
        self.onboardingRepository = onboardingRepository
        self.settingsRepository = settingsRepository
        self.locationService = locationService
        self.notificationAuthorizer = notificationAuthorizer
    }

    // MARK: - Public Methods
    func checkOnboardingStatus() async {
        do {
            if let settings = try? settingsRepository.getSettings() {
                wakingUpStart = settings.wakingUpStart
                wakingUpEnd = settings.wakingUpEnd
                morningStart = settings.morningStart
                morningEnd = settings.morningEnd
                eveningStart = settings.eveningStart
                eveningEnd = settings.eveningEnd
                sleepStart = settings.sleepStart
                sleepEnd = settings.sleepEnd
                afterPrayerOffset = settings.afterPrayerOffset ?? 15
            }

            let state = try onboardingRepository.getState()
            isCompleted = state.completed
            currentStep = max(0, min(state.currentStep, totalSteps - 1))
            if let name = state.userName {
                userName = name
            }
            notificationsEnabled = state.notificationsChoice
            locationEnabled = state.locationChosen
        } catch {
            print("Error checking onboarding status: \(error)")
            isCompleted = false
        }
    }

    func nextStep() {
        guard canProceed else { return }

        guard currentStep < totalSteps - 1 else {
            completeOnboarding()
            return
        }

        currentStep += 1
        saveProgress()
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        saveProgress()
    }

    func setUserName(_ name: String) {
        userName = name
        saveProgress()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        if enabled {
            Task { @MainActor in
                let granted = (try? await notificationAuthorizer.requestAuthorization()) ?? false
                notificationsEnabled = granted
                saveProgress()
            }
        } else {
            notificationsEnabled = false
            saveProgress()
        }
    }

    func setLocationEnabled(_ enabled: Bool) {
        if enabled {
            requestLocationPermission()
        } else {
            locationEnabled = false
            saveProgress()
        }
    }

    func requestLocationPermission() {
        locationService.requestPermission()
        locationEnabled = true
        saveProgress()
    }

    func completeOnboarding() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            try? await Task.sleep(for: .milliseconds(50))
            await finalizeOnboarding()
        }
    }

    func skipOnboarding() {
        notificationsEnabled = false
        locationEnabled = false
        completeOnboarding()
    }

    // MARK: - Private Methods
    private func finalizeOnboarding() async {
        do {
            let state = try onboardingRepository.getState()
            state.completed = true
            state.userName = trimmedUserName
            state.notificationsChoice = notificationsEnabled
            state.locationChosen = locationEnabled
            state.currentStep = totalSteps
            try onboardingRepository.updateState(state)

            let settings = try settingsRepository.getSettings()
            settings.userName = trimmedUserName
            settings.notificationsEnabled = notificationsEnabled
            settings.wakingUpStart = wakingUpStart
            settings.wakingUpEnd = wakingUpEnd
            settings.morningStart = morningStart
            settings.morningEnd = morningEnd
            settings.eveningStart = eveningStart
            settings.eveningEnd = eveningEnd
            settings.sleepStart = sleepStart
            settings.sleepEnd = sleepEnd
            settings.afterPrayerOffset = afterPrayerOffset
            try settingsRepository.updateSettings(settings)

            isCompleted = true
        } catch {
            errorMessage = "حدث خطأ في حفظ الإعدادات"
            print("Error completing onboarding: \(error)")
        }

        isLoading = false
    }

    private func saveProgress() {
        do {
            let state = try onboardingRepository.getState()
            state.currentStep = currentStep
            state.userName = trimmedUserName
            state.notificationsChoice = notificationsEnabled
            state.locationChosen = locationEnabled
            try onboardingRepository.updateState(state)
        } catch {
            print("Error saving onboarding progress: \(error)")
        }
    }
}
