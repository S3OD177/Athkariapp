import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - Published State
    var currentStep: Int = 0
    var routineIntensity: RoutineIntensity = .moderate
    var notificationsEnabled: Bool = false
    var locationEnabled: Bool = false
    var isCompleted: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    let totalSteps = 3

    var canProceed: Bool {
        switch currentStep {
        case 0: return true // Welcome
        case 1: return true // Routine intensity
        case 2: return true // Notifications (optional)
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
            if let intensity = state.intensity {
                routineIntensity = intensity
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

    func selectRoutineIntensity(_ intensity: RoutineIntensity) {
        routineIntensity = intensity
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

        do {
            // Update onboarding state
            let state = try onboardingRepository.getState()
            state.completed = true
            state.intensity = routineIntensity
            state.notificationsChoice = notificationsEnabled
            state.locationChosen = locationEnabled
            state.currentStep = totalSteps
            try onboardingRepository.updateState(state)

            // Update settings with chosen values
            let settings = try settingsRepository.getSettings()
            settings.intensity = routineIntensity
            settings.notificationsEnabled = notificationsEnabled
            try settingsRepository.updateSettings(settings)

            isCompleted = true
        } catch {
            errorMessage = "حدث خطأ في حفظ الإعدادات"
            print("Error completing onboarding: \(error)")
        }

        isLoading = false
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
            state.intensity = routineIntensity
            state.notificationsChoice = notificationsEnabled
            state.locationChosen = locationEnabled
            try onboardingRepository.updateState(state)
        } catch {
            print("Error saving onboarding progress: \(error)")
        }
    }
}
