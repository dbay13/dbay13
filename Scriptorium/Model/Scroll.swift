import Foundation
import SwiftData

/// One note. The first line is its title; everything beneath is the body.
///
/// Every property has a default so the model can later sync through CloudKit.
@Model
final class Scroll {
    var text: String = ""
    var tome: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isSealed: Bool = false
    /// Set when the scroll is burned. Burned scrolls rest in the Ashes for 30 days.
    var burnedAt: Date? = nil

    init(text: String = "", tome: String = "", createdAt: Date = .now) {
        self.text = text
        self.tome = tome
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension Scroll {
    static let ashesLifetime: TimeInterval = 30 * 24 * 60 * 60

    var titleLine: String {
        String(text.prefix(while: { $0 != "\n" }))
            .trimmingCharacters(in: .whitespaces)
    }

    var displayTitle: String {
        let title = ScrollText.plain(titleLine)
        return title.isEmpty ? "Untitled scroll" : title
    }

    /// The body as a single line of plain text, for the list preview.
    var preview: String {
        bodyParagraphs
            .map(ScrollText.plain)
            .filter { !$0.isEmpty && $0 != Glyph.fleuron }
            .joined(separator: " ")
    }

    var bodyParagraphs: [String] {
        text.components(separatedBy: "\n").dropFirst().map { $0 }
    }

    /// The first letter of the title, for its illuminated initial.
    var initialLetter: String {
        guard let letter = displayTitle.first(where: \.isLetter) else { return "S" }
        return String(letter).uppercased()
    }

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { word in word.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }

    /// Days left before a burned scroll turns to dust.
    var daysUntilDust: Int {
        guard let burnedAt else { return 30 }
        let remaining = burnedAt.addingTimeInterval(Self.ashesLifetime).timeIntervalSinceNow
        return max(0, Int((remaining / 86_400).rounded(.up)))
    }

    /// Sealed scrolls are only searchable by title.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if isSealed {
            return displayTitle.localizedCaseInsensitiveContains(query)
        }
        return text.localizedCaseInsensitiveContains(query) || tome.localizedCaseInsensitiveContains(query)
    }

    var markdown: String {
        var lines = ["# \(displayTitle)", ""]
        lines.append("_\(createdAt.formatted(date: .long, time: .shortened))\(tome.isEmpty ? "" : " · \(tome)")_")
        lines.append("")
        for paragraph in bodyParagraphs {
            if paragraph.hasPrefix(Glyph.box) {
                lines.append("- [ ] " + ScrollText.plain(paragraph))
            } else if paragraph.hasPrefix(Glyph.checked) {
                lines.append("- [x] " + ScrollText.plain(paragraph))
            } else if paragraph.trimmingCharacters(in: .whitespaces) == Glyph.fleuron {
                lines.append("* * *")
            } else {
                lines.append(paragraph)
            }
        }
        return lines.joined(separator: "\n")
    }
}

enum ScrollText {
    /// Strips checklist markers so a line reads as plain words.
    static func plain(_ line: String) -> String {
        var line = line.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix(Glyph.box) || line.hasPrefix(Glyph.checked) {
            line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    static func isChecklist(_ line: String) -> Bool {
        line.hasPrefix(Glyph.box) || line.hasPrefix(Glyph.checked)
    }

    /// Exports every unsealed, unburned scroll as one Markdown document.
    static func codexMarkdown(_ scrolls: [Scroll]) -> String {
        let open = scrolls.filter { !$0.isSealed && $0.burnedAt == nil }
        let sealedCount = scrolls.filter { $0.isSealed && $0.burnedAt == nil }.count
        var parts = open.map(\.markdown)
        if sealedCount > 0 {
            parts.append("_\(sealedCount) sealed scroll\(sealedCount == 1 ? " was" : "s were") left out. Break the seal and share it on its own._")
        }
        return parts.joined(separator: "\n\n---\n\n") + "\n"
    }
}
