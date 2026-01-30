import SwiftUI
import SwiftData

/// Dependency injection container for the app
@MainActor
@Observable
final class AppContainer {
    // MARK: - Shared Instance
    static let shared = AppContainer()

    // MARK: - Model Container
    let modelContainer: ModelContainer

    // MARK: - Services
    let prayerTimeService: PrayerTimeService
    let hapticsService: HapticsService
    let locationService: LocationService

    // MARK: - Services

    // MARK: - Initialization
    private init() {
        // Configure SwiftData model container
        let schema = Schema([
            DhikrItem.self,
            RoutineSlot.self,
            SessionState.self,
            AppSettings.self,
            OnboardingState.self,
            UserRoutineLink.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // Recovery for development: if schema changes fail, wipe and restart
            #if DEBUG
            print("ModelContainer failed: \(error). Resetting store...")
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
        }

        // Initialize services
        prayerTimeService = PrayerTimeService()
        hapticsService = HapticsService()
        locationService = LocationService()

        // Load initial theme settings
        if let _ = try? makeSettingsRepository().getSettings() {
            // Theme settings logic if needed
        }
    }

    // MARK: - Repository Factory Methods
    func makeDhikrRepository() -> DhikrRepository {
        DhikrRepository(modelContext: modelContainer.mainContext)
    }

    func makeSessionRepository() -> SessionRepository {
        SessionRepository(modelContext: modelContainer.mainContext)
    }



    func makeSettingsRepository() -> SettingsRepository {
        SettingsRepository(modelContext: modelContainer.mainContext)
    }

    func makeOnboardingRepository() -> OnboardingRepository {
        OnboardingRepository(modelContext: modelContainer.mainContext)
    }

    func makeUserRoutineLinkRepository() -> UserRoutineLinkRepository {
        UserRoutineLinkRepository(modelContext: modelContainer.mainContext)
    }

    func makeSeedImportService() -> SeedImportService {
        SeedImportService(modelContext: modelContainer.mainContext)
    }
}

// MARK: - Environment Key
struct AppContainerKey: EnvironmentKey {
    static var defaultValue: AppContainer {
        MainActor.assumeIsolated {
            AppContainer.shared
        }
    }
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
