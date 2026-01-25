import Foundation
import SwiftData

/// Links a dhikr to a specific routine slot (user customization)
@Model
final class UserRoutineLink {
    @Attribute(.unique) var id: UUID
    var dhikrId: UUID
    var slotKey: String // SlotKey rawValue
    var orderIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dhikrId: UUID,
        slotKey: SlotKey,
        orderIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dhikrId = dhikrId
        self.slotKey = slotKey.rawValue
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }

    var slot: SlotKey? {
        SlotKey(rawValue: slotKey)
    }
}
