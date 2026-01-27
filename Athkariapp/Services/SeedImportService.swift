import Foundation
import SwiftData

/// JSON structures for parsing seed data
struct DailyAthkarJSON: Codable, Sendable {
    let athkar: [DhikrJSON]
}

struct HisnJSON: Codable, Sendable {
    let categories: [CategoryJSON]
    let duas: [DhikrJSON]
}

struct CategoryJSON: Codable, Sendable {
    let id: String
    let name: String
    let icon: String
}

struct RepeatJSON: Codable, Sendable {
    let min: Int
    let max: Int
    let note: String?
}

struct DhikrJSON: Codable, Sendable {
    let id: String
    let category: String
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

    private let seedDataVersion = "2.0" // Increment when seed data changes
    
    func importSeedDataIfNeeded() async throws {
        // Skip if already imported for this version (INSTANT on subsequent launches)
        let lastVersion = UserDefaults.standard.string(forKey: "seedDataVersion")
        if lastVersion == seedDataVersion {
            return
        }
        
        // Parse JSON in BACKGROUND (off main thread)
        let (athkarData, hisnData) = try await parseJSONInBackground()
        
        // Then do DB operations on main thread (required by SwiftData)
        try await importParsedData(athkarData: athkarData, hisnData: hisnData)
        
        // Mark as imported
        UserDefaults.standard.set(seedDataVersion, forKey: "seedDataVersion")
    }

    func forceReimport() async throws {
        // Delete all existing data
        try modelContext.delete(model: DhikrItem.self)
        try modelContext.save()

        // Parse and import
        let (athkarData, hisnData) = try await parseJSONInBackground()
        try await importParsedData(athkarData: athkarData, hisnData: hisnData)
        UserDefaults.standard.set(seedDataVersion, forKey: "seedDataVersion")
    }

    // MARK: - Background JSON Parsing (OFF MAIN THREAD)
    
    nonisolated private func parseJSONInBackground() async throws -> (DailyAthkarJSON?, HisnJSON?) {
        // This runs on a background thread - no main thread blocking!
        return try await Task.detached(priority: .userInitiated) {
            var athkarData: DailyAthkarJSON?
            var hisnData: HisnJSON?
            
            let decoder = JSONDecoder()
            
            // Parse daily_athkar.json
            if let url = Bundle.main.url(forResource: "daily_athkar", withExtension: "json") {
                let data = try Data(contentsOf: url)
                athkarData = try decoder.decode(DailyAthkarJSON.self, from: data)
            }
            
            // Parse hisn.json
            if let url = Bundle.main.url(forResource: "hisn", withExtension: "json") {
                let data = try Data(contentsOf: url)
                hisnData = try decoder.decode(HisnJSON.self, from: data)
            }
            
            return (athkarData, hisnData)
        }.value
    }

    // MARK: - Database Operations (MAIN THREAD - required by SwiftData)
    
    private func importParsedData(athkarData: DailyAthkarJSON?, hisnData: HisnJSON?) async throws {
        // Fetch existing items once
        let descriptor = FetchDescriptor<DhikrItem>()
        let existingItems = try modelContext.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingItems.compactMap { item -> (String, DhikrItem)? in
            guard let sourceId = item.sourceId else { return nil }
            return (sourceId, item)
        })
        
        // Import daily athkar
        if let athkar = athkarData?.athkar {
            for dhikr in athkar {
                let category = DhikrCategory(rawValue: dhikr.category) ?? .general
                
                if let existing = existingMap[dhikr.id] {
                    existing.title = dhikr.title
                    existing.category = category.rawValue
                    existing.text = dhikr.text
                    existing.reference = dhikr.reference
                    existing.repeatMin = dhikr.repeat.min
                    existing.repeatMax = dhikr.repeat.max
                    existing.repeatNote = dhikr.repeat.note
                    existing.orderIndex = dhikr.orderIndex
                    existing.benefit = dhikr.benefit
                    existing.grading = dhikr.grading
                    existing.isOptional = dhikr.isOptional ?? false
                    existing.source = DhikrSource.daily.rawValue
                } else {
                    let item = DhikrItem(
                        sourceId: dhikr.id,
                        source: .daily,
                        title: dhikr.title,
                        category: category.rawValue,
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
        }
        
        // Yield to allow UI updates
        await Task.yield()
        
        // Import hisn data
        if let duas = hisnData?.duas {
            for dua in duas {
                let hisnCategory = HisnCategory(rawValue: dua.category)
                
                if let existing = existingMap[dua.id] {
                    existing.title = dua.title
                    existing.category = "hisn"
                    existing.hisnCategory = hisnCategory?.rawValue
                    existing.text = dua.text
                    existing.reference = dua.reference
                    existing.repeatMin = dua.repeat.min
                    existing.repeatMax = dua.repeat.max
                    existing.repeatNote = dua.repeat.note
                    existing.orderIndex = dua.orderIndex
                    existing.benefit = dua.benefit
                    existing.grading = dua.grading
                    existing.isOptional = dua.isOptional ?? false
                    existing.source = DhikrSource.hisn.rawValue
                } else {
                    let item = DhikrItem(
                        sourceId: dua.id,
                        source: .hisn,
                        title: dua.title,
                        category: "hisn",
                        hisnCategory: hisnCategory,
                        text: dua.text,
                        reference: dua.reference,
                        repeatMin: dua.repeat.min,
                        repeatMax: dua.repeat.max,
                        repeatNote: dua.repeat.note,
                        orderIndex: dua.orderIndex,
                        benefit: dua.benefit,
                        grading: dua.grading,
                        isOptional: dua.isOptional ?? false
                    )
                    modelContext.insert(item)
                }
            }
        }
        
        // Single save at the end (batched)
        try modelContext.save()
    }
}
