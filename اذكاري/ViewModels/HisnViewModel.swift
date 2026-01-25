import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class HisnViewModel {
    // MARK: - Published State
    var categories: [HisnCategory] = HisnCategory.allCases
    var selectedCategory: HisnCategory?
    var duaList: [DhikrItem] = []
    var filteredDuaList: [DhikrItem] = []
    var searchQuery: String = "" {
        didSet { filterDuas() }
    }
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies
    private let dhikrRepository: DhikrRepository
    private let favoritesRepository: FavoritesRepository

    // MARK: - Initialization
    init(
        dhikrRepository: DhikrRepository,
        favoritesRepository: FavoritesRepository
    ) {
        self.dhikrRepository = dhikrRepository
        self.favoritesRepository = favoritesRepository
    }

    // MARK: - Public Methods
    func loadDuas() async {
        isLoading = true
        errorMessage = nil

        do {
            duaList = try dhikrRepository.fetchBySource(.hisn)
            filterDuas()
        } catch {
            errorMessage = "حدث خطأ في تحميل الأدعية"
            print("Error loading duas: \(error)")
        }

        isLoading = false
    }

    func selectCategory(_ category: HisnCategory?) {
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
        filterDuas()
    }

    func toggleFavorite(_ dua: DhikrItem) throws -> Bool {
        try favoritesRepository.toggleFavorite(dhikrId: dua.id)
    }

    func isFavorite(_ dua: DhikrItem) throws -> Bool {
        try favoritesRepository.isFavorite(dhikrId: dua.id)
    }

    // MARK: - Private Methods
    private func filterDuas() {
        var result = duaList

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.hisnCategory == category.rawValue }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            result = result.filter { dua in
                dua.title.localizedCaseInsensitiveContains(searchQuery) ||
                dua.text.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        filteredDuaList = result
    }
}
