import SwiftUI
import UIKit

enum SettingsKey {
    static let parchment = "parchment"
    static let ink = "rubricInk"
    static let hand = "scriptHand"
    static let illuminated = "illuminatedInitials"
    static let canonicalHours = "canonicalHours"
    static let quillSounds = "quillSounds"
    static let quillHaptics = "quillHaptics"
    static let vigilMinutes = "vigilMinutes"
    static let hasSeenWelcome = "hasSeenWelcome"
    static let didSeed = "didSeedWelcomeScroll"
}

/// Light, dark, or follow the system (which follows the sun when set to Automatic).
enum Parchment: String, CaseIterable, Identifiable {
    case vellum, candlelight, bySun

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vellum: "Vellum"
        case .candlelight: "Candlelight"
        case .bySun: "By the sun"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .vellum: .light
        case .candlelight: .dark
        case .bySun: .unspecified
        }
    }
}

enum ScriptHand: String, CaseIterable, Identifiable {
    case bookHand, plain

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bookHand: "Book hand"
        case .plain: "Plain"
        }
    }
}

/// Per-reader preferences that shape how the manuscript is drawn.
struct ScribeStyle: Equatable {
    var ink: RubricInk = .vermilion
    var hand: ScriptHand = .bookHand
    var illuminated = true
    var canonicalHours = true

    var rubric: Color { ink.color }

    /// Writing type: EB Garamond ("book hand") or the system serif ("plain").
    func body(
        _ size: CGFloat,
        _ weight: Typeface.Weight = .regular,
        italic: Bool = false,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        switch hand {
        case .bookHand:
            return .custom(Typeface.garamondName(weight, italic: italic), size: size, relativeTo: style)
        case .plain:
            let font = Font.system(size: size, weight: weight.fontWeight, design: .serif)
            return italic ? font.italic() : font
        }
    }

    func uiBody(_ size: CGFloat, _ weight: Typeface.Weight = .regular, italic: Bool = false) -> UIFont {
        switch hand {
        case .bookHand:
            return Typeface.uiGaramond(size, weight, italic: italic)
        case .plain:
            return Typeface.systemSerif(size, weight: weight.uiWeight, italic: italic)
        }
    }
}

private struct ScribeStyleKey: EnvironmentKey {
    static let defaultValue = ScribeStyle()
}

extension EnvironmentValues {
    var scribe: ScribeStyle {
        get { self[ScribeStyleKey.self] }
        set { self[ScribeStyleKey.self] = newValue }
    }
}

/// Reads the reader's settings and hands them to every view below.
private struct ScribeStyleModifier: ViewModifier {
    @AppStorage(SettingsKey.ink) private var ink: RubricInk = .vermilion
    @AppStorage(SettingsKey.hand) private var hand: ScriptHand = .bookHand
    @AppStorage(SettingsKey.illuminated) private var illuminated = true
    @AppStorage(SettingsKey.canonicalHours) private var canonicalHours = true

    func body(content: Content) -> some View {
        content
            .environment(\.scribe, ScribeStyle(
                ink: ink,
                hand: hand,
                illuminated: illuminated,
                canonicalHours: canonicalHours
            ))
            .tint(ink.color)
    }
}

extension View {
    /// Apply at the root and on the content of every sheet or full-screen cover.
    func scribeStyle() -> some View {
        modifier(ScribeStyleModifier())
    }
}

/// Applies the chosen parchment to every window, including sheets and UIKit views.
enum WindowStyler {
    static func apply(_ parchment: Parchment) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = parchment.interfaceStyle
            }
        }
    }
}
