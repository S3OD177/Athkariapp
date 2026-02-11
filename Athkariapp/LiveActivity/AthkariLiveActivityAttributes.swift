import ActivityKit
import Foundation

enum LiveActivityMode: String, Codable, Hashable, Sendable {
    case session
    case prayerWindow
}

struct AthkariLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mode: LiveActivityMode
        var title: String
        var subtitle: String
        var currentCount: Int
        var targetCount: Int
        var progress: Double
        var slotKey: String?
        var prayerName: String?
        var windowEndDate: Date?
        var lastUpdated: Date

        var normalizedProgress: Double {
            min(max(progress, 0), 1)
        }
    }

    var activityID: String
}
