import SwiftUI

/// Focus mode: a dark page, one candle, and only the paragraph being written in full ink.
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

    private var duration: TimeInterval {
        TimeInterval(max(1, vigilMinutes) * 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(Palette.muted)
                .accessibilityLabel("End vigil")

                Spacer()

                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let remaining = max(0, duration - context.date.timeIntervalSince(startedAt))
                    CandleView(
                        fraction: remaining / duration,
                        caption: caption(remaining)
                    )
                }

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Text("A VIGIL AT \(CanonicalHour(date: startedAt).rawValue.uppercased())")
                .font(Typeface.display(12, .regular, relativeTo: .caption))
                .tracking(2.2)
                .foregroundStyle(Palette.muted)
                .padding(.top, 18)
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

            Text(isSpent ? "The candle is spent. Write on, or rest." : "\(max(0, scroll.wordCount - startingWords)) words this vigil")
                .font(scribe.body(16, italic: true, relativeTo: .footnote))
                .foregroundStyle(Palette.muted)
                .padding(.vertical, 12)
        }
        .background(Palette.ground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .onAppear {
            startingWords = scroll.wordCount
            UIApplication.shared.isIdleTimerDisabled = true
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

    private func caption(_ remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "SPENT" }
        let minutes = Int((remaining / 60).rounded(.up))
        return "\(minutes) MIN LEFT"
    }
}

struct CandleView: View {
    /// Wax remaining, 1 = a fresh candle.
    let fraction: Double
    let caption: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if fraction > 0 {
                    Circle()
                        .fill(Palette.flame.opacity(0.14))
                        .frame(width: 46, height: 46)
                        .blur(radius: 6)
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let flicker = 1 + 0.07 * sin(t * 9) + 0.04 * sin(t * 23)
                        let sway = 0.6 * sin(t * 5)
                        ZStack(alignment: .bottom) {
                            FlameShape()
                                .fill(Palette.flame)
                                .frame(width: 16, height: 26)
                            FlameShape()
                                .fill(Palette.flameCore)
                                .frame(width: 8, height: 13)
                                .padding(.bottom, 1)
                        }
                        .scaleEffect(x: 1, y: CGFloat(flicker), anchor: .bottom)
                        .offset(x: CGFloat(sway))
                        .shadow(color: Palette.flame.opacity(0.7), radius: 10)
                    }
                    .frame(width: 20, height: 28, alignment: .bottom)
                }
            }
            .frame(height: 34, alignment: .bottom)

            Rectangle().fill(Palette.wick).frame(width: 2, height: 5)
            UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                .fill(Palette.wax)
                .frame(width: 20, height: 8 + 50 * CGFloat(min(1, max(0, fraction))))
                .animation(.linear(duration: 1), value: fraction)
            Capsule().fill(Palette.holder).frame(width: 40, height: 6)

            Text(caption)
                .font(Typeface.display(11, .regular, relativeTo: .caption))
                .tracking(1.6)
                .foregroundStyle(Palette.muted)
                .padding(.top, 10)
        }
        .frame(height: 130, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Candle, \(caption.lowercased())")
    }
}
