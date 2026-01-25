import Foundation
import SwiftData

@MainActor
protocol SessionRepositoryProtocol {
    func fetchTodaySessions() throws -> [SessionState]
    func fetchSession(date: Date, slotKey: SlotKey) throws -> SessionState?
    func fetchOrCreateSession(date: Date, slotKey: SlotKey) throws -> SessionState
    func update(_ session: SessionState) throws
    func insert(_ session: SessionState) throws
    func delete(_ session: SessionState) throws
    func fetchSessionsForDateRange(from: Date, to: Date) throws -> [SessionState]
}

@MainActor
final class SessionRepository: SessionRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchTodaySessions() throws -> [SessionState] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<SessionState> { session in
            session.date == startOfDay
        }
        var descriptor = FetchDescriptor<SessionState>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.slotKey)]
        return try modelContext.fetch(descriptor)
    }

    func fetchSession(date: Date, slotKey: SlotKey) throws -> SessionState? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let slotValue = slotKey.rawValue
        let predicate = #Predicate<SessionState> { session in
            session.date == startOfDay && session.slotKey == slotValue
        }
        let descriptor = FetchDescriptor<SessionState>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    func fetchOrCreateSession(date: Date, slotKey: SlotKey) throws -> SessionState {
        if let existing = try fetchSession(date: date, slotKey: slotKey) {
            return existing
        }

        let session = SessionState(date: date, slotKey: slotKey)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    func update(_ session: SessionState) throws {
        session.lastUpdated = Date()
        try modelContext.save()
    }

    func insert(_ session: SessionState) throws {
        modelContext.insert(session)
        try modelContext.save()
    }

    func delete(_ session: SessionState) throws {
        modelContext.delete(session)
        try modelContext.save()
    }

    func fetchSessionsForDateRange(from: Date, to: Date) throws -> [SessionState] {
        let fromStart = Calendar.current.startOfDay(for: from)
        let toStart = Calendar.current.startOfDay(for: to)
        let predicate = #Predicate<SessionState> { session in
            session.date >= fromStart && session.date <= toStart
        }
        var descriptor = FetchDescriptor<SessionState>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date), SortDescriptor(\.slotKey)]
        return try modelContext.fetch(descriptor)
    }
}
