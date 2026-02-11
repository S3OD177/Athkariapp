import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class HisnViewModel {
    // MARK: - Published State
    var chapters: [DhikrItem] = []
    var filteredChapters: [DhikrItem] = []
    var searchQuery: String = "" {
        didSet { filterChapters() }
    }
    var isLoading: Bool = false
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
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load unique chapters
            chapters = try dhikrRepository.fetchHisnChapters()
            filterChapters()
        } catch {
            errorMessage = "حدث خطأ في تحميل الكتب"
            print("Error loading chapters: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Methods
    private func filterChapters() {
        if searchQuery.isEmpty {
            filteredChapters = chapters
        } else {
            filteredChapters = chapters.filter { chapter in
                chapter.title.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
}
