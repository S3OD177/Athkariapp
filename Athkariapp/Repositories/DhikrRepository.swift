@preconcurrency import Foundation
@preconcurrency import SwiftData

@MainActor
protocol DhikrRepositoryProtocol {
    func fetchAll() throws -> [DhikrItem]
    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem]
    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem]
    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem]
    func fetchHisnChapters() throws -> [DhikrItem]
    func searchHisnChapters(query: String) throws -> [DhikrItem]
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
        let descriptor = FetchDescriptor<DhikrItem>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchBySource(_ source: DhikrSource) throws -> [DhikrItem] {
        let sourceValue = source.rawValue
        let descriptor = FetchDescriptor<DhikrItem>(
            predicate: #Predicate { item in
                item.source == sourceValue
            },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByCategory(_ category: DhikrCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let descriptor = FetchDescriptor<DhikrItem>(
            predicate: #Predicate { item in
                item.category == categoryValue
            },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByHisnCategory(_ category: HisnCategory) throws -> [DhikrItem] {
        let categoryValue = category.rawValue
        let descriptor = FetchDescriptor<DhikrItem>(
            predicate: #Predicate { item in
                item.hisnCategory == categoryValue
            },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchHisnChapters() throws -> [DhikrItem] {
        let items = try fetchBySource(.hisn)
        return uniqueHisnChapters(from: items)
    }

    func searchHisnChapters(query: String) throws -> [DhikrItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return try fetchHisnChapters() }

        let items = try fetchBySource(.hisn)
        let matchingItems = items.filter { item in
            item.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            item.text.localizedCaseInsensitiveContains(trimmedQuery) ||
            (item.reference?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }

        return uniqueHisnChapters(from: matchingItems)
    }

    private func uniqueHisnChapters(from items: [DhikrItem]) -> [DhikrItem] {
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
        let descriptor = FetchDescriptor<DhikrItem>(
            predicate: #Predicate { item in
                item.title == title
            },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> DhikrItem? {
        var descriptor = FetchDescriptor<DhikrItem>(
            predicate: #Predicate { item in
                item.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func search(query: String) throws -> [DhikrItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return try fetchAll() }

        let descriptor = FetchDescriptor<DhikrItem>(
            predicate: #Predicate { item in
                item.title.contains(trimmedQuery) ||
                item.text.contains(trimmedQuery)
            },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
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
