import Foundation
import SwiftData

@MainActor
protocol OnboardingRepositoryProtocol {
    func getState() throws -> OnboardingState
    func updateState(_ state: OnboardingState) throws
    func markCompleted() throws
    func reset() throws -> OnboardingState
}

@MainActor
final class OnboardingRepository: OnboardingRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getState() throws -> OnboardingState {
        let descriptor = FetchDescriptor<OnboardingState>()
        let states = try modelContext.fetch(descriptor)

        if let existing = states.first {
            return existing
        }

        // Create default state
        let defaultState = OnboardingState()
        modelContext.insert(defaultState)
        try modelContext.save()
        return defaultState
    }

    func updateState(_ state: OnboardingState) throws {
        try modelContext.save()
    }

    func markCompleted() throws {
        let state = try getState()
        state.completed = true
        try modelContext.save()
    }

    func reset() throws -> OnboardingState {
        // Delete all existing states
        let descriptor = FetchDescriptor<OnboardingState>()
        let existingStates = try modelContext.fetch(descriptor)
        for state in existingStates {
            modelContext.delete(state)
        }

        // Create new default state
        let defaultState = OnboardingState()
        modelContext.insert(defaultState)
        try modelContext.save()
        return defaultState
    }
}
