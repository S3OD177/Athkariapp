import XCTest
@testable import Athkariapp

final class SlotKeyTests: XCTestCase {

    func testAllSlotKeysHaveArabicNames() {
        for slot in SlotKey.allCases {
            XCTAssertFalse(slot.arabicName.isEmpty)
        }
    }

    func testAfterPrayerSlotsIdentified() {
        let afterPrayerSlots: [SlotKey] = [.afterFajr, .afterDhuhr, .afterAsr, .afterMaghrib, .afterIsha]
        let otherSlots: [SlotKey] = [.morning, .evening, .sleep]

        for slot in afterPrayerSlots {
            XCTAssertTrue(slot.isAfterPrayer)
        }

        for slot in otherSlots {
            XCTAssertFalse(slot.isAfterPrayer)
        }
    }

    func testSlotKeysSortOrder() {
        let slots = SlotKey.allCases.sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(slots[0], .wakingUp)
        XCTAssertEqual(slots[1], .morning)
        XCTAssertEqual(slots[2], .afterFajr)
        XCTAssertEqual(slots[8], .sleep)
    }

    func testSlotKeyDhikrCategoryMapping() {
        XCTAssertEqual(SlotKey.morning.dhikrCategory, .morning)
        XCTAssertEqual(SlotKey.evening.dhikrCategory, .evening)
        XCTAssertEqual(SlotKey.sleep.dhikrCategory, .sleep)
        XCTAssertEqual(SlotKey.afterFajr.dhikrCategory, .afterPrayer)
        XCTAssertEqual(SlotKey.afterDhuhr.dhikrCategory, .afterPrayer)
        XCTAssertEqual(SlotKey.afterAsr.dhikrCategory, .afterPrayer)
        XCTAssertEqual(SlotKey.afterMaghrib.dhikrCategory, .afterPrayer)
        XCTAssertEqual(SlotKey.afterIsha.dhikrCategory, .afterPrayer)
    }
}
