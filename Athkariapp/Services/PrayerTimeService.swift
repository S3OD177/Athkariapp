import Foundation
import CoreLocation

protocol PrayerTimeServiceProtocol: Sendable {
    func getPrayerTimes(
        date: Date,
        location: CLLocationCoordinate2D,
        method: CalculationMethod
    ) -> PrayerTimes
    
    func fetchPrayerTimes(
        latitude: Double,
        longitude: Double,
        method: Int
    ) async throws -> PrayerTimes
}

/// Simple prayer time calculator using basic astronomical calculations
/// This is a placeholder implementation that can be improved later
final class PrayerTimeService: PrayerTimeServiceProtocol, @unchecked Sendable {
    // Shared state for the app
    var currentPrayerTimes: PrayerTimes?

    // Default location (Mecca) when no location is available
    private let defaultLocation = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    func getPrayerTimes(
        date: Date,
        location: CLLocationCoordinate2D,
        method: CalculationMethod
    ) -> PrayerTimes {
        let calendar = Calendar(identifier: .gregorian)

        // Get day of year
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1

        // Simplified calculation parameters based on method
        let params = getMethodParameters(method)

        // Calculate declination and equation of time (simplified)
        let declination = calculateDeclination(dayOfYear: dayOfYear)
        let equationOfTime = calculateEquationOfTime(dayOfYear: dayOfYear)

        // Calculate solar noon
        let solarNoon = 12.0 - (location.longitude / 15.0) - equationOfTime

        // Calculate prayer times
        let fajrHour = calculateFajr(solarNoon: solarNoon, latitude: location.latitude, declination: declination, angle: params.fajrAngle)
        let sunriseHour = calculateSunrise(solarNoon: solarNoon, latitude: location.latitude, declination: declination)
        let dhuhrHour = solarNoon + 0.0167 // Add 1 minute after solar noon
        let asrHour = calculateAsr(solarNoon: solarNoon, latitude: location.latitude, declination: declination, factor: params.asrFactor)
        let maghribHour = calculateMaghrib(solarNoon: solarNoon, latitude: location.latitude, declination: declination)
        let ishaHour = calculateIsha(solarNoon: solarNoon, latitude: location.latitude, declination: declination, angle: params.ishaAngle)

        // Convert to dates
        let startOfDay = calendar.startOfDay(for: date)

        return PrayerTimes(
            date: startOfDay,
            fajr: dateFromHour(fajrHour, relativeTo: startOfDay),
            sunrise: dateFromHour(sunriseHour, relativeTo: startOfDay),
            dhuhr: dateFromHour(dhuhrHour, relativeTo: startOfDay),
            asr: dateFromHour(asrHour, relativeTo: startOfDay),
            maghrib: dateFromHour(maghribHour, relativeTo: startOfDay),
            isha: dateFromHour(ishaHour, relativeTo: startOfDay)
        )
    }

    // MARK: - Calculation Parameters

    private struct CalculationParameters {
        let fajrAngle: Double
        let ishaAngle: Double
        let asrFactor: Double // 1 for Shafi/Maliki/Hanbali, 2 for Hanafi
    }

    private func getMethodParameters(_ method: CalculationMethod) -> CalculationParameters {
        switch method {
        case .ummAlQura:
            return CalculationParameters(fajrAngle: 18.5, ishaAngle: 0, asrFactor: 1)
        case .muslimWorldLeague:
            return CalculationParameters(fajrAngle: 18, ishaAngle: 17, asrFactor: 1)
        case .egyptian:
            return CalculationParameters(fajrAngle: 19.5, ishaAngle: 17.5, asrFactor: 1)
        case .karachi:
            return CalculationParameters(fajrAngle: 18, ishaAngle: 18, asrFactor: 1)
        case .northAmerica:
            return CalculationParameters(fajrAngle: 15, ishaAngle: 15, asrFactor: 1)
        }
    }

    // MARK: - Astronomical Calculations

    private func calculateDeclination(dayOfYear: Int) -> Double {
        let angle = 2 * .pi * (Double(dayOfYear) - 81) / 365
        return 23.45 * sin(angle) * .pi / 180
    }

    private func calculateEquationOfTime(dayOfYear: Int) -> Double {
        let b = 2 * .pi * (Double(dayOfYear) - 81) / 365
        return 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
    }

    private func calculateFajr(solarNoon: Double, latitude: Double, declination: Double, angle: Double) -> Double {
        let latRad = latitude * .pi / 180
        let angleRad = angle * .pi / 180

        let cosHA = (-sin(angleRad) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))
        let clampedCosHA = max(-1, min(1, cosHA))
        let hourAngle = acos(clampedCosHA) * 180 / .pi / 15

        return solarNoon - hourAngle
    }

    private func calculateSunrise(solarNoon: Double, latitude: Double, declination: Double) -> Double {
        let latRad = latitude * .pi / 180
        let sunriseAngle = 0.833 * .pi / 180 // Standard sunrise angle

        let cosHA = (-sin(sunriseAngle) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))
        let clampedCosHA = max(-1, min(1, cosHA))
        let hourAngle = acos(clampedCosHA) * 180 / .pi / 15

        return solarNoon - hourAngle
    }

    private func calculateAsr(solarNoon: Double, latitude: Double, declination: Double, factor: Double) -> Double {
        let latRad = latitude * .pi / 180
        let shadowAngle = atan(1 / (factor + tan(abs(latRad - declination))))

        let cosHA = (sin(shadowAngle) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))
        let clampedCosHA = max(-1, min(1, cosHA))
        let hourAngle = acos(clampedCosHA) * 180 / .pi / 15

        return solarNoon + hourAngle
    }

    private func calculateMaghrib(solarNoon: Double, latitude: Double, declination: Double) -> Double {
        let latRad = latitude * .pi / 180
        let sunsetAngle = 0.833 * .pi / 180

        let cosHA = (-sin(sunsetAngle) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))
        let clampedCosHA = max(-1, min(1, cosHA))
        let hourAngle = acos(clampedCosHA) * 180 / .pi / 15

        return solarNoon + hourAngle
    }

    private func calculateIsha(solarNoon: Double, latitude: Double, declination: Double, angle: Double) -> Double {
        // For Umm Al-Qura, Isha is 90 minutes after Maghrib
        if angle == 0 {
            let maghrib = calculateMaghrib(solarNoon: solarNoon, latitude: latitude, declination: declination)
            return maghrib + 1.5 // 90 minutes
        }

        let latRad = latitude * .pi / 180
        let angleRad = angle * .pi / 180

        let cosHA = (-sin(angleRad) - sin(latRad) * sin(declination)) / (cos(latRad) * cos(declination))
        let clampedCosHA = max(-1, min(1, cosHA))
        let hourAngle = acos(clampedCosHA) * 180 / .pi / 15

        return solarNoon + hourAngle
    }

    private func dateFromHour(_ hour: Double, relativeTo date: Date) -> Date {
        let totalSeconds = hour * 3600
        return date.addingTimeInterval(totalSeconds)
    }

    // MARK: - API Implementation

    func fetchPrayerTimes(
        latitude: Double,
        longitude: Double,
        method: Int = 4 // Umm Al-Qura default
    ) async throws -> PrayerTimes {
        let urlString = "https://api.aladhan.com/v1/timings/today?latitude=\(latitude)&longitude=\(longitude)&method=\(method)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AladhanResponse.self, from: data)
        
        let timings = response.data.timings
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        func parse(_ time: String) -> Date {
            let components = time.split(separator: " ").first.map(String.init) ?? time
            let datePart = formatter.date(from: components) ?? Date()
            let hour = calendar.component(.hour, from: datePart)
            let minute = calendar.component(.minute, from: datePart)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        let prayerTimesResult = PrayerTimes(
            date: today,
            fajr: parse(timings.Fajr),
            sunrise: parse(timings.Sunrise),
            dhuhr: parse(timings.Dhuhr),
            asr: parse(timings.Asr),
            maghrib: parse(timings.Maghrib),
            isha: parse(timings.Isha)
        )
        
        self.currentPrayerTimes = prayerTimesResult
        return prayerTimesResult
    }
}

// MARK: - API Models

struct AladhanResponse: Codable {
    let data: AladhanData
}

struct AladhanData: Codable {
    let timings: AladhanTimings
}

struct AladhanTimings: Codable {
    let Fajr: String
    let Sunrise: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}

// MARK: - Default Prayer Times

extension PrayerTimeService {
    /// Returns approximate prayer times for today using default location
    func getDefaultPrayerTimes(for date: Date = Date()) -> PrayerTimes {
        let prayerTimesResult = getPrayerTimes(date: date, location: defaultLocation, method: .ummAlQura)
        self.currentPrayerTimes = prayerTimesResult
        return prayerTimesResult
    }
}
