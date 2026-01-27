import Foundation
import SwiftData

@Model
final class OnboardingState {
    @Attribute(.unique) var id: UUID
    var completed: Bool
    var userName: String?
    var locationChosen: Bool
    var notificationsChoice: Bool
    var currentStep: Int

    init(
        id: UUID = UUID(),
        completed: Bool = false,
        userName: String? = nil,
        locationChosen: Bool = false,
        notificationsChoice: Bool = false,
        currentStep: Int = 0
    ) {
        self.id = id
        self.completed = completed
        self.userName = userName
        self.locationChosen = locationChosen
        self.notificationsChoice = notificationsChoice
        self.currentStep = currentStep
    }


}
