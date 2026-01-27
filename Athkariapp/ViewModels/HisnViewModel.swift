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
    var fontSize: Double = 1.0
    var errorMessage: String?

    // MARK: - Dependencies
    private let dhikrRepository: DhikrRepository
    private let settingsRepository: SettingsRepositoryProtocol

    // MARK: - Initialization
    init(
        dhikrRepository: DhikrRepository,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.dhikrRepository = dhikrRepository
        self.settingsRepository = settingsRepository
    }

    // MARK: - Public Methods
    func loadDuas() async {
        isLoading = true
        errorMessage = nil

        do {
            duaList = try dhikrRepository.fetchBySource(.hisn)
            if let settings = try? settingsRepository.getSettings() {
                fontSize = settings.fontSize
            }
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
