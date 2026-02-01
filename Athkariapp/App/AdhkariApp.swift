import SwiftUI
import SwiftData

@main
struct AdhkariApp: App {
    @State private var appContainer = AppContainer.shared
    @State private var isOnboardingCompleted = false
    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    SplashView()
                } else if isOnboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView(onFinished: {
                        withAnimation {
                            isOnboardingCompleted = true
                        }
                    })
                }
            }
            .environment(\.appContainer, appContainer)
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
            .modelContainer(appContainer.modelContainer)
            .task {
                await initializeApp()
            }
            .onReceive(NotificationCenter.default.publisher(for: .didClearData)) { _ in
                // Delay slightly to allow the heavy deletion logic to clear the main thread
                // and for the alert to dismiss cleanly before switching views.
                Task {
                    // Reset seed version so it re-imports
                    UserDefaults.standard.removeObject(forKey: "seedDataVersion")
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await MainActor.run {
                        withAnimation {
                            isOnboardingCompleted = false
                        }
                    }
                }
            }
        }
    }



    @MainActor
    private func initializeApp() async {
        // Import seed data FIRST (must complete before home screen shows)
        let seedService = appContainer.makeSeedImportService()
        do {
            try await seedService.importSeedDataIfNeeded()
        } catch {
            print("Error importing seed data: \(error)")
        }
        
        // Then check onboarding status
        checkOnboardingStatus()

        // Now hide splash - data is ready
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
