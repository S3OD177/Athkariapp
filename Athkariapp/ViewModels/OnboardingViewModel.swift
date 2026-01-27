import Foundation
import SwiftUI
import SwiftData

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

    // Time Configuration State (Defaults)
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
        case 0: return true // Welcome
        case 1: return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty // Name Input
        case 2: return true // Time Config
        case 3: return true // Permissions
        default: return true
        }
    }

    var isLastStep: Bool {
        currentStep == totalSteps - 1
    }

    // MARK: - Dependencies
    private let onboardingRepository: OnboardingRepository
    private let settingsRepository: SettingsRepository
    private let locationService: LocationService

    // MARK: - Initialization
    init(
        onboardingRepository: OnboardingRepository,
        settingsRepository: SettingsRepository,
        locationService: LocationService
    ) {
        self.onboardingRepository = onboardingRepository
        self.settingsRepository = settingsRepository
        self.locationService = locationService
    }

    // MARK: - Public Methods
    func checkOnboardingStatus() async {
        do {
            let state = try onboardingRepository.getState()
            isCompleted = state.completed
            currentStep = state.currentStep
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
        notificationsEnabled = enabled
        saveProgress()
    }

    func requestLocationPermission() {
        locationService.requestPermission()
        locationEnabled = true
        saveProgress()
    }

    func completeOnboarding() {
        isLoading = true
        
        Task {
            // Give UI a chance to show loading state
            try? await Task.sleep(for: .milliseconds(50))
            
            do {
                // Update onboarding state
                let state = try onboardingRepository.getState()
                state.completed = true
                state.userName = userName
                state.notificationsChoice = notificationsEnabled
                state.locationChosen = locationEnabled
                state.currentStep = totalSteps
                try onboardingRepository.updateState(state)

                // Update settings with chosen values
                // Update settings with chosen values
                let settings = try settingsRepository.getSettings()
                settings.userName = userName
                settings.notificationsEnabled = notificationsEnabled
                
                // Save time configuration
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
    }

    func skipOnboarding() {
        do {
            try onboardingRepository.markCompleted()
            isCompleted = true
        } catch {
            print("Error skipping onboarding: \(error)")
            isCompleted = true // Allow proceeding anyway
        }
    }

    // MARK: - Private Methods
    private func saveProgress() {
        do {
            let state = try onboardingRepository.getState()
            state.currentStep = currentStep
            state.userName = userName
            state.notificationsChoice = notificationsEnabled
            state.locationChosen = locationEnabled
            try onboardingRepository.updateState(state)
        } catch {
            print("Error saving onboarding progress: \(error)")
        }
    }
}
