import Foundation

/// Prayer times for a given day
struct PrayerTimes: Equatable, Sendable {
    let date: Date
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    /// Current prayer based on time
    func currentPrayer(at time: Date = Date()) -> Prayer {
        if time < fajr { return .isha } // After midnight, before fajr
        if time < sunrise { return .fajr }
        if time < dhuhr { return .sunrise }
        if time < asr { return .dhuhr }
        if time < maghrib { return .asr }
        if time < isha { return .maghrib }
        return .isha
    }

    /// Next prayer time
    func nextPrayer(at time: Date = Date()) -> (prayer: Prayer, time: Date)? {
        let prayers: [(Prayer, Date)] = [
            (.fajr, fajr),
            (.sunrise, sunrise),
            (.dhuhr, dhuhr),
            (.asr, asr),
            (.maghrib, maghrib),
            (.isha, isha)
        ]

        for (prayer, prayerTime) in prayers {
            if time < prayerTime {
                return (prayer, prayerTime)
            }
        }

        // After isha, next is tomorrow's fajr
        return nil
    }

    /// Maps current prayer to after-prayer slot
    func afterPrayerSlot(at time: Date = Date()) -> SlotKey? {
        let prayer = currentPrayer(at: time)
        switch prayer {
        case .fajr: return .afterFajr
        case .dhuhr: return .afterDhuhr
        case .asr: return .afterAsr
        case .maghrib: return .afterMaghrib
        case .isha: return .afterIsha
        case .sunrise: return nil
        }
    }
}

/// Prayer type
enum Prayer: String, CaseIterable {
    case fajr = "fajr"
    case sunrise = "sunrise"
    case dhuhr = "dhuhr"
    case asr = "asr"
    case maghrib = "maghrib"
    case isha = "isha"

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    var icon: String {
        switch self {
        case .fajr: return "sunrise.fill"
        case .sunrise: return "sun.horizon.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.fill"
        }
    }
}
