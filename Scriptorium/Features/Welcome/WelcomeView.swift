import SwiftUI

struct WelcomeView: View {
    let onBegin: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()
            ManuscriptFrame().ignoresSafeArea(edges: .bottom)

            ScrollView {
                VStack(spacing: 28) {
                    IlluminatedInitial(letter: "S", size: 132)
                        .padding(5)
                        .overlay(Rectangle().strokeBorder(Palette.gold, lineWidth: 1))
                        .padding(.top, 56)

                    VStack(spacing: 10) {
                        Text("SCRIPTORIUM")
                            .font(Typeface.display(32, .bold, relativeTo: .largeTitle))
                            .tracking(5)
                            .foregroundStyle(Palette.ink)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("A quiet chamber for thy thoughts.")
                            .font(scribe.body(20, italic: true, relativeTo: .title3))
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    FleuronDivider()

                    VStack(alignment: .leading, spacing: 18) {
                        WelcomePoint(title: "One page. No clutter.", detail: "Open and write. Every scroll keeps itself.") {
                            QuillIcon(size: 24)
                        }
                        WelcomePoint(title: "Seal what is private.", detail: "Press a wax seal on any scroll. Face ID breaks it.") {
                            Image(systemName: "lock")
                        }
                        WelcomePoint(title: "Write by candlelight.", detail: "Vigil mode hides everything but thy words.") {
                            Image(systemName: "flame")
                        }
                    }
                }
                .padding(.horizontal, 36)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: onBegin) {
                        Text("TAKE UP THE QUILL")
                            .font(Typeface.display(16, .bold, relativeTo: .headline))
                            .tracking(1.9)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(RubricButtonStyle())

                    Text("No account. Thy scrolls stay on this iPhone.")
                        .font(scribe.body(15, relativeTo: .footnote))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 24)
                .padding(.top, 8)
                .background(Palette.ground)
            }
        }
    }
}

private struct WelcomePoint<Icon: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let icon: Icon

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon
                .font(.system(size: 20))
                .foregroundStyle(scribe.rubric)
                .frame(width: 26)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(scribe.body(19, .semibold, relativeTo: .headline))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(scribe.body(17, relativeTo: .subheadline))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A solid button in the rubric ink with a pressed-wax edge.
struct RubricButtonStyle: ButtonStyle {
    @Environment(\.scribe) private var scribe

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.onRubric)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(scribe.rubric)
                    .shadow(color: .black.opacity(0.35), radius: 0, y: configuration.isPressed ? 0 : 3)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
