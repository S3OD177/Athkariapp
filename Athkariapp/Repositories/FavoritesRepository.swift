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
        let descriptor = FetchDescriptor<FavoriteItem>()
        let items = try modelContext.fetch(descriptor)
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func isFavorite(dhikrId: UUID) throws -> Bool {
        let allFavorites = try modelContext.fetch(FetchDescriptor<FavoriteItem>())
        return allFavorites.contains { $0.dhikrId == dhikrId }
    }

    func addFavorite(dhikrId: UUID) throws {
        let exists = try isFavorite(dhikrId: dhikrId)
        guard !exists else { return }

        let favorite = FavoriteItem(dhikrId: dhikrId)
        modelContext.insert(favorite)
        try modelContext.save()
    }

    func removeFavorite(dhikrId: UUID) throws {
        let allFavorites = try modelContext.fetch(FetchDescriptor<FavoriteItem>())
        let itemsToDelete = allFavorites.filter { $0.dhikrId == dhikrId }

        for item in itemsToDelete {
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
