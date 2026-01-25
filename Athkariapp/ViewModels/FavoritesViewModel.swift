import Foundation
import SwiftUI
import SwiftData

/// Segment for favorites filtering
enum FavoriteSegment: String, CaseIterable {
    case daily = "daily"
    case hisn = "hisn"

    var arabicName: String {
        switch self {
        case .daily: return "الأذكار اليومية"
        case .hisn: return "حصن المسلم"
        }
    }
}

@MainActor
@Observable
final class FavoritesViewModel {
    // MARK: - Published State
    var selectedSegment: FavoriteSegment = .daily
    var favorites: [DhikrItem] = []
    var filteredFavorites: [DhikrItem] = []
    var isLoading: Bool = false
    var errorMessage: String?

    var isEmpty: Bool {
        filteredFavorites.isEmpty
    }

    var emptyStateMessage: String {
        switch selectedSegment {
        case .daily:
            return "لم تقم بإضافة أي أذكار للمفضلة بعد"
        case .hisn:
            return "لم تقم بإضافة أي أدعية للمفضلة بعد"
        }
    }

    // MARK: - Dependencies
    private let favoritesRepository: FavoritesRepository
    private let dhikrRepository: DhikrRepository

    // MARK: - Initialization
    init(
        favoritesRepository: FavoritesRepository,
        dhikrRepository: DhikrRepository
    ) {
        self.favoritesRepository = favoritesRepository
        self.dhikrRepository = dhikrRepository
    }

    // MARK: - Public Methods
    func loadFavorites() async {
        isLoading = true
        errorMessage = nil

        do {
            let favoriteItems = try favoritesRepository.fetchAll()
            var dhikrItems: [DhikrItem] = []

            for fav in favoriteItems {
                if let item = try dhikrRepository.fetchById(fav.dhikrId) {
                    dhikrItems.append(item)
                }
            }

            favorites = dhikrItems
            filterFavorites()
        } catch {
            errorMessage = "حدث خطأ في تحميل المفضلة"
            print("Error loading favorites: \(error)")
        }

        isLoading = false
    }

    func selectSegment(_ segment: FavoriteSegment) {
        selectedSegment = segment
        filterFavorites()
    }

    func removeFavorite(_ dhikr: DhikrItem) throws {
        try favoritesRepository.removeFavorite(dhikrId: dhikr.id)
        favorites.removeAll { $0.id == dhikr.id }
        filterFavorites()
    }

    // MARK: - Private Methods
    private func filterFavorites() {
        switch selectedSegment {
        case .daily:
            filteredFavorites = favorites.filter { $0.dhikrSource == .daily }
        case .hisn:
            filteredFavorites = favorites.filter { $0.dhikrSource == .hisn }
        }
    }
}
