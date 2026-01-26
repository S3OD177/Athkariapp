import Foundation
import SwiftData

@MainActor
protocol DhikrRepositoryProtocol {
    func fetchAll() throws -> [DhikrItem]
    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem]
    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem]
    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem]
    func fetchById(_ id: UUID) throws -> DhikrItem?
    func search(query: String) throws -> [DhikrItem]
    func insert(_ item: DhikrItem) throws
    func insertBatch(_ items: [DhikrItem]) throws
    func delete(_ item: DhikrItem) throws
    func count() throws -> Int
}

@MainActor
final class DhikrRepository: DhikrRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [DhikrItem] {
        let descriptor = FetchDescriptor<DhikrItem>()
        let items = try modelContext.fetch(descriptor)
        return items.sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem] {
        let sourceValue = source.rawValue
        let allItems = try fetchAll()
        return allItems.filter { $0.source == sourceValue }
    }

    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let allItems = try fetchAll()
        return allItems.filter { $0.category == categoryValue }
    }

    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let allItems = try fetchAll()
        return allItems.filter { $0.hisnCategory == categoryValue }
    }

    func fetchById(_ id: UUID) throws -> DhikrItem? {
        let allItems = try fetchAll()
        return allItems.first { $0.id == id }
    }

    func search(query: String) throws -> [DhikrItem] {
        let allItems = try fetchAll()
        return allItems.filter { item in
            item.title.localizedStandardContains(query) ||
            item.text.localizedStandardContains(query)
        }
    }

    func insert(_ item: DhikrItem) throws {
        modelContext.insert(item)
        try modelContext.save()
    }

    func insertBatch(_ items: [DhikrItem]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    func delete(_ item: DhikrItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    func count() throws -> Int {
        let descriptor = FetchDescriptor<DhikrItem>()
        return try modelContext.fetchCount(descriptor)
    }
}
