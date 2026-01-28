import Foundation
import SwiftData

/// Unified JSON structure for parsing all adhkar data from a single file
struct UnifiedAdhkarJSON: Codable, Sendable {
    let athkar: [DhikrJSON]
}

struct RepeatJSON: Codable, Sendable {
    let min: Int
    let max: Int
    let note: String?
}

struct DhikrJSON: Codable, Sendable {
    let id: String
    let category: String
    let hisnCategory: String?
    let source: String
    let title: String
    let text: String
    let reference: String?
    let `repeat`: RepeatJSON
    let orderIndex: Int
    let benefit: String?
    let grading: String?
    let isOptional: Bool?
}

@MainActor
protocol SeedImportServiceProtocol {
    func importSeedDataIfNeeded() async throws
    func forceReimport() async throws
}

@MainActor
final class SeedImportService: SeedImportServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    private let seedDataVersion = "4.6" // Daily adhkar titles update

    func importSeedDataIfNeeded() async throws {
        // Skip if already imported for this version (INSTANT on subsequent launches)
        let lastVersion = UserDefaults.standard.string(forKey: "seedDataVersion")
        if lastVersion == seedDataVersion {
            return
        }

        // Delete old seed data when migrating to new version
        // Logic: Delete everything where source != "user_added"
        // Workaround for Swift 6 #Predicate "Sendable" error: Manual fetch & delete
        if lastVersion != nil {
            let descriptor = FetchDescriptor<DhikrItem>()
            let allItems = try modelContext.fetch(descriptor)
            
            for item in allItems {
                if item.source != "user_added" {
                    modelContext.delete(item)
                }
            }
            try modelContext.save()
        }

        // Parse JSON in BACKGROUND (off main thread)
        let adhkarData = try await parseJSONInBackground()

        // Then do DB operations on main thread (required by SwiftData)
        try await importParsedData(adhkarData: adhkarData)

        // Mark as imported
        UserDefaults.standard.set(seedDataVersion, forKey: "seedDataVersion")
    }

    func forceReimport() async throws {
        // Delete all existing seed data (preserve user-added)
        let descriptor = FetchDescriptor<DhikrItem>()
        let allItems = try modelContext.fetch(descriptor)
        
        for item in allItems {
            if item.source != "user_added" {
                modelContext.delete(item)
            }
        }
        try modelContext.save()

        // Parse and import
        let adhkarData = try await parseJSONInBackground()
        try await importParsedData(adhkarData: adhkarData)
        UserDefaults.standard.set(seedDataVersion, forKey: "seedDataVersion")
    }

    // MARK: - Background JSON Parsing (OFF MAIN THREAD)

    nonisolated private func parseJSONInBackground() async throws -> UnifiedAdhkarJSON? {
        // This runs on a background thread - no main thread blocking!
        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()

            guard let url = Bundle.main.url(forResource: "adhkar", withExtension: "json") else {
                return nil
            }

            let data = try Data(contentsOf: url)
            return try decoder.decode(UnifiedAdhkarJSON.self, from: data)
        }.value
    }

    // MARK: - Database Operations (MAIN THREAD - required by SwiftData)

    private func importParsedData(adhkarData: UnifiedAdhkarJSON?) async throws {
        guard let athkar = adhkarData?.athkar else { return }

        // Fetch existing items once
        let descriptor = FetchDescriptor<DhikrItem>()
        let existingItems = try modelContext.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingItems.compactMap { item -> (String, DhikrItem)? in
            guard let sourceId = item.sourceId else { return nil }
            return (sourceId, item)
        })

        for dhikr in athkar {
            let dhikrSource = DhikrSource(rawValue: dhikr.source) ?? .daily
            let hisnCategory = dhikr.hisnCategory.flatMap { HisnCategory(rawValue: $0) }

            if let existing = existingMap[dhikr.id] {
                existing.title = dhikr.title
                existing.category = dhikr.category
                existing.hisnCategory = hisnCategory?.rawValue
                existing.text = dhikr.text
                existing.reference = dhikr.reference
                existing.repeatMin = dhikr.repeat.min
                existing.repeatMax = dhikr.repeat.max
                existing.repeatNote = dhikr.repeat.note
                existing.orderIndex = dhikr.orderIndex
                existing.benefit = dhikr.benefit
                existing.grading = dhikr.grading
                existing.isOptional = dhikr.isOptional ?? false
                existing.source = dhikrSource.rawValue
            } else {
                let item = DhikrItem(
                    sourceId: dhikr.id,
                    source: dhikrSource,
                    title: dhikr.title,
                    category: dhikr.category,
                    hisnCategory: hisnCategory,
                    text: dhikr.text,
                    reference: dhikr.reference,
                    repeatMin: dhikr.repeat.min,
                    repeatMax: dhikr.repeat.max,
                    repeatNote: dhikr.repeat.note,
                    orderIndex: dhikr.orderIndex,
                    benefit: dhikr.benefit,
                    grading: dhikr.grading,
                    isOptional: dhikr.isOptional ?? false
                )
                modelContext.insert(item)
            }
        }

        // Single save at the end (batched)
        try modelContext.save()
    }
}
