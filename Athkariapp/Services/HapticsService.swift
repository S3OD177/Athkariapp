import UIKit

@MainActor
protocol HapticsServiceProtocol: Sendable {
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func playSelection()
    func setEnabled(_ enabled: Bool)
}

@MainActor
final class HapticsService: HapticsServiceProtocol {
    static let shared = HapticsService()
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
        generator.prepare()
        generator.impactOccurred()
    }

    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func playSelection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
