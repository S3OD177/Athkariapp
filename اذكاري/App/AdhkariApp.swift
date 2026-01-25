import SwiftUI
import SwiftData

@main
struct AdhkariApp: App {
    @State private var appContainer = AppContainer.shared
    @State private var isOnboardingCompleted = false
    @State private var isLoading = true
    @State private var currentTheme: AppTheme = .system

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    SplashView()
                } else if isOnboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView()
                        .onDisappear {
                            checkOnboardingStatus()
                        }
                }
            }
            .environment(\.appContainer, appContainer)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(colorScheme)
            .modelContainer(appContainer.modelContainer)
            .task {
                await initializeApp()
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    @MainActor
    private func initializeApp() async {
        // Import seed data
        let seedService = appContainer.makeSeedImportService()
        do {
            try await seedService.importSeedDataIfNeeded()
        } catch {
            print("Error importing seed data: \(error)")
        }

        // Check onboarding status
        checkOnboardingStatus()

        // Load theme preference
        loadThemePreference()

        // Done loading
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation {
            isLoading = false
        }
    }

    @MainActor
    private func checkOnboardingStatus() {
        let repository = appContainer.makeOnboardingRepository()
        if let state = try? repository.getState() {
            isOnboardingCompleted = state.completed
        }
    }

    @MainActor
    private func loadThemePreference() {
        let repository = appContainer.makeSettingsRepository()
        if let settings = try? repository.getSettings() {
            currentTheme = settings.appTheme
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("اذكاري")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                Text("رفيقك اليومي للذكر")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1
            }
        }
    }
}

#Preview("Splash") {
    SplashView()
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Main") {
    MainTabView()
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
}
