import UIKit

@MainActor
protocol HapticsServiceProtocol: Sendable {
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle?)
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func playSelection()
    func setEnabled(_ enabled: Bool)
    func setIntensity(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
}

@MainActor
final class HapticsService: HapticsServiceProtocol {
    static let shared = HapticsService()
    private var isEnabled: Bool
    private var intensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium

    init(isEnabled: Bool = true, intensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        self.isEnabled = isEnabled
        self.intensity = intensity
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func setIntensity(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        self.intensity = style
    }

    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle? = nil) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style ?? intensity)
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
