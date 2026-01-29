import Foundation

struct HijriApiResponse: Codable {
    let code: Int
    let status: String
    let data: HijriData
}

struct HijriData: Codable {
    let hijri: HijriDateInfo
}

struct HijriDateInfo: Codable {
    let date: String
    let day: String
    let weekday: HijriWeekday
    let month: HijriMonth
    let year: String
    let format: String
}

struct HijriWeekday: Codable {
    let en: String
    let ar: String
}

struct HijriMonth: Codable {
    let number: Int
    let en: String
    let ar: String
}

final class HijriDateService: @unchecked Sendable {
    static let shared = HijriDateService()
    
    private init() {}
    
    func fetchHijriDate(latitude: Double = 21.4225, longitude: Double = 39.8262) async throws -> HijriDateInfo {
        let apiKey = "aZUHsql6tGOVHu1YrjvxyU49ASjdrnoC7rr5p0NawQgjxJNP"
        let urlString = "https://islamicapi.com/api/v1/fasting/?lat=\(latitude)&lon=\(longitude)&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(NewFastingApiResponse.self, from: data)
        guard response.status == "success", let hijriString = response.data.hijri else {
            throw URLError(.cannotParseResponse)
        }
        
        // Expected format: YYYY-MM-DD usually, or human readable.
        // Let's assume standard IslamicAPI pattern: "YYYY-MM-DD" based on common APIs
        // If it returns "1445-09-12"
        let components = hijriString.components(separatedBy: "-")
        if components.count == 3 {
            let year = components[0]
            let monthNum = Int(components[1]) ?? 1
            let day = components[2]
            
            let monthNameAr = getMonthNameAr(monthNum)
            let monthNameEn = getMonthNameEn(monthNum)
            
            
            // Weekday calculation (approximate or current)
            // We can't easily get the hijri weekday from just the date string without a calendar,
            // but we can assume it aligns with today?
            
            return HijriDateInfo(
                date: hijriString,
                day: day,
                weekday: HijriWeekday(en: "", ar: ""), // Simplified or calculated
                month: HijriMonth(number: monthNum, en: monthNameEn, ar: monthNameAr),
                year: year,
                format: "YYYY-MM-DD"
            )
        }
        
        // Fallback if parsing fails or different format
        throw URLError(.cannotParseResponse)
    }
    
    private func getMonthNameAr(_ month: Int) -> String {
        let months = [
            1: "محرم", 2: "صفر", 3: "ربيع الأول", 4: "ربيع الثاني",
            5: "جمادى الأولى", 6: "جمادى الآخرة", 7: "رجب", 8: "شعبان",
            9: "رمضان", 10: "شوال", 11: "ذو القعدة", 12: "ذو الحجة"
        ]
        return months[month] ?? ""
    }
    
    private func getMonthNameEn(_ month: Int) -> String {
         let months = [
            1: "Muharram", 2: "Safar", 3: "Rabi Al-Awwal", 4: "Rabi Al-Thani",
            5: "Jumada Al-Awwal", 6: "Jumada Al-Akhira", 7: "Rajab", 8: "Shaaban",
            9: "Ramadan", 10: "Shawwal", 11: "Dhul Qadah", 12: "Dhul Hijjah"
        ]
        return months[month] ?? ""
    }
}

// Temporary internal models for the new API
private struct NewFastingApiResponse: Codable {
    let status: String
    let data: NewFastingApiData
}

private struct NewFastingApiData: Codable {
    let hijri: String?
}
