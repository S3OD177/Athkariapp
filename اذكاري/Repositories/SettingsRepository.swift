import Foundation
import SwiftData

@MainActor
protocol SettingsRepositoryProtocol {
    func getSettings() throws -> AppSettings
    func updateSettings(_ settings: AppSettings) throws
    func resetToDefaults() throws -> AppSettings
}

@MainActor
final class SettingsRepository: SettingsRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getSettings() throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        let settings = try modelContext.fetch(descriptor)

        if let existing = settings.first {
            return existing
        }

        // Create default settings
        let defaultSettings = AppSettings()
        modelContext.insert(defaultSettings)
        try modelContext.save()
        return defaultSettings
    }

    func updateSettings(_ settings: AppSettings) throws {
        try modelContext.save()
    }

    func resetToDefaults() throws -> AppSettings {
        // Delete all existing settings
        let descriptor = FetchDescriptor<AppSettings>()
        let existingSettings = try modelContext.fetch(descriptor)
        for setting in existingSettings {
            modelContext.delete(setting)
        }

        // Create new default settings
        let defaultSettings = AppSettings()
        modelContext.insert(defaultSettings)
        try modelContext.save()
        return defaultSettings
    }
}
