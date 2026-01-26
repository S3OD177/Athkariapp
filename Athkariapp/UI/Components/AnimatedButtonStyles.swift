import SwiftUI

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var duration: Double = 0.1
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.easeInOut(duration: duration), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Bounce Button Style
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: configuration.isPressed)
    }
}

// MARK: - Pressable Button Style (Opacity Only)
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions
extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle {
        ScaleButtonStyle()
    }
    
    static func scale(amount: CGFloat = 0.96) -> ScaleButtonStyle {
        ScaleButtonStyle(scaleAmount: amount)
    }
}

extension ButtonStyle where Self == BounceButtonStyle {
    static var bounce: BounceButtonStyle {
        BounceButtonStyle()
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle {
        PressableButtonStyle()
    }
}
