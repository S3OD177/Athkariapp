import Foundation
import SwiftData

/// Status of a session
enum SessionStatus: String, Codable, CaseIterable {
    case notStarted = "not_started"
    case partial = "partial"
    case completed = "completed"

    var arabicName: String {
        switch self {
        case .notStarted: return "لم يبدأ"
        case .partial: return "جزئي"
        case .completed: return "مكتمل"
        }
    }

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .partial: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

@Model
final class SessionState {
    @Attribute(.unique) var id: UUID
    var date: Date // Start of day
    var slotKey: String // SlotKey rawValue
    var currentDhikrId: UUID?
    var currentCount: Int
    var totalDhikrsCount: Int
    var targetCount: Int
    var status: String // SessionStatus rawValue
    var lastUpdated: Date
    var completedDhikrIdsData: Data
    
    // Tracking for post-prayer adhkar
    var completedAt: Date?
    var shownMode: String? // "timeBased" or "manual"
    var offsetUsedMinutes: Int?
    var prayerName: String?
    var adhanTime: Date?

    init(
        id: UUID = UUID(),
        date: Date,
        slotKey: SlotKey,
        currentDhikrId: UUID? = nil,
        currentCount: Int = 0,
        totalDhikrsCount: Int = 0,
        targetCount: Int = 0,
        status: SessionStatus = .notStarted,
        completedDhikrIds: [UUID] = [],
        completedAt: Date? = nil,
        shownMode: String? = nil,
        offsetUsedMinutes: Int? = nil,
        prayerName: String? = nil,
        adhanTime: Date? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.slotKey = slotKey.rawValue
        self.currentDhikrId = currentDhikrId
        self.currentCount = currentCount
        self.totalDhikrsCount = totalDhikrsCount
        self.targetCount = targetCount
        self.status = status.rawValue
        self.lastUpdated = Date()
        self.completedDhikrIdsData = SessionState.encodeCompletedDhikrIds(completedDhikrIds)
        self.completedAt = completedAt
        self.shownMode = shownMode
        self.offsetUsedMinutes = offsetUsedMinutes
        self.prayerName = prayerName
        self.adhanTime = adhanTime
    }

    var sessionStatus: SessionStatus {
        get { SessionStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }

    var completedDhikrIds: [UUID] {
        get { SessionState.decodeCompletedDhikrIds(completedDhikrIdsData) }
        set { completedDhikrIdsData = SessionState.encodeCompletedDhikrIds(newValue) }
    }

    var slot: SlotKey? {
        SlotKey(rawValue: slotKey)
    }

    var progress: Double {
        guard targetCount > 0 else { return 0 }
        return min(Double(currentCount) / Double(targetCount), 1.0)
    }

    var isCompleted: Bool {
        sessionStatus == .completed
    }
    
    /// Returns true if the post-prayer dhikr was completed within 2 hours of the ready time
    var isCompletionOnTime: Bool {
        guard let completedAt = completedAt, 
              let adhanTime = adhanTime,
              let offset = offsetUsedMinutes else { return true } 
        
        let readyTime = adhanTime.addingTimeInterval(Double(offset) * 60)
        let deadline = readyTime.addingTimeInterval(2 * 60 * 60) // 2 hours window
        
        return completedAt <= deadline
    }

    private static func encodeCompletedDhikrIds(_ ids: [UUID]) -> Data {
        (try? JSONEncoder().encode(ids)) ?? Data()
    }

    private static func decodeCompletedDhikrIds(_ data: Data) -> [UUID] {
        (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
    }
}
