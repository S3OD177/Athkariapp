import Foundation
import SwiftData

/// JSON structures for parsing seed data
struct DailyAthkarJSON: Codable {
    let athkar: [DhikrJSON]
}

struct HisnJSON: Codable {
    let categories: [CategoryJSON]
    let duas: [DhikrJSON]
}

struct CategoryJSON: Codable {
    let id: String
    let name: String
    let icon: String
}

struct DhikrJSON: Codable {
    let id: String
    let category: String
    let title: String
    let text: String
    let reference: String?
    let repeatCount: Int
    let orderIndex: Int
    let benefit: String?
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

    func importSeedDataIfNeeded() async throws {
        try await importAllSeedData()
    }

    func forceReimport() async throws {
        // Delete all existing data
        try modelContext.delete(model: DhikrItem.self)
        try modelContext.save()

        // Import fresh data
        try await importAllSeedData()
    }

    private func importAllSeedData() async throws {
        try importDailyAthkar()
        try importHisnData()
    }

    private func importDailyAthkar() throws {
        guard let url = Bundle.main.url(forResource: "daily_athkar", withExtension: "json") else {
            print("Warning: daily_athkar.json not found in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let athkarData = try decoder.decode(DailyAthkarJSON.self, from: data)

        // Fetch all existing items to minimize individual queries
        let descriptor = FetchDescriptor<DhikrItem>()
        let existingItems = try modelContext.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

        for dhikr in athkarData.athkar {
            let category = DhikrCategory(rawValue: dhikr.category) ?? .general
            let id = UUID(uuidString: dhikr.id) ?? UUID()
            
            if let existing = existingMap[id] {
                // Update existing
                existing.title = dhikr.title
                existing.category = category.rawValue
                existing.text = dhikr.text
                existing.reference = dhikr.reference
                existing.repeatCount = dhikr.repeatCount
                existing.orderIndex = dhikr.orderIndex
                existing.benefit = dhikr.benefit
                existing.source = DhikrSource.daily.rawValue
            } else {
                // Insert new
                let item = DhikrItem(
                    id: id,
                    source: .daily,
                    title: dhikr.title,
                    category: category.rawValue,
                    text: dhikr.text,
                    reference: dhikr.reference,
                    repeatCount: dhikr.repeatCount,
                    orderIndex: dhikr.orderIndex,
                    benefit: dhikr.benefit
                )
                modelContext.insert(item)
            }
        }

        try modelContext.save()
    }

    private func importHisnData() throws {
        guard let url = Bundle.main.url(forResource: "hisn", withExtension: "json") else {
            print("Warning: hisn.json not found in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let hisnData = try decoder.decode(HisnJSON.self, from: data)

        // Fetch all existing items
        let descriptor = FetchDescriptor<DhikrItem>()
        let existingItems = try modelContext.fetch(descriptor)
        let existingMap = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

        for dua in hisnData.duas {
            let hisnCategory = HisnCategory(rawValue: dua.category)
            let id = UUID(uuidString: dua.id) ?? UUID()
            
            if let existing = existingMap[id] {
                // Update existing
                existing.title = dua.title
                existing.category = "hisn"
                existing.hisnCategory = hisnCategory?.rawValue
                existing.text = dua.text
                existing.reference = dua.reference
                existing.repeatCount = dua.repeatCount
                existing.orderIndex = dua.orderIndex
                existing.benefit = dua.benefit
                existing.source = DhikrSource.hisn.rawValue
            } else {
                // Insert new
                let item = DhikrItem(
                    id: id,
                    source: .hisn,
                    title: dua.title,
                    category: "hisn",
                    hisnCategory: hisnCategory,
                    text: dua.text,
                    reference: dua.reference,
                    repeatCount: dua.repeatCount,
                    orderIndex: dua.orderIndex,
                    benefit: dua.benefit
                )
                modelContext.insert(item)
            }
        }

        try modelContext.save()
    }
}
