import SwiftData
import XCTest
@testable import Athkariapp

@MainActor
final class DhikrRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: DhikrRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let schema = Schema([
            DhikrItem.self,
            RoutineSlot.self,
            SessionState.self,
            AppSettings.self,
            OnboardingState.self,
            UserRoutineLink.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(for: schema, configurations: [configuration])
        repository = DhikrRepository(modelContext: container.mainContext)

        try repository.insertBatch([
            DhikrItem(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                source: .daily,
                title: "أذكار الصباح",
                category: DhikrCategory.morning.rawValue,
                text: "أصبحنا وأصبح الملك لله",
                orderIndex: 2
            ),
            DhikrItem(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                source: .daily,
                title: "أذكار المساء",
                category: DhikrCategory.evening.rawValue,
                text: "أمسينا وأمسى الملك لله",
                orderIndex: 1
            ),
            DhikrItem(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                source: .hisn,
                title: "دعاء السفر",
                category: HisnCategory.travel.rawValue,
                hisnCategory: .travel,
                text: "سبحان الذي سخر لنا هذا",
                reference: "سورة الزخرف",
                orderIndex: 3
            ),
            DhikrItem(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                source: .hisn,
                title: "دعاء السفر",
                category: HisnCategory.travel.rawValue,
                hisnCategory: .travel,
                text: "وإنا إلى ربنا لمنقلبون",
                reference: "دعاء ركوب الدابة",
                orderIndex: 4
            )
        ])
    }

    override func tearDownWithError() throws {
        repository = nil
        container = nil
        try super.tearDownWithError()
    }

    func testFetchAllSortsByOrderIndex() throws {
        let items = try repository.fetchAll()

        XCTAssertEqual(items.map(\.title), [
            "أذكار المساء",
            "أذكار الصباح",
            "دعاء السفر",
            "دعاء السفر"
        ])
    }

    func testFetchBySourceUsesPredicateAndSorts() throws {
        let items = try repository.fetchBySource(.daily)

        XCTAssertEqual(items.map(\.title), [
            "أذكار المساء",
            "أذكار الصباح"
        ])
    }

    func testFetchByCategoryUsesPredicate() throws {
        let items = try repository.fetchByCategory(.morning)

        XCTAssertEqual(items.map(\.title), ["أذكار الصباح"])
    }

    func testFetchByHisnCategoryUsesPredicate() throws {
        let items = try repository.fetchByHisnCategory(.travel)

        XCTAssertEqual(items.map(\.title), ["دعاء السفر", "دعاء السفر"])
    }

    func testFetchByTitleUsesPredicateAndSorts() throws {
        let items = try repository.fetchByTitle("أذكار الصباح")

        XCTAssertEqual(items.map(\.text), ["أصبحنا وأصبح الملك لله"])
    }

    func testFetchByIdUsesPredicate() throws {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let item = try repository.fetchById(id)

        XCTAssertEqual(item?.title, "أذكار المساء")
    }

    func testSearchMatchesTitleOrText() throws {
        let titleMatches = try repository.search(query: "السفر")
        let textMatches = try repository.search(query: "الملك")

        XCTAssertEqual(titleMatches.map(\.title), ["دعاء السفر", "دعاء السفر"])
        XCTAssertEqual(textMatches.map(\.title), [
            "أذكار المساء",
            "أذكار الصباح"
        ])
    }

    func testSearchHisnChaptersMatchesTitleTextOrReferenceAndDeduplicatesChapters() throws {
        let titleMatches = try repository.searchHisnChapters(query: "السفر")
        let textMatches = try repository.searchHisnChapters(query: "لمنقلبون")
        let referenceMatches = try repository.searchHisnChapters(query: "الزخرف")

        XCTAssertEqual(titleMatches.map(\.title), ["دعاء السفر"])
        XCTAssertEqual(textMatches.map(\.title), ["دعاء السفر"])
        XCTAssertEqual(referenceMatches.map(\.title), ["دعاء السفر"])
    }

    func testEmptySearchReturnsAllItemsSorted() throws {
        let items = try repository.search(query: "   ")

        XCTAssertEqual(items.map(\.title), [
            "أذكار المساء",
            "أذكار الصباح",
            "دعاء السفر",
            "دعاء السفر"
        ])
    }
}
