import SwiftUI
import SwiftData

/// Dependency injection container for the app
@MainActor
@Observable
final class AppContainer {
    // MARK: - Shared Instance
    static let shared = AppContainer()
    static let cloudKitPreferenceKey = "iCloudSyncEnabled"
    private static let cloudKitContainerId = "iCloud.com.Athkariapp"

    // MARK: - Model Container
    let modelContainer: ModelContainer

    // MARK: - Services
    let prayerTimeService: PrayerTimeService
    let hapticsService: HapticsService
    let locationService: LocationService
    let liveActivityCoordinator: LiveActivityCoordinator
    let widgetSnapshotCoordinator: WidgetSnapshotCoordinator

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

        let cloudKitEnabled = AppContainer.isCloudKitEnabled()
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = cloudKitEnabled
            ? .private(Self.cloudKitContainerId)
            : .none
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )

        do {
            modelContainer = try AppContainer.makeModelContainer(
                schema: schema,
                configuration: cloudConfiguration
            )
        } catch {
            if cloudKitEnabled {
                print("CloudKit ModelContainer failed: \(error). Falling back to local store.")
                let localConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                do {
                    modelContainer = try AppContainer.makeModelContainer(
                        schema: schema,
                        configuration: localConfiguration
                    )
                } catch {
                    fatalError("Could not create local ModelContainer after CloudKit failure: \(error)")
                }
            } else {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }

        // Initialize services
        prayerTimeService = PrayerTimeService()
        hapticsService = HapticsService()
        locationService = LocationService()
        liveActivityCoordinator = LiveActivityCoordinator()
        widgetSnapshotCoordinator = WidgetSnapshotCoordinator()

        // Load initial theme settings
        if let settings = try? makeSettingsRepository().getSettings() {
            let dismissMinutes = settings.liveActivityDismissMinutes
                ?? LiveActivityCoordinator.defaultDismissMinutes
            liveActivityCoordinator.updateDismissPreset(minutes: dismissMinutes)
            // Theme settings logic if needed
        }
    }

    private static func isCloudKitEnabled() -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: cloudKitPreferenceKey) == nil {
            defaults.set(true, forKey: cloudKitPreferenceKey)
        }
        return defaults.bool(forKey: cloudKitPreferenceKey)
    }

    private static func makeModelContainer(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            #if DEBUG
            let url = configuration.url
            print("ModelContainer failed: \(error). Resetting store at \(url.path)...")
            let walUrl = url.deletingPathExtension().appendingPathExtension("store-wal")
            let shmUrl = url.deletingPathExtension().appendingPathExtension("store-shm")

            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: walUrl)
            try? FileManager.default.removeItem(at: shmUrl)

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                throw error
            }
            #else
            throw error
            #endif
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
