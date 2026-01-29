import Foundation

// MARK: - API Configuration
enum APIConfig {
    /// Prayer times API key
    /// Note: For production, consider moving to Keychain or server-side proxy
    static let prayerTimesAPIKey: String = {
        // Check for environment variable first (for CI/testing)
        if let envKey = ProcessInfo.processInfo.environment["PRAYER_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        // Fallback to bundled key
        return "aZUHsql6tGOVHu1YrjvxyU49ASjdrnoC7rr5p0NawQgjxJNP"
    }()

    static let prayerTimesBaseURL = "https://islamicapi.com/api/v1/prayer-time/"
}

// MARK: - Notifications
extension Notification.Name {
    static let didClearData = Notification.Name("didClearData")
}
