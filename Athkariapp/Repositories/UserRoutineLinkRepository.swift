import Foundation
import SwiftData

@MainActor
protocol UserRoutineLinkRepositoryProtocol {
    func fetchBySlot(_ slotKey: SlotKey) throws -> [UserRoutineLink]
    func addLink(dhikrId: UUID, slotKey: SlotKey) throws
    func removeLink(dhikrId: UUID, slotKey: SlotKey) throws
    func isLinked(dhikrId: UUID, slotKey: SlotKey) throws -> Bool
    func fetchAllLinksForDhikr(_ dhikrId: UUID) throws -> [UserRoutineLink]
}

@MainActor
final class UserRoutineLinkRepository: UserRoutineLinkRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchBySlot(_ slotKey: SlotKey) throws -> [UserRoutineLink] {
        let slotValue = slotKey.rawValue
        let allLinks = try modelContext.fetch(FetchDescriptor<UserRoutineLink>())
        return allLinks.filter { $0.slotKey == slotValue }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func addLink(dhikrId: UUID, slotKey: SlotKey) throws {
        let exists = try isLinked(dhikrId: dhikrId, slotKey: slotKey)
        guard !exists else { return }

        // Get current max order index for this slot
        let links = try fetchBySlot(slotKey)
        let maxIndex = links.map(\.orderIndex).max() ?? -1

        let link = UserRoutineLink(
            dhikrId: dhikrId,
            slotKey: slotKey,
            orderIndex: maxIndex + 1
        )
        modelContext.insert(link)
        try modelContext.save()
    }

    func removeLink(dhikrId: UUID, slotKey: SlotKey) throws {
        let slotValue = slotKey.rawValue
        let allLinks = try modelContext.fetch(FetchDescriptor<UserRoutineLink>())
        let linksToDelete = allLinks.filter { $0.dhikrId == dhikrId && $0.slotKey == slotValue }

        for link in linksToDelete {
            modelContext.delete(link)
        }
        try modelContext.save()
    }

    func isLinked(dhikrId: UUID, slotKey: SlotKey) throws -> Bool {
        let slotValue = slotKey.rawValue
        let allLinks = try modelContext.fetch(FetchDescriptor<UserRoutineLink>())
        return allLinks.contains { $0.dhikrId == dhikrId && $0.slotKey == slotValue }
    }

    func fetchAllLinksForDhikr(_ dhikrId: UUID) throws -> [UserRoutineLink] {
        let allLinks = try modelContext.fetch(FetchDescriptor<UserRoutineLink>())
        return allLinks.filter { $0.dhikrId == dhikrId }
    }
}
