import UIKit

// MARK: - Global Swipe Back Gesture Fix
// This extension restores the interactive pop gesture (swipe back) even when
// the navigation bar is hidden or a custom back button is used.

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
