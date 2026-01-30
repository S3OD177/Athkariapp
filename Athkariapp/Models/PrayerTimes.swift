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
    func nextPrayer(at time: Date = Date(), includingSunrise: Bool = true) -> (prayer: Prayer, time: Date)? {
        var prayers: [(Prayer, Date)] = [
            (.fajr, fajr),
            (.dhuhr, dhuhr),
            (.asr, asr),
            (.maghrib, maghrib),
            (.isha, isha)
        ]
        
        if includingSunrise {
            prayers.insert((.sunrise, sunrise), at: 1)
        }

        for (prayer, prayerTime) in prayers {
            if time < prayerTime {
                return (prayer, prayerTime)
            }
        }

        // After isha, next is tomorrow's fajr
        // Calculate tomorrow's Fajr (approximated as today's Fajr + 24 hours)
        // ideally we would fetch tomorrow's times, but this is a safe visual fallback
        let nextFajr = fajr.addingTimeInterval(24 * 60 * 60)
        return (.fajr, nextFajr)
    }

    /// Maps current prayer to after-prayer slot if within the active duration
    func afterPrayerSlot(at time: Date = Date(), durationMinutes: Int = 0) -> SlotKey? {
        guard let prayer = currentAdhan(at: time) else { return nil }
        
        // Handle midnight wrap for Isha
        if prayer == .isha && time < fajr {
            // We are well past the duration of last night's Isha unless duration is massive, 
            // but legally we are in "Isha time". 
            // Let's assume consistent logic: check start time.
            // If we are here, we are assuming it started yesterday.
            return prayer.afterPrayerSlot
        }
        
        // Define which prayer time to check against
        guard let adhanTime = timeForPrayer(prayer) else { return nil }
        
        // Start immediately at Adhan
        if time < adhanTime { return nil }
        
        // Check expiration
        let expirationTime = adhanTime.addingTimeInterval(Double(durationMinutes) * 60)
        
        guard time <= expirationTime else {
            return nil
        }

        return prayer.afterPrayerSlot
    }

    /// Returns the prayer if its Adhan has started but the next prayer hasn't begun
    func currentAdhan(at time: Date = Date()) -> Prayer? {
        let prayer = currentPrayer(at: time)
        if prayer == .sunrise { return nil }
        
        // Ensure the prayer time has actually passed
        guard let adhanTime = timeForPrayer(prayer) else { return nil }
        
        // Special handling for Isha after midnight (early morning)
        // If currentPrayer is .isha and we are before Fajr, it effectively refers to previous night's Isha.
        if prayer == .isha && time < fajr {
            return .isha
        }
        
        if time < adhanTime {
            return nil
        }
        
        return prayer
    }

    /// Check if post-prayer is active (between Adhan and Adhan + Duration)
    func isPostPrayerReady(for prayer: Prayer, at time: Date = Date(), durationMinutes: Int) -> Bool {
        // Midnight fallback
        if prayer == .isha && time < fajr {
            // If past midnight, we are likely past the duration unless duration is huge (e.g. > 4 hours)
            // But let's check properly if needed. For now, assuming standard usage (< 60 mins), it's expired.
            return false
        }
        
        guard let adhanTime = timeForPrayer(prayer) else { return false }
        
        // Start immediately at Adhan
        if time < adhanTime { return false }
        
        // End after duration
        let expirationTime = adhanTime.addingTimeInterval(Double(durationMinutes) * 60)
        if time > expirationTime { return false }
        
        if let next = nextPrayer(at: adhanTime) {
            return time < next.time
        }
        
        return true
    }

    func timeForPrayer(_ prayer: Prayer) -> Date? {
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
