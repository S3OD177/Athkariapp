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
    var targetCount: Int
    var status: String // SessionStatus rawValue
    var lastUpdated: Date
    var completedDhikrIds: [UUID]

    init(
        id: UUID = UUID(),
        date: Date,
        slotKey: SlotKey,
        currentDhikrId: UUID? = nil,
        currentCount: Int = 0,
        targetCount: Int = 0,
        status: SessionStatus = .notStarted,
        completedDhikrIds: [UUID] = []
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.slotKey = slotKey.rawValue
        self.currentDhikrId = currentDhikrId
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.status = status.rawValue
        self.lastUpdated = Date()
        self.completedDhikrIds = completedDhikrIds
    }

    var sessionStatus: SessionStatus {
        get { SessionStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
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
}
