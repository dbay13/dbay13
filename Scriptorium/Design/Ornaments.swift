import SwiftUI

enum Glyph {
    static let box = "☐"
    static let checked = "☑"
    static let fleuron = "❦"
}

// MARK: - Illumination

/// Tiny white penwork dots, as on the ground of an illuminated letter.
struct PenworkDots: Shape {
    var spacing: CGFloat = 7
    var dot: CGFloat = 0.8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y = rect.minY + spacing / 2
        while y < rect.maxY {
            var x = rect.minX + spacing / 2
            while x < rect.maxX {
                path.addEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
                x += spacing
            }
            y += spacing
        }
        return path
    }
}

/// A gold blackletter capital on a deep, penwork-dotted ground in a gilt frame.
struct IlluminatedInitial: View {
    let letter: String
    var size: CGFloat = 48

    @Environment(\.scribe) private var scribe

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(uiColor: scribe.ink.deepTop), scribe.ink.deep, Color(uiColor: scribe.ink.deepBottom)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            PenworkDots(spacing: max(6, size * 0.146), dot: max(0.7, size * 0.017))
                .fill(Color(hex: 0xFFEECD, opacity: 0.24))
            Text(letter)
                .font(Typeface.initial(size * 0.71))
                .foregroundStyle(Palette.leaf)
                .shadow(color: Color(hex: 0x280C04, opacity: 0.6), radius: 0, x: 0, y: max(1, size * 0.02))
                .offset(y: size * 0.06)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.gilt, lineWidth: max(1.5, size * 0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 1)
                .strokeBorder(Palette.giltLight.opacity(0.45), lineWidth: 1)
                .padding(max(2.5, size * 0.055))
        )
        .shadow(color: Palette.shadow, radius: 1.5, y: 1)
        .accessibilityHidden(true)
    }
}

/// Hairlines that fade out, with a gold fleuron between them.
struct FleuronDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            LinearGradient(colors: [.clear, Palette.ruleStrong], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            Text(Glyph.fleuron)
                .font(.system(size: 19))
                .foregroundStyle(Palette.gold)
            LinearGradient(colors: [Palette.ruleStrong, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// A row divider that fades at both ends.
struct FadingRule: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Palette.rule, location: 0.1),
                .init(color: Palette.rule, location: 0.9),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
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
            .font(Typeface.display(11.5, .semibold, relativeTo: .caption))
            .tracking(2.3)
            .foregroundStyle(scribe.rubric)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Letter-spaced small caps for dates, hours and quiet labels.
struct SmallCaps: View {
    let text: String
    var color: Color = Palette.muted

    init(_ text: String, color: Color = Palette.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Typeface.display(11, .regular, relativeTo: .caption))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

// MARK: - Controls

/// Round, frosted buttons that float over the parchment.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(GlassChip())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlassChip: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Palette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Palette.glass, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.ruleStrong.opacity(0.7), lineWidth: 1))
            .shadow(color: Palette.shadow, radius: 1.5, y: 1)
            .contentShape(Capsule())
    }
}

/// A glass "back" pill: chevron and the name of the screen it returns to.
struct GlassBackLabel: View {
    let title: String

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(scribe.body(18, .medium))
        }
        .foregroundStyle(scribe.rubric)
        .padding(.leading, 12)
        .padding(.trailing, 16)
    }
}

/// A solid button in deep rubric with a gilt inner line and a pressed lip.
struct RubricButtonStyle: ButtonStyle {
    @Environment(\.scribe) private var scribe

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        return configuration.label
            .foregroundStyle(Palette.onRubric)
            .background(
                shape.fill(LinearGradient(
                    colors: [Color(uiColor: scribe.ink.deepTop), scribe.ink.deep, Color(uiColor: scribe.ink.deepBottom)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            )
            .overlay(shape.strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Palette.giltLight.opacity(0.55), lineWidth: 1)
                    .padding(4.5)
            )
            .background(shape.fill(Color(uiColor: scribe.ink.deepBottom)).offset(y: configuration.isPressed ? 0 : 3))
            .shadow(color: Palette.shadow, radius: 10, y: 8)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// A grouped card for settings and lists.
struct ParchmentCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, padding)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.rule, lineWidth: 1))
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

/// A candle on a 24 × 24 grid, for the Vigil button.
struct CandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.addRect(CGRect(origin: p(9, 11), size: CGSize(width: 6 * sx, height: 9 * sy)))
        path.move(to: p(12, 11))
        path.addLine(to: p(12, 9))
        path.move(to: p(12, 2.8))
        path.addCurve(to: p(13.3, 7), control1: p(13.6, 4.5), control2: p(14.1, 5.8))
        path.addCurve(to: p(10.8, 7), control1: p(12.7, 7.8), control2: p(11.4, 7.8))
        path.addCurve(to: p(12, 2.8), control1: p(10, 5.9), control2: p(10.5, 4.4))
        path.move(to: p(7, 20))
        path.addLine(to: p(17, 20))
        return path
    }
}

struct CandleIcon: View {
    var size: CGFloat = 22

    var body: some View {
        CandleShape()
            .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A candle flame.
struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.5, y: y))
        path.addCurve(
            to: CGPoint(x: x + w, y: y + h * 0.64),
            control1: CGPoint(x: x + w * 0.72, y: y + h * 0.2),
            control2: CGPoint(x: x + w, y: y + h * 0.38)
        )
        path.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h), control: CGPoint(x: x + w, y: y + h))
        path.addQuadCurve(to: CGPoint(x: x, y: y + h * 0.64), control: CGPoint(x: x, y: y + h))
        path.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y),
            control1: CGPoint(x: x, y: y + h * 0.38),
            control2: CGPoint(x: x + w * 0.28, y: y + h * 0.2)
        )
        path.closeSubpath()
        return path
    }
}

/// A swallow-tailed ribbon end.
struct RibbonTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.5))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
