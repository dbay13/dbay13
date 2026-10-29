import Foundation
import LocalAuthentication
import Observation
import SwiftData

/// Remembers which sealed scrolls were opened this session.
/// Everything is resealed when the app goes to the background.
@Observable
final class SealKeeper {
    private(set) var openSeals: Set<PersistentIdentifier> = []

    var hasOpenSeals: Bool { !openSeals.isEmpty }

    func isOpen(_ scroll: Scroll) -> Bool {
        openSeals.contains(scroll.persistentModelID)
    }

    func open(_ scroll: Scroll) {
        openSeals.insert(scroll.persistentModelID)
    }

    func resealAll() {
        openSeals.removeAll()
    }
}

enum Biometrics {
    /// Seals need a device passcode (Face ID or Touch ID are used when set up).
    static var canSeal: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var symbolName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.open"
        }
    }

    /// Face ID / Touch ID with the passcode as fallback.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Keep sealed"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // The passcode was removed after sealing. Nothing on the device can
            // check identity any more, so the seal can only be decorative.
            return true
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
