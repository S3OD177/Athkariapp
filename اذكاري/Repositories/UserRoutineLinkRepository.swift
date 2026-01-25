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
        let predicate = #Predicate<UserRoutineLink> { link in
            link.slotKey == slotValue
        }
        var descriptor = FetchDescriptor<UserRoutineLink>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.orderIndex)]
        return try modelContext.fetch(descriptor)
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
        let predicate = #Predicate<UserRoutineLink> { link in
            link.dhikrId == dhikrId && link.slotKey == slotValue
        }
        let descriptor = FetchDescriptor<UserRoutineLink>(predicate: predicate)
        let links = try modelContext.fetch(descriptor)

        for link in links {
            modelContext.delete(link)
        }
        try modelContext.save()
    }

    func isLinked(dhikrId: UUID, slotKey: SlotKey) throws -> Bool {
        let slotValue = slotKey.rawValue
        let predicate = #Predicate<UserRoutineLink> { link in
            link.dhikrId == dhikrId && link.slotKey == slotValue
        }
        let descriptor = FetchDescriptor<UserRoutineLink>(predicate: predicate)
        return try modelContext.fetchCount(descriptor) > 0
    }

    func fetchAllLinksForDhikr(_ dhikrId: UUID) throws -> [UserRoutineLink] {
        let predicate = #Predicate<UserRoutineLink> { link in
            link.dhikrId == dhikrId
        }
        let descriptor = FetchDescriptor<UserRoutineLink>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
}
