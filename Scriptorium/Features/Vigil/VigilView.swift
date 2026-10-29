import SwiftUI

/// Focus mode: a dark room, one candle, and only the paragraph being written in full ink.
struct VigilView: View {
    @Bindable var scroll: Scroll

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scribe) private var scribe
    @AppStorage(SettingsKey.vigilMinutes) private var vigilMinutes = 25
    @AppStorage(SettingsKey.quillSounds) private var quillSounds = false
    @AppStorage(SettingsKey.quillHaptics) private var quillHaptics = true

    @StateObject private var controller = ManuscriptController()
    @State private var startedAt = Date.now
    @State private var startingWords = 0
    @State private var isSpent = false
    @State private var haloBreath = false

    private var duration: TimeInterval {
        TimeInterval(max(1, vigilMinutes) * 60)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.vigilGround.ignoresSafeArea()

            // Candlelight spilling over the page.
            RadialGradient(
                stops: [
                    .init(color: Color(hex: 0xFFB050, opacity: 0.26), location: 0),
                    .init(color: Color(hex: 0xFF963C, opacity: 0.12), location: 0.22),
                    .init(color: Color(hex: 0xFF8228, opacity: 0.04), location: 0.45),
                    .init(color: .clear, location: 0.65),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 310
            )
            .frame(width: 620, height: 620)
            .offset(y: -240)
            .opacity(isSpent ? 0 : (haloBreath ? 0.86 : 1))
            .scaleEffect(haloBreath ? 0.985 : 1)
            .animation(.easeInOut(duration: 2), value: isSpent)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        let remaining = max(0, duration - context.date.timeIntervalSince(startedAt))
                        CandleView(fraction: remaining / duration, caption: caption(remaining))
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Palette.vigilMuted)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .accessibilityLabel("End vigil")
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.top, 8)

                Text("A vigil at \(CanonicalHour(date: startedAt).rawValue) · \(scroll.displayTitle)".uppercased())
                    .font(Typeface.display(11, .regular, relativeTo: .caption))
                    .tracking(1.8)
                    .foregroundStyle(Palette.vigilMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 6)

                ManuscriptTextView(
                    text: Binding(
                        get: { scroll.text },
                        set: { newValue in
                            scroll.text = newValue
                            scroll.updatedAt = .now
                        }
                    ),
                    controller: controller,
                    style: .make(scribe: scribe, dark: true, focusMode: true, illuminated: false),
                    onUserEdit: { QuillFeedback.shared.stroke(haptics: quillHaptics, sounds: quillSounds) }
                )

                Text(footer)
                    .font(scribe.body(16, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Palette.vigilMuted)
                    .padding(.vertical, 12)
            }
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .onAppear {
            startingWords = scroll.wordCount
            UIApplication.shared.isIdleTimerDisabled = true
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                haloBreath = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            isSpent = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var footer: String {
        if isSpent { return "The candle is spent. Write on, or rest." }
        let words = max(0, scroll.wordCount - startingWords)
        let count = words <= 99 ? ScribeDate.spelled(words) : "\(words)"
        return words == 0 ? "No words yet this vigil" : "\(count) \(words == 1 ? "word" : "words") this vigil"
    }

    private func caption(_ remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "The candle is spent" }
        let minutes = Int((remaining / 60).rounded(.up))
        return "\(ScribeDate.spelled(minutes)) \(minutes == 1 ? "minute remains" : "minutes remain")"
    }
}

/// A beeswax candle in a brass chamberstick that burns down over the vigil.
struct CandleView: View {
    /// Wax remaining: 1 is a fresh candle, 0 is spent.
    let fraction: Double
    let caption: String

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if fraction > 0 {
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        flame(at: context.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        smoke(at: context.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
            .frame(width: 44, height: 64, alignment: .bottom)

            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0xFF9A4A), Color(hex: 0x2A1A10)], startPoint: .top, endPoint: .center))
                .frame(width: 3, height: 9)
                .padding(.top, -4)

            ZStack(alignment: .top) {
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFE6B2), Color(hex: 0xF2DFB8), Color(hex: 0xD9C49C)], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 20))
                    .frame(width: 38, height: 12)
                drip(height: 22).offset(x: -14, y: 5)
                drip(height: 15).offset(x: 12, y: 5)
            }
            .frame(width: 38, height: 12, alignment: .top)
            .zIndex(1)
            .padding(.bottom, -6)

            Rectangle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: 0xA8956F), location: 0),
                        .init(color: Color(hex: 0xD9C8A3), location: 0.14),
                        .init(color: Color(hex: 0xF5EBD5), location: 0.36),
                        .init(color: Color(hex: 0xEADBBB), location: 0.58),
                        .init(color: Color(hex: 0xC8B48E), location: 0.82),
                        .init(color: Color(hex: 0x9C8964), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 38, height: 14 + 96 * CGFloat(min(1, max(0, fraction))))
                .animation(.linear(duration: 1), value: fraction)

            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0xF4D98F), Color(hex: 0xC99A3C), Color(hex: 0x7A5A1E), Color(hex: 0x4A3410)], center: UnitPoint(x: 0.4, y: 0.3), startRadius: 0, endRadius: 56))
                    .frame(width: 104, height: 18)
                Ellipse()
                    .fill(LinearGradient(colors: [Color(hex: 0x6E4E17), Color(hex: 0xE9C979), Color(hex: 0x8A6420)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 44, height: 12)
                    .offset(y: -6)
                Ellipse()
                    .strokeBorder(Color(hex: 0xA87D2E), lineWidth: 3)
                    .frame(width: 22, height: 16)
                    .offset(x: 58, y: 1)
            }
            .shadow(color: .black.opacity(0.5), radius: 6, y: 6)
            .padding(.top, -2)

            Text(caption.uppercased())
                .font(Typeface.display(11, .regular, relativeTo: .caption))
                .tracking(1.8)
                .foregroundStyle(Palette.vigilCaption)
                .padding(.top, 14)
        }
        .accessibilityElement()
        .accessibilityLabel("Candle. \(caption)")
    }

    private func drip(height: CGFloat) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 4)
            .fill(LinearGradient(colors: [Color(hex: 0xCDBB94), Color(hex: 0xF4E8CE), Color(hex: 0xD3C19C)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 8, height: height)
    }

    private func flame(at time: TimeInterval) -> some View {
        let flicker = 1 + 0.06 * sin(time * 9) + 0.04 * sin(time * 23)
        let sway = 1.5 * sin(time * 5) + 0.8 * sin(time * 13)
        return ZStack(alignment: .bottom) {
            FlameShape()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: Color(hex: 0xFFF4C9), location: 0.26),
                        .init(color: Color(hex: 0xFFD27A), location: 0.5),
                        .init(color: Color(hex: 0xFFA94A), location: 0.74),
                        .init(color: Color(hex: 0xFF7828, opacity: 0.75), location: 1),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.74),
                    startRadius: 0,
                    endRadius: 30
                ))
                .frame(width: 20, height: 44)
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0x6E96FF, opacity: 0.55), .clear], center: .center, startRadius: 0, endRadius: 5))
                .frame(width: 8, height: 11)
                .padding(.bottom, 2)
        }
        .scaleEffect(x: 1, y: CGFloat(flicker), anchor: .bottom)
        .rotationEffect(.degrees(sway), anchor: .bottom)
        .shadow(color: Color(hex: 0xFFB450, opacity: 0.9), radius: 5)
        .shadow(color: Color(hex: 0xFF8C32, opacity: 0.5), radius: 14)
    }

    private func smoke(at time: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = (time / 3.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(Color(hex: 0xC8BEAF, opacity: 0.35))
                    .frame(width: 10, height: 10)
                    .blur(radius: 3)
                    .scaleEffect(0.6 + 2 * phase)
                    .offset(x: 8 * phase, y: -60 * phase)
                    .opacity(0.6 * (1 - phase))
            }
        }
        .frame(height: 10)
    }
}
