@preconcurrency import Foundation
@preconcurrency import SwiftData

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
        let predicate = #Predicate<SessionState> { $0.date == startOfDay }
        let descriptor = FetchDescriptor<SessionState>(
            predicate: predicate
        )
        return try modelContext.fetch(descriptor).sorted { $0.slotKey < $1.slotKey }
    }

    func fetchSession(date: Date, slotKey: SlotKey) throws -> SessionState? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let slotValue = slotKey.rawValue
        
        // Note: Predicates on multiple fields
        let predicate = #Predicate<SessionState> {
            $0.date == startOfDay && $0.slotKey == slotValue
        }
        var descriptor = FetchDescriptor<SessionState>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        return try modelContext.fetch(descriptor).first
    }

    func fetchOrCreateSession(date: Date, slotKey: SlotKey) throws -> SessionState {
        if let existing = try fetchSession(date: date, slotKey: slotKey) {
            return existing
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        let session = SessionState(date: startOfDay, slotKey: slotKey)
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
        // Predicates don't support date comparisons perfectly in all SwiftData versions without expanding,
        // but standard >= and <= usually work on Date attributes.
        let predicate = #Predicate<SessionState> {
            $0.date >= fromStart && $0.date <= toStart
        }
        let descriptor = FetchDescriptor<SessionState>(
            predicate: predicate
        )
        let sessions = try modelContext.fetch(descriptor)
        return sessions.sorted { 
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.slotKey < $1.slotKey
        }
    }
}
