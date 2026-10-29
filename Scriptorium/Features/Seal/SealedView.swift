import SwiftUI

/// Shown in place of a sealed scroll until Face ID (or the passcode) breaks the seal.
struct SealedView: View {
    let scroll: Scroll

    @Environment(\.scribe) private var scribe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(SealKeeper.self) private var sealKeeper

    @State private var shake: CGFloat = 0
    @State private var isAsking = false
    @State private var brokenSeal: UIImage?
    @State private var shardsFalling = false

    private let sealSize: CGFloat = 168

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    GlassBackLabel(title: "Scrolls")
                }
                .buttonStyle(GlassButtonStyle())
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)

            ScrollView {
                VStack(spacing: 0) {
                    sealedLetter
                        .padding(.top, 26)
                        .accessibilityElement()
                        .accessibilityLabel("A folded letter, closed with a wax seal and ribbon")

                    VStack(spacing: 8) {
                        SmallCaps("Sealed scroll")
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
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                Button(action: breakSeal) {
                    HStack(spacing: 12) {
                        Image(systemName: Biometrics.symbolName)
                            .font(.system(size: 20))
                        Text("BREAK THE SEAL")
                            .tracking(2.4)
                    }
                    .font(Typeface.display(15.5, .bold, relativeTo: .headline))
                    .frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(RubricButtonStyle())
                .disabled(isAsking)

                Text("Face ID, or thy passcode")
                    .font(scribe.body(15, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(ParchmentBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var sealedLetter: some View {
        ZStack(alignment: .topLeading) {
            FoldedLetter()
                .frame(width: 280, height: 184)
                .rotationEffect(.degrees(-2))
                .offset(x: 10, y: 24)

            RibbonTail()
                .fill(Palette.silkRibbon)
                .frame(width: 30, height: 150)
                .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
                .rotationEffect(.degrees(22), anchor: .top)
                .offset(x: 128, y: 112)

            RibbonTail()
                .fill(Palette.silkRibbon)
                .frame(width: 30, height: 165)
                .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
                .rotationEffect(.degrees(-16), anchor: .top)
                .offset(x: 142, y: 112)

            Group {
                if let brokenSeal {
                    ZStack {
                        shard(brokenSeal, isLeft: true)
                        shard(brokenSeal, isLeft: false)
                    }
                } else {
                    WaxSealImage(size: sealSize, seed: scroll.sealSeed)
                }
            }
            .frame(width: sealSize, height: sealSize)
            .modifier(Shake(amount: shake))
            .offset(x: 66, y: 50)
        }
        .frame(width: 300, height: 330, alignment: .topLeading)
    }

    private func shard(_ image: UIImage, isLeft: Bool) -> some View {
        let direction: CGFloat = isLeft ? -1 : 1
        return Image(uiImage: image)
            .resizable()
            .frame(width: sealSize, height: sealSize)
            .clipShape(CrackHalf(isLeft: isLeft))
            .shadow(color: Color(hex: 0x280A04, opacity: 0.35), radius: 4, y: 3)
            .rotationEffect(.degrees(shardsFalling ? Double(direction) * 28 : 0))
            .offset(x: shardsFalling ? direction * 46 : 0, y: shardsFalling ? 190 : 0)
            .opacity(shardsFalling ? 0 : 1)
    }

    private func breakSeal() {
        isAsking = true
        Task {
            let opened = await Biometrics.authenticate(reason: "Break the seal on “\(scroll.displayTitle)”.")
            isAsking = false
            guard opened else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.linear(duration: 0.4)) { shake += 1 }
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            let spec = WaxSealSpec(ink: scribe.ink, seed: scroll.sealSeed, pixels: Int((sealSize * max(2, displayScale)).rounded()))
            if !UIAccessibility.isReduceMotionEnabled, let image = WaxSealRenderer.cachedImage(spec) {
                brokenSeal = image
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                withAnimation(.easeIn(duration: 0.8)) {
                    shardsFalling = true
                }
                try? await Task.sleep(for: .milliseconds(760))
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                sealKeeper.open(scroll)
            }
        }
    }
}

/// The back of a folded letter, its top flap closed over the fold.
private struct FoldedLetter: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(hex: 0xF1E6CB), Color(hex: 0xE6D6B3)], startPoint: .top, endPoint: .bottom))
                Image(uiImage: PaperTexture.grainLight)
                    .resizable(resizingMode: .tile)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.52))
                    path.move(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w * 0.59, y: h * 0.52))
                }
                .stroke(Color(hex: 0x785523, opacity: 0.18), lineWidth: 1.2)
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: w / 2, y: h * 0.64))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(hex: 0xF1E6CB), Color(hex: 0xDCC9A2)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: 0x3C230A, opacity: 0.25), radius: 3, y: 4)
            }
            .shadow(color: Color(hex: 0x28160A, opacity: 0.28), radius: 15, y: 18)
            .shadow(color: Color(hex: 0x28160A, opacity: 0.18), radius: 3, y: 3)
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
