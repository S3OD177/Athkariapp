import XCTest
@testable import Athkariapp

final class AthkariWidgetSnapshotTests: XCTestCase {

    func testDecodeFallbackWhenDataMissing() {
        let snapshot = AthkariWidgetSnapshot.decode(from: nil)
        XCTAssertEqual(snapshot.version, AthkariWidgetSnapshot.currentVersion)
        XCTAssertNil(snapshot.session)
        XCTAssertNil(snapshot.prayer)
        XCTAssertEqual(snapshot.fallback.routeURL, AthkariWidgetRoutes.home)
    }

    func testDecodeFallbackWhenDataCorrupt() {
        let invalidData = Data("not-json".utf8)
        let snapshot = AthkariWidgetSnapshot.decode(from: invalidData)

        XCTAssertNil(snapshot.session)
        XCTAssertNil(snapshot.prayer)
        XCTAssertEqual(snapshot.fallback.routeURL, AthkariWidgetRoutes.home)
    }

    func testEncodeDecodeRoundTripPreservesSession() {
        let source = AthkariWidgetSnapshot(
            version: AthkariWidgetSnapshot.currentVersion,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            session: AthkariWidgetSnapshot.SessionContent(
                slotKey: "morning",
                title: "أذكار الصباح",
                subtitle: "سبحان الله",
                currentCount: 4,
                targetCount: 10,
                progress: 0.4,
                heroLabel: nil,
                heroPrimaryLine: "ينتهي الذكر الحالي خلال 1س 17د",
                heroSecondaryLine: "التالي: أذكار الاستيقاظ",
                completionText: "4/10 مكتمل",
                nextTitle: nil,
                windowEndDate: nil,
                iconSystemName: nil,
                routeURL: AthkariWidgetRoutes.session(slotKey: "morning")
            ),
            prayer: nil,
            fallback: AthkariWidgetSnapshot.FallbackContent(
                title: "أذكاري",
                subtitle: "افتح التطبيق",
                routeURL: AthkariWidgetRoutes.home
            )
        )

        let data = source.encode()
        let decoded = AthkariWidgetSnapshot.decode(from: data)

        XCTAssertEqual(decoded.session?.slotKey, "morning")
        XCTAssertEqual(decoded.session?.heroPrimaryLine, "ينتهي الذكر الحالي خلال 1س 17د")
        XCTAssertEqual(decoded.session?.heroSecondaryLine, "التالي: أذكار الاستيقاظ")
        XCTAssertEqual(decoded.session?.completionText, "4/10 مكتمل")
        XCTAssertEqual(decoded.effectiveRouteURL, AthkariWidgetRoutes.session(slotKey: "morning"))
    }

    func testDecodeFallbackWhenVersionInvalid() {
        let payload = """
        {
          "version": 0,
          "generatedAt": 1700000000,
          "fallback": {
            "title": "X",
            "subtitle": "Y",
            "routeURL": "athkari://home"
          }
        }
        """
        let data = Data(payload.utf8)
        let snapshot = AthkariWidgetSnapshot.decode(from: data)

        XCTAssertEqual(snapshot.version, AthkariWidgetSnapshot.currentVersion)
        XCTAssertEqual(snapshot.effectiveRouteURL, AthkariWidgetRoutes.home)
    }

    func testDecodeOldPayloadWithoutHeroFields() {
        let payload = """
        {
          "version": 1,
          "generatedAt": 1700000000,
          "session": {
            "slotKey": "sleep",
            "title": "أذكار النوم",
            "subtitle": "افتح التطبيق",
            "currentCount": 0,
            "targetCount": 17,
            "progress": 0.0,
            "routeURL": "athkari://session?slot=sleep"
          },
          "fallback": {
            "title": "أذكاري",
            "subtitle": "fallback",
            "routeURL": "athkari://home"
          }
        }
        """

        let snapshot = AthkariWidgetSnapshot.decode(from: Data(payload.utf8))
        XCTAssertEqual(snapshot.session?.slotKey, "sleep")
        XCTAssertNil(snapshot.session?.heroPrimaryLine)
        XCTAssertNil(snapshot.session?.heroSecondaryLine)
        XCTAssertNil(snapshot.session?.completionText)
        XCTAssertEqual(snapshot.effectiveRouteURL, "athkari://session?slot=sleep")
    }

    func testRouteHelpers() {
        XCTAssertEqual(
            AthkariWidgetRoutes.session(slotKey: "morning"),
            "athkari://session?slot=morning"
        )
        XCTAssertEqual(
            AthkariWidgetRoutes.prayer(slotKey: "after_maghrib"),
            "athkari://session?slot=after_maghrib"
        )
        XCTAssertEqual(AthkariWidgetRoutes.prayer(slotKey: nil), AthkariWidgetRoutes.home)
    }
}
