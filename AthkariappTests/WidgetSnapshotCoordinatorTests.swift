import XCTest
@testable import Athkariapp

final class WidgetSnapshotCoordinatorTests: XCTestCase {

    func testSessionTakesPrecedenceOverPrayer() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let session = LiveActivityCoordinator.SessionSnapshot(
            slotKey: "morning",
            title: "أذكار الصباح",
            subtitle: "سبحان الله",
            currentCount: 3,
            targetCount: 10,
            progress: 0.3
        )

        let prayerWindow = LiveActivityCoordinator.PrayerWindowSnapshot(
            slotKey: "after_fajr",
            title: "أذكار بعد الفجر",
            subtitle: "نافذة ما بعد الأذان",
            prayerName: "الفجر",
            windowStartDate: now,
            windowEndDate: now.addingTimeInterval(15 * 60)
        )

        let snapshot = WidgetSnapshotCoordinator.makeSnapshot(
            currentDate: now,
            session: session,
            prayerWindow: prayerWindow,
            nextPrayer: WidgetSnapshotCoordinator.NextPrayerSnapshot(
                name: "صلاة الظهر",
                date: now.addingTimeInterval(3_600)
            )
        )

        XCTAssertEqual(snapshot.effectiveRouteURL, AthkariWidgetRoutes.session(slotKey: "morning"))
        if case .session = snapshot.activeContent {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected session content to take precedence.")
        }
    }

    func testActiveSessionOverridesHeroCardSnapshot() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = LiveActivityCoordinator.SessionSnapshot(
            slotKey: "morning",
            title: "أذكار الصباح",
            subtitle: "سبحان الله",
            currentCount: 3,
            targetCount: 10,
            progress: 0.3
        )
        let heroCard = WidgetSnapshotCoordinator.HeroCardSnapshot(
            slotKey: "sleep",
            headerLabel: "الذكر الحالي",
            title: "أذكار النوم",
            subtitle: "ينتهي الذكر الحالي خلال 1س 17د",
            heroPrimaryLine: "ينتهي الذكر الحالي خلال 1س 17د",
            heroSecondaryLine: "التالي: أذكار الاستيقاظ",
            completionText: "0/17 مكتمل",
            currentCount: 0,
            targetCount: 17,
            progress: 0,
            windowEndDate: now.addingTimeInterval(3_600),
            nextTitle: "أذكار الاستيقاظ",
            iconSystemName: "moon.zzz.fill",
            routeURL: "athkari://session?slot=sleep"
        )

        let snapshot = WidgetSnapshotCoordinator.makeSnapshot(
            currentDate: now,
            session: session,
            heroCard: heroCard,
            prayerWindow: nil,
            nextPrayer: nil
        )

        XCTAssertEqual(snapshot.session?.slotKey, "morning")
        XCTAssertEqual(snapshot.effectiveRouteURL, AthkariWidgetRoutes.session(slotKey: "morning"))
    }

    func testClearingSessionFallsBackToPrayer() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let prayerWindow = LiveActivityCoordinator.PrayerWindowSnapshot(
            slotKey: "after_fajr",
            title: "أذكار بعد الفجر",
            subtitle: "نافذة ما بعد الأذان",
            prayerName: "الفجر",
            windowStartDate: now,
            windowEndDate: now.addingTimeInterval(900)
        )

        let snapshot = WidgetSnapshotCoordinator.makeSnapshot(
            currentDate: now,
            session: nil,
            prayerWindow: prayerWindow,
            nextPrayer: WidgetSnapshotCoordinator.NextPrayerSnapshot(
                name: "صلاة الظهر",
                date: now.addingTimeInterval(3_600)
            )
        )

        XCTAssertEqual(snapshot.effectiveRouteURL, AthkariWidgetRoutes.session(slotKey: "after_fajr"))
        if case .prayer = snapshot.activeContent {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected prayer content when session is nil.")
        }
    }

    func testNilSessionAndPrayerFallsBackToHomeRoute() {
        let snapshot = WidgetSnapshotCoordinator.makeSnapshot(
            currentDate: Date(),
            session: nil,
            prayerWindow: nil,
            nextPrayer: nil
        )

        XCTAssertEqual(snapshot.effectiveRouteURL, AthkariWidgetRoutes.home)
        if case .fallback = snapshot.activeContent {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected fallback content when all sources are nil.")
        }
    }

    func testHeroCardUsedWhenSessionIsNil() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let heroCard = WidgetSnapshotCoordinator.HeroCardSnapshot(
            slotKey: "sleep",
            headerLabel: "الذكر الحالي",
            title: "أذكار النوم",
            subtitle: "ينتهي الذكر الحالي خلال 1س 17د",
            heroPrimaryLine: "ينتهي الذكر الحالي خلال 1س 17د",
            heroSecondaryLine: "التالي: أذكار الاستيقاظ",
            completionText: "0/17 مكتمل",
            currentCount: 0,
            targetCount: 17,
            progress: 0,
            windowEndDate: now.addingTimeInterval(3_600),
            nextTitle: "أذكار الاستيقاظ",
            iconSystemName: "moon.zzz.fill",
            routeURL: "athkari://session?slot=sleep"
        )

        let snapshot = WidgetSnapshotCoordinator.makeSnapshot(
            currentDate: now,
            session: nil,
            heroCard: heroCard,
            prayerWindow: nil,
            nextPrayer: nil
        )

        XCTAssertEqual(snapshot.session?.title, "أذكار النوم")
        XCTAssertEqual(snapshot.session?.heroPrimaryLine, "ينتهي الذكر الحالي خلال 1س 17د")
        XCTAssertEqual(snapshot.session?.heroSecondaryLine, "التالي: أذكار الاستيقاظ")
        XCTAssertEqual(snapshot.session?.completionText, "0/17 مكتمل")
        XCTAssertEqual(snapshot.effectiveRouteURL, "athkari://session?slot=sleep")
    }

    func testPrayerRouteWithoutSlotGoesHome() {
        XCTAssertEqual(AthkariWidgetRoutes.prayer(slotKey: nil), AthkariWidgetRoutes.home)
    }

    func testSessionRouteWithValidSlot() {
        XCTAssertEqual(
            AthkariWidgetRoutes.session(slotKey: "after_fajr"),
            "athkari://session?slot=after_fajr"
        )
    }
}
