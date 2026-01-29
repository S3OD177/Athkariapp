import Foundation
import CoreLocation

// MARK: - API Models

struct FastingApiResponse: Codable {
    let status: String
    let data: RootData
}

struct RootData: Codable {
    let fasting: [FastingDay]
}

struct FastingDay: Codable {
    let date: String
    let hijri: String
    let hijri_readable: String?
    let time: FastingTime
}

struct FastingTime: Codable {
    let sahur: String
    let iftar: String
}

// MARK: - Service

protocol FastingServiceProtocol: Sendable {
    func fetchFastingTimes(latitude: Double, longitude: Double) async throws -> FastingTimes
}

struct FastingTimes: Sendable {
    let date: Date
    let suhoor: Date
    let iftar: Date
    let hijriDate: String
}

final class FastingService: FastingServiceProtocol, @unchecked Sendable {
    private let apiKey = "aZUHsql6tGOVHu1YrjvxyU49ASjdrnoC7rr5p0NawQgjxJNP"
    
    func fetchFastingTimes(latitude: Double, longitude: Double) async throws -> FastingTimes {
        let urlString = "https://islamicapi.com/api/v1/fasting/?lat=\(latitude)&lon=\(longitude)&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // Use a shared session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        do {
            let apiResponse = try JSONDecoder().decode(FastingApiResponse.self, from: data)
            
            guard apiResponse.status == "success", let dayData = apiResponse.data.fasting.first else {
                throw URLError(.cannotParseResponse)
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            func parseTime(_ timeString: String) -> Date {
                // Handle "04:15" or "04:15 am"
                let cleaned = timeString.components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: ":"))).joined()
                
                // Try parse with simple HH:mm
                if let date = formatter.date(from: timeString.components(separatedBy: " ").first ?? timeString) {
                    let h = calendar.component(.hour, from: date)
                    let m = calendar.component(.minute, from: date)
                    return calendar.date(bySettingHour: h, minute: m, second: 0, of: today) ?? today
                }
                return today
            }
            
            return FastingTimes(
                date: today,
                suhoor: parseTime(dayData.time.sahur),
                iftar: parseTime(dayData.time.iftar),
                hijriDate: dayData.hijri // "1447-08-10"
            )
            
        } catch {
            print("FastingService Error: \(error)")
            throw error
        }
    }
}
