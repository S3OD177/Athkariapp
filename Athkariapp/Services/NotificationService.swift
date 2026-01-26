import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    
    init() {}
    
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    func schedulePostPrayerNotifications(prayerTimes: PrayerTimes, offsetMinutes: Int) async {
        let center = UNUserNotificationCenter.current()
        
        // Clear existing post-prayer notifications
        center.removePendingNotificationRequests(withIdentifiers: Prayer.allCases.map { "post_prayer_\($0.rawValue)" })
        
        for prayer in Prayer.allCases {
            guard prayer != .sunrise else { continue }
            guard let adhanTime = timeForPrayer(prayer, in: prayerTimes) else { continue }
            
            let readyTime = adhanTime.addingTimeInterval(Double(offsetMinutes) * 60)
            
            // Only schedule if time is in the future
            guard readyTime > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("post_prayer_ready_title", comment: "")
            content.body = String(format: NSLocalizedString("post_prayer_ready_body", comment: ""), prayer.arabicName)
            content.sound = .default
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: readyTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "post_prayer_\(prayer.rawValue)",
                content: content,
                trigger: trigger
            )
            
            try? await center.add(request)
        }
    }
    
    private func timeForPrayer(_ prayer: Prayer, in times: PrayerTimes) -> Date? {
        switch prayer {
        case .fajr: return times.fajr
        case .dhuhr: return times.dhuhr
        case .asr: return times.asr
        case .maghrib: return times.maghrib
        case .isha: return times.isha
        case .sunrise: return nil
        }
    }
}
