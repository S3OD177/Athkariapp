@preconcurrency import Foundation
@preconcurrency import SwiftData

@MainActor
protocol DhikrRepositoryProtocol {
    func fetchAll() throws -> [DhikrItem]
    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem]
    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem]
    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem]
    func fetchHisnChapters() throws -> [DhikrItem]
    func fetchByTitle(_ title: String) throws -> [DhikrItem]
    func fetchById(_ id: UUID) throws -> DhikrItem?
    func search(query: String) throws -> [DhikrItem]
    func insert(_ item: DhikrItem) throws
    func insertBatch(_ items: [DhikrItem]) throws
    func delete(_ item: DhikrItem) throws
    func count() throws -> Int
}

@preconcurrency
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
        return try fetchAll()
            .filter { $0.source == sourceValue }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        return try fetchAll()
            .filter { $0.category == categoryValue }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        return try fetchAll()
            .filter { $0.hisnCategory == categoryValue }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchHisnChapters() throws -> [DhikrItem] {
        let items = try fetchBySource(.hisn)
        
        // Group by title and keep the first item of each group (as the chapter representative)
        // Maintain order based on the first occurrence
        var uniqueChapters: [DhikrItem] = []
        var seenTitles: Set<String> = []
        
        for item in items {
            if !seenTitles.contains(item.title) {
                seenTitles.insert(item.title)
                uniqueChapters.append(item)
            }
        }
        
        return uniqueChapters
    }
    
    func fetchByTitle(_ title: String) throws -> [DhikrItem] {
        return try fetchAll()
            .filter { $0.title == title }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func fetchById(_ id: UUID) throws -> DhikrItem? {
        return try fetchAll().first { $0.id == id }
    }

    func search(query: String) throws -> [DhikrItem] {
        return try fetchAll()
            .filter { item in
                item.title.localizedStandardContains(query) ||
                item.text.localizedStandardContains(query)
            }
            .sorted { $0.orderIndex < $1.orderIndex }
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
