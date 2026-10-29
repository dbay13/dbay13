import SwiftUI

/// A scroll set as an illuminated page, rendered to an image for sharing.
struct ManuscriptPage: View {
    let scroll: Scroll
    let scribe: ScribeStyle
    /// The scroll's wax seal, rendered beforehand (an image render cannot wait for it).
    let seal: UIImage?

    private var paragraphs: [String] {
        Array(scroll.bodyParagraphs.prefix(40))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ScribeDate.long(scroll.createdAt, canonical: scribe.canonicalHours).uppercased())
                .font(Typeface.display(9, .regular))
                .tracking(1.8)
                .foregroundStyle(Color(hex: 0x6E5C49))
                .frame(maxWidth: .infinity)

            Text(scroll.displayTitle)
                .font(scribe.body(27, .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            FleuronDivider()
                .padding(.vertical, 2)

            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                paragraphView(paragraph, isFirst: index == firstProseIndex)
            }

            HStack {
                Text("WRITTEN IN SCRIPTORIUM")
                    .font(Typeface.display(8.5, .semibold))
                    .tracking(2.2)
                    .foregroundStyle(Color(hex: 0x6E5C49))
                Spacer()
                if let seal {
                    Image(uiImage: seal)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(hex: 0x280A04, opacity: 0.35), radius: 2, y: 2)
                        .padding(.vertical, -12)
                }
            }
            .padding(.top, 16)
        }
        .foregroundStyle(Color(hex: 0x2A1F17))
        .padding(.horizontal, 38)
        .padding(.top, 50)
        .padding(.bottom, 40)
        .frame(width: 390)
        .background(ParchmentBackground())
        .overlay(
            ZStack {
                Rectangle().strokeBorder(Palette.gilt, lineWidth: 1).padding(13)
                Rectangle().strokeBorder(Palette.gilt.opacity(0.4), lineWidth: 1).padding(18)
            }
        )
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
                Image(systemName: checked ? "checkmark.square" : "square")
                    .foregroundStyle(scribe.ink.deep)
                Text(ScrollText.plain(trimmed))
                    .strikethrough(checked, color: scribe.ink.deep.opacity(0.6))
                    .foregroundStyle(checked ? Color(hex: 0x6E5C49) : Color(hex: 0x2A1F17))
            }
            .font(scribe.body(16.5))
        } else if isFirst, scribe.illuminated, let first = trimmed.first, first.isLetter {
            HStack(alignment: .top, spacing: 11) {
                IlluminatedInitial(letter: String(first).uppercased(), size: 52)
                Text(String(trimmed.dropFirst()))
                    .font(scribe.body(16.5))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if trimmed.isEmpty {
            Color.clear.frame(height: 2)
        } else {
            Text(trimmed)
                .font(scribe.body(16.5))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
