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
    
    func fetchHijriDate(for date: Date = Date()) async throws -> HijriDateInfo {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateString = formatter.string(from: date)
        
        guard let url = URL(string: "https://api.aladhan.com/v1/gToH?date=\(dateString)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HijriApiResponse.self, from: data)
        return response.data.hijri
    }
}
