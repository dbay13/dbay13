import SwiftUI

enum Glyph {
    static let box = "☐"
    static let checked = "☑"
    static let fleuron = "❦"
}

/// A blackletter capital in a gilded frame, as at the head of a manuscript page.
struct IlluminatedInitial: View {
    let letter: String
    var size: CGFloat = 44

    @Environment(\.scribe) private var scribe

    var body: some View {
        Text(letter)
            .font(Typeface.initial(size * 0.72))
            .foregroundStyle(scribe.rubric)
            .offset(y: size * 0.04)
            .frame(width: size, height: size)
            .background(Palette.surface)
            .overlay(Rectangle().strokeBorder(Palette.gold, lineWidth: max(1.5, size * 0.03)))
            .accessibilityHidden(true)
    }
}

/// Two hairlines with a fleuron between them.
struct FleuronDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Palette.ruleStrong).frame(height: 1)
            Text(Glyph.fleuron)
                .font(.system(size: 18))
                .foregroundStyle(Palette.gold)
            Rectangle().fill(Palette.ruleStrong).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Small caps section label in the rubric ink.
struct RubricLabel: View {
    let text: String

    @Environment(\.scribe) private var scribe

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Typeface.display(12, .semibold, relativeTo: .caption))
            .tracking(1.9)
            .foregroundStyle(scribe.rubric)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A double gilt rule around a page.
struct ManuscriptFrame: View {
    var body: some View {
        ZStack {
            Rectangle().strokeBorder(Palette.gold, lineWidth: 1).padding(14)
            Rectangle().strokeBorder(Palette.rule, lineWidth: 1).padding(19)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Wax seal

/// A round blob of wax with irregular drips at the edge.
struct WaxSealShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let core = radius * 0.84
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2))

        let drips: [(degrees: Double, size: CGFloat)] = [
            (0, 0.13), (44, 0.12), (91, 0.11), (133, 0.14),
            (181, 0.12), (224, 0.13), (269, 0.11), (314, 0.12),
        ]
        for drip in drips {
            let angle = drip.degrees * .pi / 180
            let dripRadius = radius * drip.size
            let distance = radius - dripRadius
            let dripCenter = CGPoint(
                x: center.x + CGFloat(cos(angle)) * distance,
                y: center.y + CGFloat(sin(angle)) * distance
            )
            path.addEllipse(in: CGRect(
                x: dripCenter.x - dripRadius,
                y: dripCenter.y - dripRadius,
                width: dripRadius * 2,
                height: dripRadius * 2
            ))
        }
        return path
    }
}

/// A pressed wax seal in the rubric ink, with whatever mark is stamped into it.
struct WaxSeal<Mark: View>: View {
    var size: CGFloat
    @ViewBuilder var mark: Mark

    @Environment(\.scribe) private var scribe

    var body: some View {
        ZStack {
            WaxSealShape().fill(scribe.rubric)
            Circle()
                .strokeBorder(Color.black.opacity(0.26), lineWidth: max(1.5, size * 0.03))
                .frame(width: size * 0.64, height: size * 0.64)
            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: max(1, size * 0.01))
                .frame(width: size * 0.7, height: size * 0.7)
            mark
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.22), radius: size * 0.05, y: size * 0.03)
    }
}

/// The embossed blackletter "S" used on large seals.
struct SealMonogram: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Text("S")
                .font(Typeface.initial(size * 0.48))
                .foregroundStyle(Color.black.opacity(0.32))
                .offset(x: 1.5, y: 1.5)
            Text("S")
                .font(Typeface.initial(size * 0.48))
                .foregroundStyle(Color(hex: 0xFFE1C8).opacity(0.55))
        }
        .offset(y: size * 0.03)
        .accessibilityHidden(true)
    }
}

// MARK: - Drawn icons

/// A feather quill, drawn on a 24 × 24 grid.
struct QuillShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: p(20, 3))
        path.addCurve(to: p(6, 16), control1: p(13, 4), control2: p(8, 9))
        path.addLine(to: p(4, 21))
        path.move(to: p(20, 3))
        path.addCurve(to: p(8, 15), control1: p(19, 10), control2: p(15, 14))
        path.move(to: p(9, 14))
        path.addCurve(to: p(18, 6), control1: p(12, 11), control2: p(15, 8))
        return path
    }
}

struct QuillIcon: View {
    var size: CGFloat = 24
    var lineWidth: CGFloat = 1.6

    var body: some View {
        QuillShape()
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A candle flame.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.5, y: y))
        path.addCurve(
            to: CGPoint(x: x + w, y: y + h * 0.62),
            control1: CGPoint(x: x + w * 0.7, y: y + h * 0.2),
            control2: CGPoint(x: x + w, y: y + h * 0.36)
        )
        path.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h), control: CGPoint(x: x + w, y: y + h))
        path.addQuadCurve(to: CGPoint(x: x, y: y + h * 0.62), control: CGPoint(x: x, y: y + h))
        path.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y),
            control1: CGPoint(x: x, y: y + h * 0.36),
            control2: CGPoint(x: x + w * 0.3, y: y + h * 0.2)
        )
        path.closeSubpath()
        return path
    }
}
