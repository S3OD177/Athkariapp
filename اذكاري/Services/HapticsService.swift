import UIKit

protocol HapticsServiceProtocol {
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func playSelection()
}

final class HapticsService: HapticsServiceProtocol {
    private var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func playSelection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
