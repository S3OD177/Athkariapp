import Foundation
import SwiftData

@MainActor
protocol FavoritesRepositoryProtocol {
    func fetchAll() throws -> [FavoriteItem]
    func isFavorite(dhikrId: UUID) throws -> Bool
    func addFavorite(dhikrId: UUID) throws
    func removeFavorite(dhikrId: UUID) throws
    func toggleFavorite(dhikrId: UUID) throws -> Bool
    func count() throws -> Int
}

@MainActor
final class FavoritesRepository: FavoritesRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [FavoriteItem] {
        var descriptor = FetchDescriptor<FavoriteItem>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try modelContext.fetch(descriptor)
    }

    func isFavorite(dhikrId: UUID) throws -> Bool {
        let predicate = #Predicate<FavoriteItem> { item in
            item.dhikrId == dhikrId
        }
        let descriptor = FetchDescriptor<FavoriteItem>(predicate: predicate)
        return try modelContext.fetchCount(descriptor) > 0
    }

    func addFavorite(dhikrId: UUID) throws {
        let exists = try isFavorite(dhikrId: dhikrId)
        guard !exists else { return }

        let favorite = FavoriteItem(dhikrId: dhikrId)
        modelContext.insert(favorite)
        try modelContext.save()
    }

    func removeFavorite(dhikrId: UUID) throws {
        let predicate = #Predicate<FavoriteItem> { item in
            item.dhikrId == dhikrId
        }
        let descriptor = FetchDescriptor<FavoriteItem>(predicate: predicate)
        let items = try modelContext.fetch(descriptor)

        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func toggleFavorite(dhikrId: UUID) throws -> Bool {
        let exists = try isFavorite(dhikrId: dhikrId)
        if exists {
            try removeFavorite(dhikrId: dhikrId)
            return false
        } else {
            try addFavorite(dhikrId: dhikrId)
            return true
        }
    }

    func count() throws -> Int {
        let descriptor = FetchDescriptor<FavoriteItem>()
        return try modelContext.fetchCount(descriptor)
    }
}
