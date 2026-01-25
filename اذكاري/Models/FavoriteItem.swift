import Foundation
import SwiftData

@Model
final class FavoriteItem {
    @Attribute(.unique) var id: UUID
    var dhikrId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dhikrId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dhikrId = dhikrId
        self.createdAt = createdAt
    }
}
