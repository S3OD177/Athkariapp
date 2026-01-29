@preconcurrency import Foundation
@preconcurrency import SwiftData

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
        return try modelContext.fetch(descriptor).sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem] {
        let sourceValue = source.rawValue
        let predicate = #Predicate<DhikrItem> { item in item.source == sourceValue }
        let descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        return try modelContext.fetch(descriptor).sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let predicate = #Predicate<DhikrItem> { item in item.category == categoryValue }
        let descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        return try modelContext.fetch(descriptor).sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let predicate = #Predicate<DhikrItem> { item in item.hisnCategory == categoryValue }
        let descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        return try modelContext.fetch(descriptor).sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchById(_ id: UUID) throws -> DhikrItem? {
        let predicate = #Predicate<DhikrItem> { item in item.id == id }
        var descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func search(query: String) throws -> [DhikrItem] {
        let predicate = #Predicate<DhikrItem> { item in
            item.title.localizedStandardContains(query) ||
            item.text.localizedStandardContains(query)
        }
        let descriptor = FetchDescriptor<DhikrItem>(predicate: predicate)
        return try modelContext.fetch(descriptor).sorted { $0.orderIndex < $1.orderIndex }
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
