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
        let descriptor = FetchDescriptor<DhikrItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem] {
        let sourceValue = source.rawValue
        let predicate = #Predicate<DhikrItem> { item in
            item.source == sourceValue
        }
        var descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.orderIndex)]
        return try modelContext.fetch(descriptor)
    }

    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let predicate = #Predicate<DhikrItem> { item in
            item.category == categoryValue
        }
        var descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.orderIndex)]
        return try modelContext.fetch(descriptor)
    }

    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let predicate = #Predicate<DhikrItem> { item in
            item.hisnCategory == categoryValue
        }
        var descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.orderIndex)]
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> DhikrItem? {
        let predicate = #Predicate<DhikrItem> { item in
            item.id == id
        }
        let descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    func search(query: String) throws -> [DhikrItem] {
        let predicate = #Predicate<DhikrItem> { item in
            item.title.localizedStandardContains(query) ||
            item.text.localizedStandardContains(query)
        }
        var descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.orderIndex)]
        return try modelContext.fetch(descriptor)
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
