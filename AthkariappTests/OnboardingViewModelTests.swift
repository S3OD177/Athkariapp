import XCTest
import CoreLocation
@testable import Athkariapp

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    func testNextStepBlocksWhenNameIsEmpty() {
        let (viewModel, _, _, _) = makeSUT(notificationGranted: true)

        viewModel.currentStep = 1
        viewModel.userName = "   "

        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, 1)

        viewModel.userName = "سعود"
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, 2)
    }

    func testCompleteOnboardingPersistsStateAndSettings() {
        let (viewModel, onboardingRepository, settingsRepository, _) = makeSUT(notificationGranted: true)

        viewModel.userName = "سعود"
        viewModel.wakingUpStart = 5
        viewModel.wakingUpEnd = 7
        viewModel.morningStart = 7
        viewModel.morningEnd = 10
        viewModel.eveningStart = 17
        viewModel.eveningEnd = 19
        viewModel.sleepStart = 22
        viewModel.sleepEnd = 2
        viewModel.afterPrayerOffset = 30
        viewModel.notificationsEnabled = true
        viewModel.locationEnabled = true

        viewModel.completeOnboarding()
        waitUntil(timeout: 1.0) { viewModel.isCompleted }

        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertTrue(onboardingRepository.state.completed)
        XCTAssertEqual(onboardingRepository.state.currentStep, viewModel.totalSteps)
        XCTAssertEqual(onboardingRepository.state.userName, "سعود")
        XCTAssertTrue(onboardingRepository.state.notificationsChoice)
        XCTAssertTrue(onboardingRepository.state.locationChosen)

        XCTAssertEqual(settingsRepository.settings.userName, "سعود")
        XCTAssertTrue(settingsRepository.settings.notificationsEnabled)
        XCTAssertEqual(settingsRepository.settings.wakingUpStart, 5)
        XCTAssertEqual(settingsRepository.settings.wakingUpEnd, 7)
        XCTAssertEqual(settingsRepository.settings.morningStart, 7)
        XCTAssertEqual(settingsRepository.settings.morningEnd, 10)
        XCTAssertEqual(settingsRepository.settings.eveningStart, 17)
        XCTAssertEqual(settingsRepository.settings.eveningEnd, 19)
        XCTAssertEqual(settingsRepository.settings.sleepStart, 22)
        XCTAssertEqual(settingsRepository.settings.sleepEnd, 2)
        XCTAssertEqual(settingsRepository.settings.afterPrayerOffset, 30)
    }

    func testSkipOnboardingCompletesWithoutPermissions() {
        let (viewModel, onboardingRepository, settingsRepository, _) = makeSUT(notificationGranted: true)

        viewModel.userName = "أحمد"
        viewModel.notificationsEnabled = true
        viewModel.locationEnabled = true

        viewModel.skipOnboarding()
        waitUntil(timeout: 1.0) { viewModel.isCompleted }

        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertTrue(onboardingRepository.state.completed)
        XCTAssertFalse(onboardingRepository.state.notificationsChoice)
        XCTAssertFalse(onboardingRepository.state.locationChosen)
        XCTAssertFalse(settingsRepository.settings.notificationsEnabled)
    }

    func testCheckOnboardingStatusRestoresSavedProgressAndTimeSettings() async {
        let state = OnboardingState()
        state.completed = false
        state.currentStep = 3
        state.userName = "ليان"
        state.notificationsChoice = true
        state.locationChosen = false

        let settings = AppSettings()
        settings.wakingUpStart = 4
        settings.wakingUpEnd = 8
        settings.morningStart = 8
        settings.morningEnd = 11
        settings.eveningStart = 16
        settings.eveningEnd = 21
        settings.sleepStart = 21
        settings.sleepEnd = 3
        settings.afterPrayerOffset = 25

        let (viewModel, _, _, _) = makeSUT(
            notificationGranted: true,
            state: state,
            settings: settings
        )

        await viewModel.checkOnboardingStatus()

        XCTAssertEqual(viewModel.currentStep, 3)
        XCTAssertEqual(viewModel.userName, "ليان")
        XCTAssertTrue(viewModel.notificationsEnabled)
        XCTAssertFalse(viewModel.locationEnabled)

        XCTAssertEqual(viewModel.wakingUpStart, 4)
        XCTAssertEqual(viewModel.wakingUpEnd, 8)
        XCTAssertEqual(viewModel.morningStart, 8)
        XCTAssertEqual(viewModel.morningEnd, 11)
        XCTAssertEqual(viewModel.eveningStart, 16)
        XCTAssertEqual(viewModel.eveningEnd, 21)
        XCTAssertEqual(viewModel.sleepStart, 21)
        XCTAssertEqual(viewModel.sleepEnd, 3)
        XCTAssertEqual(viewModel.afterPrayerOffset, 25)
    }

    func testNotificationPermissionResultUpdatesToggle() {
        let (deniedViewModel, _, _, _) = makeSUT(notificationGranted: false)

        deniedViewModel.setNotificationsEnabled(true)
        waitUntil(timeout: 0.5) { !deniedViewModel.notificationsEnabled }
        XCTAssertFalse(deniedViewModel.notificationsEnabled)

        let (grantedViewModel, _, _, _) = makeSUT(notificationGranted: true)

        grantedViewModel.setNotificationsEnabled(true)
        waitUntil(timeout: 0.5) { grantedViewModel.notificationsEnabled }
        XCTAssertTrue(grantedViewModel.notificationsEnabled)
    }

    private func makeSUT(
        notificationGranted: Bool,
        state: OnboardingState = OnboardingState(),
        settings: AppSettings = AppSettings()
    ) -> (OnboardingViewModel, MockOnboardingRepository, MockSettingsRepository, MockLocationService) {
        let onboardingRepository = MockOnboardingRepository(state: state)
        let settingsRepository = MockSettingsRepository(settings: settings)
        let locationService = MockLocationService()
        let notificationAuthorizer = MockNotificationAuthorizer(granted: notificationGranted)

        let viewModel = OnboardingViewModel(
            onboardingRepository: onboardingRepository,
            settingsRepository: settingsRepository,
            locationService: locationService,
            notificationAuthorizer: notificationAuthorizer
        )

        return (viewModel, onboardingRepository, settingsRepository, locationService)
    }

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

@MainActor
private final class MockOnboardingRepository: OnboardingRepositoryProtocol {
    var state: OnboardingState

    init(state: OnboardingState) {
        self.state = state
    }

    func getState() throws -> OnboardingState {
        state
    }

    func updateState(_ state: OnboardingState) throws {
        self.state = state
    }

    func markCompleted() throws {
        state.completed = true
    }

    func reset() throws -> OnboardingState {
        state = OnboardingState()
        return state
    }
}

@MainActor
private final class MockSettingsRepository: SettingsRepositoryProtocol {
    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func getSettings() throws -> AppSettings {
        settings
    }

    func updateSettings(_ settings: AppSettings) throws {
        self.settings = settings
    }

    func resetToDefaults() throws -> AppSettings {
        settings = AppSettings()
        return settings
    }
}

@MainActor
private final class MockLocationService: LocationServiceProtocol {
    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var permissionRequestsCount = 0

    func requestPermission() {
        permissionRequestsCount += 1
    }

    func startUpdatingLocation() { }
    func stopUpdatingLocation() { }
    func startUpdatingHeading() { }
    func stopUpdatingHeading() { }
}

@MainActor
private struct MockNotificationAuthorizer: NotificationAuthorizing {
    let granted: Bool

    func requestAuthorization() async throws -> Bool {
        granted
    }
}
