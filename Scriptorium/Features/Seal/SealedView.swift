import SwiftUI

/// Shown in place of a sealed scroll until Face ID (or the passcode) breaks the seal.
struct SealedView: View {
    let scroll: Scroll

    @Environment(\.scribe) private var scribe
    @Environment(SealKeeper.self) private var sealKeeper
    @State private var shake: CGFloat = 0
    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                FoldedLetter()
                    .frame(width: 290, height: 190)
                WaxSeal(size: 176) {
                    SealMonogram(size: 176)
                }
                .offset(y: 46)
                .modifier(Shake(amount: shake))
            }
            .frame(height: 300)
            .padding(.top, 36)
            .accessibilityElement()
            .accessibilityLabel("A folded letter closed with a wax seal")

            VStack(spacing: 8) {
                Text("SEALED SCROLL")
                    .font(Typeface.display(12, .regular, relativeTo: .caption))
                    .tracking(2.2)
                    .foregroundStyle(Palette.muted)
                Text(scroll.displayTitle)
                    .font(scribe.body(32, .semibold, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                Text("This scroll bears thy seal. Only thy face may break it.")
                    .font(scribe.body(18, italic: true))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
            .padding(.top, 8)

            Spacer(minLength: 24)

            Button(action: breakSeal) {
                HStack(spacing: 10) {
                    Image(systemName: Biometrics.symbolName)
                    Text("BREAK THE SEAL")
                        .tracking(1.9)
                }
                .font(Typeface.display(16, .bold, relativeTo: .headline))
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(RubricButtonStyle())
            .disabled(isAsking)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(Palette.ground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func breakSeal() {
        isAsking = true
        Task {
            let opened = await Biometrics.authenticate(reason: "Break the seal on “\(scroll.displayTitle)”.")
            isAsking = false
            if opened {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.3)) {
                    sealKeeper.open(scroll)
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.linear(duration: 0.4)) {
                    shake += 1
                }
            }
        }
    }
}

/// The back of a folded letter.
private struct FoldedLetter: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Rectangle()
                    .fill(Palette.surface)
                    .overlay(Rectangle().strokeBorder(Palette.ruleStrong, lineWidth: 1.5))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.5))
                    path.move(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.5))
                }
                .stroke(Palette.rule, lineWidth: 1.2)
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: w / 2, y: h * 0.59))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.closeSubpath()
                }
                .fill(Palette.ground.opacity(0.35))
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: w / 2, y: h * 0.59))
                    path.addLine(to: CGPoint(x: w, y: 0))
                }
                .stroke(Palette.ruleStrong, lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Side-to-side shake for a refused seal.
private struct Shake: GeometryEffect {
    var amount: CGFloat

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 4), y: 0))
    }
}
