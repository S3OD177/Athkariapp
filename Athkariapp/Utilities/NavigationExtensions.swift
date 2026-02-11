import UIKit
import SwiftUI

// MARK: - Swipe Back Enabler
// This helper ViewRepresentable explicitly re-enables the interactive pop gesture
// even when the navigation bar is hidden or back button is custom.

struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController() // Dummy VC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let navigationController = uiViewController.navigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true // Always allow swipe
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        self.background(SwipeBackEnabler())
    }
}

// MARK: - Safe-Area Tap Gesture

private struct SafeAreaInsetsPreferenceKey: PreferenceKey {
    static var defaultValue: EdgeInsets { .init() }

    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

private struct SafeAreaRectShape: Shape {
    var insets: EdgeInsets

    func path(in rect: CGRect) -> Path {
        let left = insets.leading
        let right = insets.trailing
        let top = insets.top
        let bottom = insets.bottom
        let width = max(0, rect.width - left - right)
        let height = max(0, rect.height - top - bottom)

        return Path(CGRect(x: rect.minX + left, y: rect.minY + top, width: width, height: height))
    }
}

private struct SafeAreaTapGestureModifier: ViewModifier {
    let action: () -> Void
    @State private var safeAreaInsets: EdgeInsets = .init()

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SafeAreaInsetsPreferenceKey.self, value: proxy.safeAreaInsets)
                }
            )
            .onPreferenceChange(SafeAreaInsetsPreferenceKey.self) { safeAreaInsets = $0 }
            .contentShape(SafeAreaRectShape(insets: safeAreaInsets))
            .onTapGesture(perform: action)
    }
}

extension View {
    func safeAreaTapGesture(perform action: @escaping () -> Void) -> some View {
        modifier(SafeAreaTapGestureModifier(action: action))
    }
}
