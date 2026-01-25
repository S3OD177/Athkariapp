import XCTest
@testable import Athkariapp

final class SessionStateTests: XCTestCase {

    func testSessionProgress() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            currentCount: 15,
            targetCount: 33
        )

        XCTAssertEqual(session.progress, 15.0 / 33.0, accuracy: 0.001)
    }

    func testSessionProgressZeroTarget() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            currentCount: 0,
            targetCount: 0
        )

        XCTAssertEqual(session.progress, 0.0)
    }

    func testSessionProgressCompleted() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            currentCount: 33,
            targetCount: 33
        )

        XCTAssertEqual(session.progress, 1.0)
    }

    func testSessionProgressOverflow() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            currentCount: 50,
            targetCount: 33
        )

        // Progress should cap at 1.0
        XCTAssertEqual(session.progress, 1.0)
    }

    func testSessionStatusNotStarted() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            status: .notStarted
        )

        XCTAssertEqual(session.sessionStatus, .notStarted)
        XCTAssertFalse(session.isCompleted)
    }

    func testSessionStatusPartial() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            currentCount: 10,
            targetCount: 33,
            status: .partial
        )

        XCTAssertEqual(session.sessionStatus, .partial)
        XCTAssertFalse(session.isCompleted)
    }

    func testSessionStatusCompleted() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning,
            currentCount: 33,
            targetCount: 33,
            status: .completed
        )

        XCTAssertEqual(session.sessionStatus, .completed)
        XCTAssertTrue(session.isCompleted)
    }

    func testSlotKeyMapping() {
        let session = SessionState(
            date: Date(),
            slotKey: .morning
        )

        XCTAssertEqual(session.slot, .morning)
        XCTAssertEqual(session.slotKey, "morning")
    }

    func testDateStartOfDay() {
        let now = Date()
        let session = SessionState(
            date: now,
            slotKey: .evening
        )

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)

        XCTAssertEqual(session.date, startOfDay)
    }
}
