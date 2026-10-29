import CoreText
import SwiftUI
import UIKit

/// The three bundled typefaces: Cinzel for display, EB Garamond for writing,
/// and UnifrakturMaguntia for illuminated initials. All are SIL OFL licensed.
enum Typeface {
    enum Weight {
        case regular, medium, semibold, bold

        var uiWeight: UIFont.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
        }

        var fontWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            }
        }
    }

    static let fraktur = "UnifrakturMaguntia"

    static func cinzelName(_ weight: Weight) -> String {
        switch weight {
        case .regular, .medium: "Cinzel-Regular"
        case .semibold: "Cinzel-SemiBold"
        case .bold: "Cinzel-Bold"
        }
    }

    static func garamondName(_ weight: Weight, italic: Bool) -> String {
        if italic { return "EBGaramond-Italic" }
        switch weight {
        case .regular: return "EBGaramond-Regular"
        case .medium: return "EBGaramond-Medium"
        case .semibold, .bold: return "EBGaramond-SemiBold"
        }
    }

    // MARK: SwiftUI

    /// Small-caps style display type (Cinzel). Scales with Dynamic Type.
    static func display(_ size: CGFloat, _ weight: Weight = .semibold, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(cinzelName(weight), size: size, relativeTo: style)
    }

    /// Blackletter for illuminated initials. Fixed size: it lives inside a fixed frame.
    static func initial(_ size: CGFloat) -> Font {
        .custom(fraktur, fixedSize: size)
    }

    // MARK: UIKit

    static func uiDisplay(_ size: CGFloat, _ weight: Weight = .semibold) -> UIFont {
        UIFont(name: cinzelName(weight), size: size) ?? .systemFont(ofSize: size, weight: weight.uiWeight)
    }

    static func uiGaramond(_ size: CGFloat, _ weight: Weight = .regular, italic: Bool = false) -> UIFont {
        UIFont(name: garamondName(weight, italic: italic), size: size)
            ?? systemSerif(size, weight: weight.uiWeight, italic: italic)
    }

    static func uiInitial(_ size: CGFloat) -> UIFont {
        UIFont(name: fraktur, size: size) ?? systemSerif(size, weight: .bold, italic: false)
    }

    static func systemSerif(_ size: CGFloat, weight: UIFont.Weight, italic: Bool) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let serif = descriptor.withDesign(.serif) {
            descriptor = serif
        }
        if italic, let slanted = descriptor.withSymbolicTraits(.traitItalic) {
            descriptor = slanted
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// Registers the bundled .ttf files so they can be used by name.
enum FontRegistrar {
    static func registerBundledFonts() {
        let bundle = Bundle.main
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in Set(urls) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Navigation bar styling that matches the manuscript look.
@MainActor
enum ChromeAppearance {
    static func apply() {
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = Palette.groundUI
        bar.shadowColor = .clear
        bar.titleTextAttributes = [
            .font: Typeface.uiDisplay(17, .semibold),
            .foregroundColor: Palette.inkUI,
        ]
        bar.largeTitleTextAttributes = [
            .font: Typeface.uiDisplay(32, .semibold),
            .foregroundColor: Palette.inkUI,
        ]
        let button = UIBarButtonItemAppearance(style: .plain)
        button.normal.titleTextAttributes = [.font: Typeface.uiGaramond(18)]
        bar.buttonAppearance = button
        bar.backButtonAppearance = button

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = bar
        navigationBar.scrollEdgeAppearance = bar
        navigationBar.compactAppearance = bar
    }
}
