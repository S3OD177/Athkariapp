import Foundation
import SwiftData

@Model
final class OnboardingState {
    @Attribute(.unique) var id: UUID
    var completed: Bool
    var chosenRoutineIntensity: String? // RoutineIntensity rawValue
    var locationChosen: Bool
    var notificationsChoice: Bool
    var currentStep: Int

    init(
        id: UUID = UUID(),
        completed: Bool = false,
        chosenRoutineIntensity: RoutineIntensity? = nil,
        locationChosen: Bool = false,
        notificationsChoice: Bool = false,
        currentStep: Int = 0
    ) {
        self.id = id
        self.completed = completed
        self.chosenRoutineIntensity = chosenRoutineIntensity?.rawValue
        self.locationChosen = locationChosen
        self.notificationsChoice = notificationsChoice
        self.currentStep = currentStep
    }

    var intensity: RoutineIntensity? {
        get {
            guard let chosenRoutineIntensity else { return nil }
            return RoutineIntensity(rawValue: chosenRoutineIntensity)
        }
        set { chosenRoutineIntensity = newValue?.rawValue }
    }
}
