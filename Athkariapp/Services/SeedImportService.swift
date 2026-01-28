@preconcurrency import Foundation
@preconcurrency import SwiftData

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

    private let seedDataVersion = "5.0" // Fixed category mismatches

    func importSeedDataIfNeeded() async throws {
        // Skip if already imported for this version (INSTANT on subsequent launches)
        let lastVersion = UserDefaults.standard.string(forKey: "seedDataVersion")
        if lastVersion == seedDataVersion {
            return
        }

        // Delete old seed data when migrating to new version
        // Batched deletion to prevent OOM if database is huge
        if lastVersion != nil {
            let userAdded = "user_added"
            // Use Predicate to fetch ONLY deletable items.
            // This avoids fetching 'user_added' items entirely, preventing the infinite loop check issues.
            let predicate = #Predicate<DhikrItem> { item in
                item.source != userAdded
            }
            
            var hasMore = true
            while hasMore {
                // Fetch in batches of 2000
                var descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
                descriptor.fetchLimit = 2000
                
                let batch = try modelContext.fetch(descriptor)
                
                if batch.isEmpty {
                    hasMore = false
                    break
                }
                
                for item in batch {
                    modelContext.delete(item)
                }
                
                try modelContext.save()
                
                // CRITICAL: Yield to the main thread to allow UI (Splash Screen) to render.
                // Without this, the heavy loop blocks the main thread completely, causing a black screen/freeze.
                await Task.yield()
            }
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

    // MARK: - Database Operations (MAIN THREAD - required by SwiftData)

    private func importParsedData(adhkarData: UnifiedAdhkarJSON?) async throws {
        guard let athkar = adhkarData?.athkar else { return }

        // Fetch existing items map optimization
        // Instead of fetching EVERYTHING, we could fetch just IDs if SwiftData allowed projection easily to non-persistent models.
        // For now, we will stick to fetching, but let's yield first.
        await Task.yield()

        let descriptor = FetchDescriptor<DhikrItem>()
        // We can optimize by only fetching items that HAVE a sourceId (which are seed items)
        // predicate: #Predicate<DhikrItem> { $0.sourceId != nil }
        // But for safety against duplicates, we'll fetch all.
        let existingItems = try modelContext.fetch(descriptor)
        
        // Build map for O(1) lookup
        var existingMap = Dictionary(uniqueKeysWithValues: existingItems.compactMap { item -> (String, DhikrItem)? in
            guard let sourceId = item.sourceId else { return nil }
            return (sourceId, item)
        })
        
        // Process in batches to avoid locking UI
        let batchSize = 100
        var processedCount = 0
        
        for dhikr in athkar {
            let dhikrSource = DhikrSource(rawValue: dhikr.source) ?? .daily
            let hisnCategory = dhikr.hisnCategory.flatMap { HisnCategory(rawValue: $0) }

            if let existing = existingMap[dhikr.id] {
                // Update existing
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
                // Insert new
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
                // Add to map to prevent dupes if JSON has dupes
                existingMap[dhikr.id] = item
            }
            
            processedCount += 1
            if processedCount % batchSize == 0 {
                // Yield to allow UI updates
                await Task.yield()
            }
        }

        // Save at the end
        try modelContext.save()
    }
}
