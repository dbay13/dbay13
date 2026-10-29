import SwiftUI

struct WelcomeView: View {
    let onBegin: () -> Void

    @Environment(\.scribe) private var scribe
    @State private var appeared = false

    var body: some View {
        ZStack {
            ParchmentBackground()
            ZStack {
                RoundedRectangle(cornerRadius: 40).strokeBorder(Palette.gold, lineWidth: 1).padding(14)
                RoundedRectangle(cornerRadius: 35).strokeBorder(Palette.rule, lineWidth: 1).padding(19)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 24) {
                    IlluminatedInitial(letter: "S", size: 132)
                        .padding(5)
                        .background(Palette.ground)
                        .overlay(Rectangle().strokeBorder(Palette.gilt, lineWidth: 1))
                        .shadow(color: Palette.shadow, radius: 12, y: 10)
                        .rise(appeared, delay: 0)
                        .padding(.top, 58)

                    VStack(spacing: 10) {
                        Text("SCRIPTORIUM")
                            .font(Typeface.display(30, .bold, relativeTo: .largeTitle))
                            .tracking(6)
                            .foregroundStyle(Palette.ink)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .rise(appeared, delay: 0.12)
                        Text("A quiet chamber for thy thoughts.")
                            .font(scribe.body(20, italic: true, relativeTo: .title3))
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                            .rise(appeared, delay: 0.2)
                    }

                    FleuronDivider()
                        .rise(appeared, delay: 0.28)

                    VStack(alignment: .leading, spacing: 16) {
                        WelcomePoint(title: "One page. No clutter.", detail: "Open and write. Every scroll keeps itself.") {
                            QuillIcon(size: 22)
                                .foregroundStyle(scribe.rubric)
                        }
                        .rise(appeared, delay: 0.36)
                        WelcomePoint(title: "Seal what is private.", detail: "Press wax on any scroll. Face ID breaks it.") {
                            WaxSealImage(size: 40, seed: "welcome")
                        }
                        .rise(appeared, delay: 0.44)
                        WelcomePoint(title: "Write by candlelight.", detail: "A vigil hides all but thy words.") {
                            CandleIcon(size: 22)
                                .foregroundStyle(scribe.rubric)
                        }
                        .rise(appeared, delay: 0.52)
                    }
                }
                .padding(.horizontal, 38)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: onBegin) {
                        Text("TAKE UP THE QUILL")
                            .font(Typeface.display(15.5, .bold, relativeTo: .headline))
                            .tracking(2.4)
                            .frame(maxWidth: .infinity, minHeight: 58)
                    }
                    .buttonStyle(RubricButtonStyle())

                    Text("No account. Thy scrolls stay on this iPhone.")
                        .font(scribe.body(15, italic: true, relativeTo: .footnote))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 38)
                .padding(.bottom, 28)
                .padding(.top, 10)
                .rise(appeared, delay: 0.62)
            }
        }
        .onAppear { appeared = true }
    }
}

private struct WelcomePoint<Icon: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let icon: Icon

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(spacing: 14) {
            icon
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.card))
                .overlay(Circle().strokeBorder(Palette.gold, lineWidth: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(scribe.body(19, .semibold, relativeTo: .headline))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(scribe.body(16.5, relativeTo: .subheadline))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Rise: ViewModifier {
    let visible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .animation(.easeOut(duration: 0.7).delay(delay), value: visible)
    }
}

private extension View {
    func rise(_ visible: Bool, delay: Double) -> some View {
        modifier(Rise(visible: UIAccessibility.isReduceMotionEnabled || visible, delay: delay))
    }
}
