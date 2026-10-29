import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// A color that follows light (Vellum) and dark (Candlelight) appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }

    /// Blends two hex colors; `amount` 0 gives `a`, 1 gives `b`.
    static func mix(_ a: UInt32, _ b: UInt32, _ amount: CGFloat) -> UIColor {
        func channel(_ value: UInt32, _ shift: UInt32) -> CGFloat { CGFloat((value >> shift) & 0xFF) / 255 }
        func blend(_ shift: UInt32) -> CGFloat { channel(a, shift) * (1 - amount) + channel(b, shift) * amount }
        return UIColor(red: blend(16), green: blend(8), blue: blend(0), alpha: 1)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(opacity)))
    }
}

/// The manuscript palette. Light values are "Vellum", dark values are "Candlelight".
enum Palette {
    static let groundUI = UIColor.dynamic(light: 0xF3E9D2, dark: 0x1A130D)
    static let cardUI = UIColor.dynamic(light: 0xEEE2C6, dark: 0x221911)
    static let surfaceUI = UIColor.dynamic(light: 0xE8D7B1, dark: 0x2E2318)
    static let barUI = UIColor.dynamic(light: 0xEBDFC3, dark: 0x1F1710)
    static let inkUI = UIColor.dynamic(light: 0x2A1F17, dark: 0xECDDBE)
    static let inkSoftUI = UIColor.dynamic(light: 0x5B4A39, dark: 0xC9B794)
    static let mutedUI = UIColor.dynamic(light: 0x6E5C49, dark: 0xA9957A)
    static let dimUI = UIColor.dynamic(light: 0xA08E73, dark: 0x6F604D)
    static let ruleUI = UIColor.dynamic(light: 0xD9C9A6, dark: 0x36291D)
    static let ruleStrongUI = UIColor.dynamic(light: 0xC4AE84, dark: 0x54422E)
    static let goldUI = UIColor.dynamic(light: 0xB8892B, dark: 0xD4A646)
    static let onRubricUI = UIColor(hex: 0xF8F0DD)
    static let glassUI = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x1E160F, alpha: 0.74) : UIColor(hex: 0xF6EEDC, alpha: 0.74)
    }
    static let shadowUI = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0, alpha: 0.55) : UIColor(hex: 0x3C2610, alpha: 0.2)
    }
    static let vignetteUI = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0, alpha: 0.5) : UIColor(hex: 0x784E18, alpha: 0.16)
    }

    static var ground: Color { Color(uiColor: groundUI) }
    static var card: Color { Color(uiColor: cardUI) }
    static var surface: Color { Color(uiColor: surfaceUI) }
    static var bar: Color { Color(uiColor: barUI) }
    static var ink: Color { Color(uiColor: inkUI) }
    static var inkSoft: Color { Color(uiColor: inkSoftUI) }
    static var muted: Color { Color(uiColor: mutedUI) }
    static var dim: Color { Color(uiColor: dimUI) }
    static var rule: Color { Color(uiColor: ruleUI) }
    static var ruleStrong: Color { Color(uiColor: ruleStrongUI) }
    static var gold: Color { Color(uiColor: goldUI) }
    static var onRubric: Color { Color(uiColor: onRubricUI) }
    static var glass: Color { Color(uiColor: glassUI) }
    static var shadow: Color { Color(uiColor: shadowUI) }
    static var vignette: Color { Color(uiColor: vignetteUI) }

    /// Burning, used for the Burn action.
    static let ember = Color(hex: 0xB4532A)

    /// Gilding for frames and illuminated letters. The same in both themes.
    static let gilt = Color(hex: 0xC99A3C)
    static let giltLight = Color(hex: 0xE9C779)
    static let giltUI = UIColor(hex: 0xC99A3C)
    static let leaf = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xFFF4CF), location: 0),
            .init(color: Color(hex: 0xEBC66C), location: 0.32),
            .init(color: Color(hex: 0xB8862B), location: 0.6),
            .init(color: Color(hex: 0xF4D88E), location: 0.84),
            .init(color: Color(hex: 0xC99A3C), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let silkRibbon = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x6E4E17), location: 0),
            .init(color: Color(hex: 0xB8892B), location: 0.22),
            .init(color: Color(hex: 0xF0D58E), location: 0.42),
            .init(color: Color(hex: 0xC99A3C), location: 0.58),
            .init(color: Color(hex: 0x8A6420), location: 0.82),
            .init(color: Color(hex: 0x5E4212), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Vigil mode: a dark room lit by one candle.
    static let vigilGround = Color(hex: 0x120D09)
    static let vigilInk = UIColor(hex: 0xF1E4C6)
    static let vigilDim = UIColor(hex: 0x5E5141)
    static let vigilMuted = Color(hex: 0x8E7C63)
    static let vigilCaption = Color(hex: 0xB9A586)
    static let flame = Color(hex: 0xFFA94A)
}

/// The rubric ink: the accent used for initials, seals, checkboxes and buttons.
enum RubricInk: String, CaseIterable, Identifiable, Sendable {
    case vermilion, lapis, verdigris, tyrian

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vermilion: "Vermilion"
        case .lapis: "Lapis"
        case .verdigris: "Verdigris"
        case .tyrian: "Tyrian"
        }
    }

    /// The deep (light-theme) value, used for wax, illuminated grounds and solid buttons in both themes.
    var deepHex: UInt32 {
        switch self {
        case .vermilion: 0x9B2A1A
        case .lapis: 0x2A4878
        case .verdigris: 0x2D6957
        case .tyrian: 0x5A3972
        }
    }

    private var brightHex: UInt32 {
        switch self {
        case .vermilion: 0xD8664C
        case .lapis: 0x8AA9DD
        case .verdigris: 0x74BBA2
        case .tyrian: 0xB493D3
        }
    }

    /// Text-safe accent: deep on Vellum, brighter on Candlelight.
    var uiColor: UIColor { .dynamic(light: deepHex, dark: brightHex) }
    var color: Color { Color(uiColor: uiColor) }

    var deepUIColor: UIColor { UIColor(hex: deepHex) }
    var deep: Color { Color(hex: deepHex) }
    var deepTop: UIColor { .mix(deepHex, 0xFFFFFF, 0.22) }
    var deepBottom: UIColor { .mix(deepHex, 0x000000, 0.38) }

    /// Base color of the sealing wax, as 0–255 RGB.
    var wax: (Float, Float, Float) {
        switch self {
        case .vermilion: (150, 24, 15)
        case .lapis: (26, 50, 112)
        case .verdigris: (22, 92, 70)
        case .tyrian: (86, 30, 98)
        }
    }
}
