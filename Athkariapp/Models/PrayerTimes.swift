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

    /// Maps current prayer to after-prayer slot with optional delay (offset in minutes)
    func afterPrayerSlot(at time: Date = Date(), offsetMinutes: Int = 0) -> SlotKey? {
        guard let prayer = currentAdhan(at: time) else { return nil }
        
        // Define which prayer time to check against
        let adhanTime: Date
        switch prayer {
        case .fajr: adhanTime = fajr
        case .dhuhr: adhanTime = dhuhr
        case .asr: adhanTime = asr
        case .maghrib: adhanTime = maghrib
        case .isha: adhanTime = isha
        case .sunrise: return nil
        }
        
        // Only show if the offset time has passed since the adhan
        let availabilityTime = adhanTime.addingTimeInterval(Double(offsetMinutes) * 60)
        
        guard time >= availabilityTime else {
            return nil
        }

        return prayer.afterPrayerSlot
    }

    /// Returns the prayer if its Adhan has started but the next prayer hasn't begun
    func currentAdhan(at time: Date = Date()) -> Prayer? {
        let prayer = currentPrayer(at: time)
        if prayer == .sunrise { return nil }
        
        // Ensure the prayer time has actually passed
        // This handles the case where currentPrayer returns .isha (early morning)
        // but the 'isha' property represents tonight's Isha (future)
        guard let adhanTime = timeForPrayer(prayer) else { return nil }
        if time < adhanTime {
            return nil
        }
        
        return prayer
    }

    /// Check if post-prayer is ready for a specific prayer
    func isPostPrayerReady(for prayer: Prayer, at time: Date = Date(), offsetMinutes: Int) -> Bool {
        guard let adhanTime = timeForPrayer(prayer) else { return false }
        let readyTime = adhanTime.addingTimeInterval(Double(offsetMinutes) * 60)
        
        // Is ready if time is between readyTime and next prayer
        if time < readyTime { return false }
        
        if let next = nextPrayer(at: adhanTime) {
            return time < next.time
        }
        
        return true
    }

    /// Countdown to post-prayer window
    func countdownToPostPrayer(at time: Date = Date(), offsetMinutes: Int) -> (prayer: Prayer, remaining: TimeInterval)? {
        guard let prayer = currentAdhan(at: time) else { return nil }
        guard let adhanTime = timeForPrayer(prayer) else { return nil }
        
        let readyTime = adhanTime.addingTimeInterval(Double(offsetMinutes) * 60)
        
        if time < readyTime {
            return (prayer, readyTime.timeIntervalSince(time))
        }
        
        return nil
    }

    private func timeForPrayer(_ prayer: Prayer) -> Date? {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
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

    var afterPrayerSlot: SlotKey? {
        switch self {
        case .fajr: return .afterFajr
        case .dhuhr: return .afterDhuhr
        case .asr: return .afterAsr
        case .maghrib: return .afterMaghrib
        case .isha: return .afterIsha
        case .sunrise: return nil
        }
    }
}
