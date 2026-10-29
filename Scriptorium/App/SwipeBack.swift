import SwiftUI
import UIKit

/// The app draws its own top bars and hides the system navigation bar, which
/// switches off the edge-swipe back gesture. This puts it back for the one
/// navigation stack it is placed in, without touching any other screen.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        private let gate = PopGate()

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enable()
        }

        private func enable() {
            guard let navigation = navigationController,
                  let pop = navigation.interactivePopGestureRecognizer else { return }
            gate.navigation = navigation
            pop.delegate = gate
            pop.isEnabled = true
        }
    }
}

private final class PopGate: NSObject, UIGestureRecognizerDelegate {
    weak var navigation: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation else { return false }
        // Never start a swipe while a push or pop is still animating.
        return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
    }
}
