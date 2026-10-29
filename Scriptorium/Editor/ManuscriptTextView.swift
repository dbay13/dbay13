import SwiftUI
import UIKit

/// Everything the text view needs to draw a page. Colors are already resolved
/// for light or dark, so Vigil mode can be dark inside a light app.
struct ManuscriptStyle: Equatable {
    var bodyFont: UIFont
    var titleFont: UIFont
    var initialFont: UIFont
    var ink: UIColor
    var dimInk: UIColor
    var mutedInk: UIColor
    var rubric: UIColor
    var gold: UIColor
    var surface: UIColor
    var illuminated: Bool
    var focusMode: Bool
    var dark: Bool

    static func make(scribe: ScribeStyle, dark: Bool, focusMode: Bool = false, illuminated: Bool? = nil) -> ManuscriptStyle {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        func resolve(_ color: UIColor) -> UIColor { color.resolvedColor(with: traits) }
        let bodySize: CGFloat = focusMode ? 20 : 19
        return ManuscriptStyle(
            bodyFont: UIFontMetrics(forTextStyle: .body).scaledFont(for: scribe.uiBody(bodySize)),
            titleFont: UIFontMetrics(forTextStyle: .title1).scaledFont(for: scribe.uiBody(30, .semibold)),
            initialFont: Typeface.uiInitial(48),
            ink: resolve(Palette.inkUI),
            dimInk: resolve(Palette.dimUI),
            mutedInk: resolve(Palette.mutedUI),
            rubric: resolve(scribe.ink.uiColor),
            gold: resolve(Palette.goldUI),
            surface: resolve(Palette.surfaceUI),
            illuminated: illuminated ?? scribe.illuminated,
            focusMode: focusMode,
            dark: dark
        )
    }
}

/// Lets toolbar buttons reach the text view.
@MainActor
final class ManuscriptController: ObservableObject {
    @Published var isEditing = false
    weak var textView: ManuscriptUITextView?

    func toggleChecklist() { textView?.toggleChecklistOnCurrentLine() }
    func insertFlourish() { textView?.insertFlourish() }
    func beginEditing() { textView?.becomeFirstResponder() }
    func endEditing() { textView?.resignFirstResponder() }
}

struct ManuscriptTextView: UIViewRepresentable {
    @Binding var text: String
    let controller: ManuscriptController
    let style: ManuscriptStyle
    var onUserEdit: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ManuscriptUITextView {
        let textView = ManuscriptUITextView()
        textView.delegate = context.coordinator
        textView.text = text
        textView.manuscriptStyle = style
        controller.textView = textView
        return textView
    }

    func updateUIView(_ textView: ManuscriptUITextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = textView
        if textView.text != text {
            textView.replaceAllText(text)
        }
        if textView.manuscriptStyle != style {
            textView.manuscriptStyle = style
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ManuscriptTextView

        init(parent: ManuscriptTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let textView = textView as? ManuscriptUITextView else { return }
            if textView.markedTextRange == nil {
                textView.applyStyle()
            }
            if parent.text != textView.text {
                parent.text = textView.text
                parent.onUserEdit()
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let textView = textView as? ManuscriptUITextView,
                  textView.manuscriptStyle?.focusMode == true,
                  textView.markedTextRange == nil else { return }
            textView.applyStyle()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n", let textView = textView as? ManuscriptUITextView else { return true }
            return textView.handleReturn(in: range)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.controller.isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.controller.isEditing = false
        }
    }
}

/// A TextKit 1 text view that sets the first line as a centered title,
/// paints an illuminated initial at the start of the first paragraph,
/// draws a fleuron under the title, and makes ☐ / ☑ tappable.
final class ManuscriptUITextView: UITextView {
    private let storage = NSTextStorage()
    private let initialView = IlluminatedCapView()
    private let flourishView = FlourishRuleView()
    private let gestureGate = GestureGate()

    private var initialIndex: Int?
    private var initialLetter = ""
    private var exclusionRect = CGRect.null
    private var bodyLineSpacing: CGFloat = 6

    private static let titleGap: CGFloat = 46

    var manuscriptStyle: ManuscriptStyle? {
        didSet {
            applyStyle()
        }
    }

    init() {
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)

        backgroundColor = .clear
        alwaysBounceVertical = true
        keyboardDismissMode = .interactive
        autocapitalizationType = .sentences
        smartQuotesType = .yes
        textContainerInset = UIEdgeInsets(top: 10, left: 24, bottom: 140, right: 24)

        initialView.isHidden = true
        flourishView.isHidden = true
        addSubview(flourishView)
        addSubview(initialView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        gestureGate.shouldBegin = { [weak self] recognizer in
            guard let self else { return false }
            return self.checkboxIndex(at: recognizer.location(in: self)) != nil
        }
        tap.delegate = gestureGate
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Text

    func replaceAllText(_ newText: String) {
        let selection = selectedRange
        text = newText
        let length = (newText as NSString).length
        selectedRange = NSRange(location: min(selection.location, length), length: 0)
        applyStyle()
    }

    /// Edits through UITextInput so undo keeps working.
    private func replace(_ range: NSRange, with string: String) {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else { return }
        replace(textRange, withText: string)
    }

    private func notifyChange() {
        delegate?.textViewDidChange?(self)
    }

    // MARK: Styling

    func applyStyle() {
        guard let style = manuscriptStyle else { return }
        tintColor = style.rubric
        keyboardAppearance = style.dark ? .dark : .default
        indicatorStyle = style.dark ? .white : .black

        let string = storage.string as NSString
        let full = NSRange(location: 0, length: string.length)
        let caret = min(selectedRange.location, string.length)
        let activeParagraph = string.paragraphRange(for: NSRange(location: caret, length: 0))

        bodyLineSpacing = round(style.bodyFont.pointSize * 0.32)
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = bodyLineSpacing
        bodyParagraph.paragraphSpacing = round(style.bodyFont.pointSize * 0.5)

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        titleParagraph.lineSpacing = 2
        titleParagraph.paragraphSpacing = Self.titleGap

        let fleuronParagraph = NSMutableParagraphStyle()
        fleuronParagraph.alignment = .center
        fleuronParagraph.paragraphSpacing = bodyParagraph.paragraphSpacing

        let boxFont = UIFont.systemFont(ofSize: round(style.bodyFont.pointSize * 1.05))
        let boxWidth = ("\(Glyph.box) " as NSString).size(withAttributes: [.font: boxFont]).width
        let checklistParagraph = NSMutableParagraphStyle()
        checklistParagraph.lineSpacing = bodyLineSpacing
        checklistParagraph.paragraphSpacing = round(style.bodyFont.pointSize * 0.25)
        checklistParagraph.headIndent = ceil(boxWidth)

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: style.bodyFont,
            .foregroundColor: style.ink,
            .paragraphStyle: bodyParagraph,
        ]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: style.titleFont,
            .foregroundColor: style.ink,
            .paragraphStyle: titleParagraph,
        ]

        var newInitialIndex: Int?
        var newInitialLetter = ""
        var paragraphNumber = 0

        storage.beginEditing()
        storage.setAttributes(bodyAttributes, range: full)
        string.enumerateSubstrings(in: full, options: [.byParagraphs, .substringNotRequired]) { _, range, enclosing, _ in
            defer { paragraphNumber += 1 }
            let isActive = enclosing.location == activeParagraph.location
            let dimmed = style.focusMode && !isActive
            let ink = dimmed ? style.dimInk : style.ink

            if paragraphNumber == 0 {
                self.storage.addAttributes(titleAttributes, range: enclosing)
                self.storage.addAttribute(.foregroundColor, value: ink, range: enclosing)
                return
            }

            self.storage.addAttribute(.foregroundColor, value: ink, range: enclosing)
            let paragraph = string.substring(with: range)

            if ScrollText.isChecklist(paragraph) {
                self.storage.addAttribute(.paragraphStyle, value: checklistParagraph, range: enclosing)
                self.storage.addAttributes(
                    [.font: boxFont, .foregroundColor: dimmed ? style.dimInk : style.rubric],
                    range: NSRange(location: range.location, length: 1)
                )
                if paragraph.hasPrefix(Glyph.checked), range.length > 2 {
                    let words = NSRange(location: range.location + 2, length: range.length - 2)
                    self.storage.addAttributes([
                        .foregroundColor: dimmed ? style.dimInk : style.mutedInk,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: style.mutedInk,
                    ], range: words)
                }
            } else if paragraph.trimmingCharacters(in: .whitespaces) == Glyph.fleuron {
                self.storage.addAttributes([.paragraphStyle: fleuronParagraph, .foregroundColor: style.gold], range: enclosing)
            } else if paragraphNumber == 1, style.illuminated, range.length > 1,
                      let first = paragraph.first, first.isLetter {
                // Hide the real letter; the illuminated initial is drawn in its place.
                let letterLength = String(first).utf16.count
                newInitialIndex = range.location
                newInitialLetter = String(first).uppercased()
                self.storage.addAttributes(
                    [.font: style.bodyFont.withSize(1), .foregroundColor: UIColor.clear],
                    range: NSRange(location: range.location, length: letterLength)
                )
            }
        }
        storage.endEditing()

        initialIndex = newInitialIndex
        initialLetter = newInitialLetter
        initialView.configure(letter: newInitialLetter, font: style.initialFont, ink: style.rubric, gold: style.gold, surface: style.surface)
        flourishView.configure(fleuron: style.gold, rule: style.mutedInk.withAlphaComponent(0.4))
        typingAttributes = activeParagraph.location == 0 ? titleAttributes : bodyAttributes
        setNeedsLayout()
    }

    // MARK: Ornaments

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutOrnaments()
    }

    private func layoutOrnaments() {
        guard let style = manuscriptStyle, textContainer.size.width > 0 else { return }
        let string = storage.string as NSString
        let origin = CGPoint(x: textContainerInset.left, y: textContainerInset.top)
        let padding = textContainer.lineFragmentPadding
        let width = textContainer.size.width - padding * 2

        // Fleuron under the title, once there is a second line.
        let firstBreak = string.range(of: "\n")
        if firstBreak.location != NSNotFound, firstBreak.location > 0 {
            let titleGlyphs = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: 0, length: firstBreak.location),
                actualCharacterRange: nil
            )
            let lastGlyph = max(0, NSMaxRange(titleGlyphs) - 1)
            let used = layoutManager.lineFragmentUsedRect(forGlyphAt: lastGlyph, effectiveRange: nil)
            flourishView.frame = CGRect(x: origin.x + padding, y: origin.y + used.maxY + 12, width: width, height: 22)
            flourishView.isHidden = false
        } else {
            flourishView.isHidden = true
        }

        // Illuminated initial: a box two lines tall, with text flowing around it.
        if let index = initialIndex, index < string.length {
            let side = ceil(style.bodyFont.lineHeight * 2 + bodyLineSpacing) - 2
            let glyph = layoutManager.glyphIndexForCharacter(at: index)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let exclusion = CGRect(x: 0, y: line.minY, width: padding + side + 10, height: side + 4)
            if abs(exclusion.minY - exclusionRect.minY) > 0.5 || abs(exclusion.width - exclusionRect.width) > 0.5 || exclusionRect.isNull {
                exclusionRect = exclusion
                textContainer.exclusionPaths = [UIBezierPath(rect: exclusion)]
            }
            initialView.frame = CGRect(x: origin.x + padding, y: origin.y + line.minY + 3, width: side, height: side)
            initialView.isHidden = false
        } else {
            if !textContainer.exclusionPaths.isEmpty {
                textContainer.exclusionPaths = []
            }
            exclusionRect = .null
            initialView.isHidden = true
        }
    }

    // MARK: Checklists

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let index = checkboxIndex(at: recognizer.location(in: self)) else { return }
        let string = storage.string as NSString
        let isChecked = string.character(at: index) == 0x2611
        replace(NSRange(location: index, length: 1), with: isChecked ? Glyph.box : Glyph.checked)
        notifyChange()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    fileprivate func checkboxIndex(at point: CGPoint) -> Int? {
        let string = storage.string as NSString
        guard string.length > 0 else { return nil }
        let containerPoint = CGPoint(x: point.x - textContainerInset.left, y: point.y - textContainerInset.top)
        var fraction: CGFloat = 0
        let hit = layoutManager.characterIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        for candidate in [hit, hit - 1, hit + 1] where candidate >= 0 && candidate < string.length {
            let character = string.character(at: candidate)
            guard character == 0x2610 || character == 0x2611 else { continue }
            let paragraph = string.paragraphRange(for: NSRange(location: candidate, length: 0))
            guard paragraph.location == candidate, paragraph.location > 0 else { continue }
            let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: candidate, length: 1), actualCharacterRange: nil)
            let box = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer).insetBy(dx: -12, dy: -8)
            if box.contains(containerPoint) {
                return candidate
            }
        }
        return nil
    }

    func toggleChecklistOnCurrentLine() {
        let string = storage.string as NSString
        let caret = min(selectedRange.location, string.length)
        let paragraph = string.paragraphRange(for: NSRange(location: caret, length: 0))
        if paragraph.location == 0 {
            // On the title line: start a checklist on a new line instead.
            let end = NSMaxRange(paragraph) - (string.substring(with: paragraph).hasSuffix("\n") ? 1 : 0)
            replace(NSRange(location: end, length: 0), with: "\n\(Glyph.box) ")
        } else {
            let line = string.substring(with: paragraph)
            if ScrollText.isChecklist(line) {
                let markerLength = line.hasPrefix(Glyph.box + " ") || line.hasPrefix(Glyph.checked + " ") ? 2 : 1
                replace(NSRange(location: paragraph.location, length: markerLength), with: "")
            } else {
                replace(NSRange(location: paragraph.location, length: 0), with: "\(Glyph.box) ")
            }
        }
        notifyChange()
    }

    /// Return on a checklist line starts the next item; return on an empty item ends the list.
    func handleReturn(in range: NSRange) -> Bool {
        let string = storage.string as NSString
        guard range.location <= string.length else { return true }
        let paragraph = string.paragraphRange(for: NSRange(location: range.location, length: 0))
        guard paragraph.location > 0 else { return true }
        let line = string.substring(with: paragraph).trimmingCharacters(in: .newlines)
        guard ScrollText.isChecklist(line) else { return true }

        if ScrollText.plain(line).isEmpty {
            replace(NSRange(location: paragraph.location, length: (line as NSString).length), with: "")
        } else {
            replace(range, with: "\n\(Glyph.box) ")
        }
        notifyChange()
        return false
    }

    func insertFlourish() {
        let string = storage.string as NSString
        let caret = min(selectedRange.location, string.length)
        let paragraph = string.paragraphRange(for: NSRange(location: caret, length: 0))
        let line = string.substring(with: paragraph)
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, paragraph.location > 0 {
            replace(NSRange(location: paragraph.location, length: (line.trimmingCharacters(in: .newlines) as NSString).length), with: "\(Glyph.fleuron)\n")
        } else {
            let end = NSMaxRange(paragraph) - (line.hasSuffix("\n") ? 1 : 0)
            replace(NSRange(location: end, length: 0), with: "\n\(Glyph.fleuron)\n")
        }
        notifyChange()
    }
}

/// Lets the checkbox tap begin only on a checkbox, so ordinary taps still place the caret.
private final class GestureGate: NSObject, UIGestureRecognizerDelegate {
    var shouldBegin: (UIGestureRecognizer) -> Bool = { _ in false }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        shouldBegin(gestureRecognizer)
    }
}

/// The illuminated initial drawn over the hidden first letter.
final class IlluminatedCapView: UIView {
    private let label = UILabel()
    private var baseFont = UIFont.systemFont(ofSize: 40)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.borderWidth = 1.5
        label.textAlignment = .center
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(letter: String, font: UIFont, ink: UIColor, gold: UIColor, surface: UIColor) {
        label.text = letter
        baseFont = font
        label.textColor = ink
        layer.borderColor = gold.cgColor
        backgroundColor = surface
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.font = baseFont.withSize(bounds.height * 0.8)
        label.frame = bounds.offsetBy(dx: 0, dy: bounds.height * 0.05)
    }
}

/// Hairline — ❦ — hairline, drawn beneath the title.
final class FlourishRuleView: UIView {
    private let leftRule = UIView()
    private let rightRule = UIView()
    private let fleuron = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        fleuron.text = Glyph.fleuron
        fleuron.font = .systemFont(ofSize: 17)
        fleuron.textAlignment = .center
        addSubview(leftRule)
        addSubview(rightRule)
        addSubview(fleuron)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(fleuron color: UIColor, rule: UIColor) {
        fleuron.textColor = color
        leftRule.backgroundColor = rule
        rightRule.backgroundColor = rule
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let glyphWidth: CGFloat = 28
        let gap: CGFloat = 8
        let midX = bounds.midX
        let midY = bounds.midY
        fleuron.frame = CGRect(x: midX - glyphWidth / 2, y: 0, width: glyphWidth, height: bounds.height)
        leftRule.frame = CGRect(x: 0, y: midY, width: max(0, midX - glyphWidth / 2 - gap), height: 1)
        let rightStart = midX + glyphWidth / 2 + gap
        rightRule.frame = CGRect(x: rightStart, y: midY, width: max(0, bounds.width - rightStart), height: 1)
    }
}
