import XCTest
import CoreLocation
@testable import اذكاري

final class PrayerTimeServiceTests: XCTestCase {

    var service: PrayerTimeService!

    override func setUp() {
        super.setUp()
        service = PrayerTimeService()
    }

    func testPrayerTimesGeneration() {
        let meccaLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let date = Date()

        let times = service.getPrayerTimes(date: date, location: meccaLocation, method: .ummAlQura)

        // All times should be on the same day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        XCTAssertEqual(times.date, startOfDay)

        // Fajr should be before sunrise
        XCTAssertLessThan(times.fajr, times.sunrise)

        // Sunrise should be before dhuhr
        XCTAssertLessThan(times.sunrise, times.dhuhr)

        // Dhuhr should be before asr
        XCTAssertLessThan(times.dhuhr, times.asr)

        // Asr should be before maghrib
        XCTAssertLessThan(times.asr, times.maghrib)

        // Maghrib should be before isha
        XCTAssertLessThan(times.maghrib, times.isha)
    }

    func testDefaultPrayerTimes() {
        let times = service.getDefaultPrayerTimes()

        // Should return valid times
        XCTAssertLessThan(times.fajr, times.sunrise)
        XCTAssertLessThan(times.sunrise, times.dhuhr)
    }

    func testCurrentPrayerDetection() {
        let meccaLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let date = Date()

        let times = service.getPrayerTimes(date: date, location: meccaLocation, method: .ummAlQura)

        // Test prayer detection at specific times
        let testTimeFajr = times.fajr.addingTimeInterval(60) // 1 minute after fajr
        XCTAssertEqual(times.currentPrayer(at: testTimeFajr), .fajr)

        let testTimeDhuhr = times.dhuhr.addingTimeInterval(60)
        XCTAssertEqual(times.currentPrayer(at: testTimeDhuhr), .dhuhr)

        let testTimeAsr = times.asr.addingTimeInterval(60)
        XCTAssertEqual(times.currentPrayer(at: testTimeAsr), .asr)

        let testTimeMaghrib = times.maghrib.addingTimeInterval(60)
        XCTAssertEqual(times.currentPrayer(at: testTimeMaghrib), .maghrib)

        let testTimeIsha = times.isha.addingTimeInterval(60)
        XCTAssertEqual(times.currentPrayer(at: testTimeIsha), .isha)
    }

    func testAfterPrayerSlotMapping() {
        let meccaLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let date = Date()

        let times = service.getPrayerTimes(date: date, location: meccaLocation, method: .ummAlQura)

        // After fajr
        let testTimeFajr = times.fajr.addingTimeInterval(60)
        XCTAssertEqual(times.afterPrayerSlot(at: testTimeFajr), .afterFajr)

        // After dhuhr
        let testTimeDhuhr = times.dhuhr.addingTimeInterval(60)
        XCTAssertEqual(times.afterPrayerSlot(at: testTimeDhuhr), .afterDhuhr)

        // After asr
        let testTimeAsr = times.asr.addingTimeInterval(60)
        XCTAssertEqual(times.afterPrayerSlot(at: testTimeAsr), .afterAsr)

        // After maghrib
        let testTimeMaghrib = times.maghrib.addingTimeInterval(60)
        XCTAssertEqual(times.afterPrayerSlot(at: testTimeMaghrib), .afterMaghrib)

        // After isha
        let testTimeIsha = times.isha.addingTimeInterval(60)
        XCTAssertEqual(times.afterPrayerSlot(at: testTimeIsha), .afterIsha)
    }

    func testDifferentCalculationMethods() {
        let location = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
        let date = Date()

        let ummAlQura = service.getPrayerTimes(date: date, location: location, method: .ummAlQura)
        let mwl = service.getPrayerTimes(date: date, location: location, method: .muslimWorldLeague)

        // Different methods should produce slightly different times
        // (they may be equal in some edge cases, but generally different)
        // Just ensure they both produce valid times
        XCTAssertLessThan(ummAlQura.fajr, ummAlQura.sunrise)
        XCTAssertLessThan(mwl.fajr, mwl.sunrise)
    }
}
