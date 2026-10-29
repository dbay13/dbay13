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
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

/// The manuscript palette. Light values are "Vellum", dark values are "Candlelight".
enum Palette {
    static let groundUI = UIColor.dynamic(light: 0xF2E8D0, dark: 0x17110C)
    static let surfaceUI = UIColor.dynamic(light: 0xEADBB8, dark: 0x271D14)
    static let barUI = UIColor.dynamic(light: 0xEBDFC3, dark: 0x1F1710)
    static let inkUI = UIColor.dynamic(light: 0x2B2018, dark: 0xEADDC2)
    static let inkSoftUI = UIColor.dynamic(light: 0x5E4E3D, dark: 0xC6B597)
    static let mutedUI = UIColor.dynamic(light: 0x6B5A48, dark: 0xA8957A)
    static let dimUI = UIColor.dynamic(light: 0x9A876C, dark: 0x7D6D58)
    static let ruleUI = UIColor.dynamic(light: 0xD8C9A8, dark: 0x3A2D20)
    static let ruleStrongUI = UIColor.dynamic(light: 0xC9B48A, dark: 0x5A4632)
    static let goldUI = UIColor.dynamic(light: 0xB8892B, dark: 0xD4A646)
    static let onRubricUI = UIColor(hex: 0xF7EFDC)

    static var ground: Color { Color(uiColor: groundUI) }
    static var surface: Color { Color(uiColor: surfaceUI) }
    static var bar: Color { Color(uiColor: barUI) }
    static var ink: Color { Color(uiColor: inkUI) }
    static var inkSoft: Color { Color(uiColor: inkSoftUI) }
    static var muted: Color { Color(uiColor: mutedUI) }
    static var rule: Color { Color(uiColor: ruleUI) }
    static var ruleStrong: Color { Color(uiColor: ruleStrongUI) }
    static var gold: Color { Color(uiColor: goldUI) }
    static var onRubric: Color { Color(uiColor: onRubricUI) }

    /// Candle colors used by Vigil mode.
    static let flame = Color(hex: 0xE3A944)
    static let flameCore = Color(hex: 0xF7E3B0)
    static let wax = Color(hex: 0xE6D7B8)
    static let wick = Color(hex: 0x3A2D20)
    static let holder = Color(hex: 0x5A4632)
}

/// The rubric ink: the accent used for initials, seals, checkboxes and buttons.
enum RubricInk: String, CaseIterable, Identifiable {
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

    var uiColor: UIColor {
        switch self {
        case .vermilion: .dynamic(light: 0x9E2B1B, dark: 0xD0634B)
        case .lapis: .dynamic(light: 0x2B4A7A, dark: 0x86A6DA)
        case .verdigris: .dynamic(light: 0x2F6B5A, dark: 0x6FB89F)
        case .tyrian: .dynamic(light: 0x5B3A73, dark: 0xB08FD0)
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}
