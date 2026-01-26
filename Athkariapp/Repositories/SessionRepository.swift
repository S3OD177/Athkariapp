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
        let allSessions = try modelContext.fetch(FetchDescriptor<SessionState>())
        return allSessions.filter { $0.date == startOfDay }
            .sorted { $0.slotKey < $1.slotKey }
    }

    func fetchSession(date: Date, slotKey: SlotKey) throws -> SessionState? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let slotValue = slotKey.rawValue
        let allSessions = try modelContext.fetch(FetchDescriptor<SessionState>())
        return allSessions.first { $0.date == startOfDay && $0.slotKey == slotValue }
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
        let allSessions = try modelContext.fetch(FetchDescriptor<SessionState>())
        return allSessions.filter { $0.date >= fromStart && $0.date <= toStart }
            .sorted { ($0.date, $0.slotKey) < ($1.date, $1.slotKey) }
    }
}
