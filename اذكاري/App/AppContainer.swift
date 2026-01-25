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

    // MARK: - Initialization
    private init() {
        // Configure SwiftData model container
        let schema = Schema([
            DhikrItem.self,
            RoutineSlot.self,
            SessionState.self,
            FavoriteItem.self,
            AppSettings.self,
            OnboardingState.self,
            UserRoutineLink.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        // Initialize services
        prayerTimeService = PrayerTimeService()
        hapticsService = HapticsService()
        locationService = LocationService()
    }

    // MARK: - Repository Factory Methods
    func makeDhikrRepository() -> DhikrRepository {
        DhikrRepository(modelContext: modelContainer.mainContext)
    }

    func makeSessionRepository() -> SessionRepository {
        SessionRepository(modelContext: modelContainer.mainContext)
    }

    func makeFavoritesRepository() -> FavoritesRepository {
        FavoritesRepository(modelContext: modelContainer.mainContext)
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
    static let defaultValue: AppContainer = AppContainer.shared
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
