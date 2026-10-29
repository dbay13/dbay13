import SwiftUI

/// A scroll set as an illuminated page, rendered to an image for sharing.
struct ManuscriptPage: View {
    let scroll: Scroll
    let scribe: ScribeStyle

    private var paragraphs: [String] {
        Array(scroll.bodyParagraphs.prefix(40))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ScribeDate.long(scroll.createdAt, canonical: scribe.canonicalHours).uppercased())
                .font(Typeface.display(9, .regular))
                .tracking(1.6)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)

            Text(scroll.displayTitle)
                .font(scribe.body(26, .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            FleuronDivider()
                .padding(.vertical, 2)

            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                paragraphView(paragraph, isFirst: index == firstProseIndex)
            }

            Text("WRITTEN IN SCRIPTORIUM")
                .font(Typeface.display(8, .semibold))
                .tracking(2)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 40)
        .padding(.vertical, 44)
        .frame(width: 390)
        .background(Palette.ground)
        .overlay(ManuscriptFrame())
        .environment(\.scribe, scribe)
    }

    private var firstProseIndex: Int? {
        paragraphs.firstIndex { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !ScrollText.isChecklist(trimmed) && trimmed != Glyph.fleuron
        }
    }

    @ViewBuilder
    private func paragraphView(_ paragraph: String, isFirst: Bool) -> some View {
        let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
        if trimmed == Glyph.fleuron {
            FleuronDivider()
        } else if ScrollText.isChecklist(trimmed) {
            let checked = trimmed.hasPrefix(Glyph.checked)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(scribe.rubric)
                Text(ScrollText.plain(trimmed))
                    .strikethrough(checked)
                    .foregroundStyle(checked ? Palette.muted : Palette.ink)
            }
            .font(scribe.body(16))
        } else if isFirst, scribe.illuminated, let first = trimmed.first, first.isLetter {
            HStack(alignment: .top, spacing: 10) {
                IlluminatedInitial(letter: String(first).uppercased(), size: 50)
                Text(String(trimmed.dropFirst()))
                    .font(scribe.body(16))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if trimmed.isEmpty {
            Color.clear.frame(height: 2)
        } else {
            Text(trimmed)
                .font(scribe.body(16))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
