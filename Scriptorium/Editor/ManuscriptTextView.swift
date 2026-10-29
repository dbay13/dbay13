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
    var rubricDeep: UIColor
    var rubricTop: UIColor
    var rubricBottom: UIColor
    var gold: UIColor
    var rule: UIColor
    var illuminated: Bool
    var focusMode: Bool
    var dark: Bool

    static func make(scribe: ScribeStyle, dark: Bool, focusMode: Bool = false, illuminated: Bool? = nil) -> ManuscriptStyle {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        func resolve(_ color: UIColor) -> UIColor { color.resolvedColor(with: traits) }
        let bodySize: CGFloat = focusMode ? 20.5 : 19.5
        return ManuscriptStyle(
            bodyFont: UIFontMetrics(forTextStyle: .body).scaledFont(for: scribe.uiBody(bodySize)),
            titleFont: UIFontMetrics(forTextStyle: .title1).scaledFont(for: scribe.uiBody(32, .semibold)),
            initialFont: Typeface.uiInitial(48),
            ink: focusMode ? Palette.vigilInk : resolve(Palette.inkUI),
            dimInk: focusMode ? Palette.vigilDim : resolve(Palette.dimUI),
            mutedInk: resolve(Palette.mutedUI),
            rubric: resolve(scribe.ink.uiColor),
            rubricDeep: scribe.ink.deepUIColor,
            rubricTop: scribe.ink.deepTop,
            rubricBottom: scribe.ink.deepBottom,
            gold: resolve(Palette.goldUI),
            rule: resolve(Palette.ruleStrongUI),
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
            let controller = parent.controller
            DispatchQueue.main.async { controller.isEditing = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            let controller = parent.controller
            DispatchQueue.main.async { controller.isEditing = false }
        }
    }
}

/// A TextKit 1 text view that sets the first line as a centered title and
/// decorates the page: a fleuron rule under the title, a gilded initial at the
/// start of the first paragraph, drawn checkboxes for ☐ / ☑ lines, and fleuron
/// rules for ❦ lines. The real characters stay in the text, hidden, so the
/// note remains plain text.
final class ManuscriptUITextView: UITextView {
    private struct CheckEntry {
        let index: Int
        let checked: Bool
        let dimmed: Bool
    }

    private let storage = NSTextStorage()
    private let initialView = IlluminatedCapView()
    private let titleRule = FlourishRuleView()
    private var checkViews: [CheckboxMarkView] = []
    private var ruleViews: [FlourishRuleView] = []
    private let gestureGate = GestureGate()

    private var initialIndex: Int?
    private var checkEntries: [CheckEntry] = []
    private var fleuronIndices: [Int] = []
    private var exclusionRect = CGRect.null
    private var bodyLineSpacing: CGFloat = 6
    private var checkSide: CGFloat = 23

    private static let titleGap: CGFloat = 50

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
        textContainerInset = UIEdgeInsets(top: 8, left: 28, bottom: 40, right: 28)

        initialView.isHidden = true
        titleRule.isHidden = true
        addSubview(titleRule)
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

        bodyLineSpacing = round(style.bodyFont.pointSize * 0.36)
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = bodyLineSpacing
        bodyParagraph.paragraphSpacing = round(style.bodyFont.pointSize * 0.56)
        bodyParagraph.hyphenationFactor = 0.6

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        titleParagraph.lineSpacing = 2
        titleParagraph.paragraphSpacing = Self.titleGap

        let fleuronParagraph = NSMutableParagraphStyle()
        fleuronParagraph.alignment = .center
        fleuronParagraph.paragraphSpacingBefore = 6
        fleuronParagraph.paragraphSpacing = round(style.bodyFont.pointSize * 0.8)

        checkSide = round(style.bodyFont.pointSize * 1.2)
        let glyphAdvance = (Glyph.box as NSString).size(withAttributes: [.font: style.bodyFont]).width
        let spaceAdvance = (" " as NSString).size(withAttributes: [.font: style.bodyFont]).width
        let boxKern = max(0, checkSide + 9 - glyphAdvance)
        let checklistParagraph = NSMutableParagraphStyle()
        checklistParagraph.lineSpacing = bodyLineSpacing
        checklistParagraph.paragraphSpacing = round(style.bodyFont.pointSize * 0.3)
        checklistParagraph.headIndent = ceil(checkSide + 9 + spaceAdvance)

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
        var newChecks: [CheckEntry] = []
        var newFleurons: [Int] = []
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
                let checked = paragraph.hasPrefix(Glyph.checked)
                self.storage.addAttribute(.paragraphStyle, value: checklistParagraph, range: enclosing)
                self.storage.addAttributes(
                    [.foregroundColor: UIColor.clear, .kern: boxKern],
                    range: NSRange(location: range.location, length: 1)
                )
                if checked, range.length > 2 {
                    let words = NSRange(location: range.location + 2, length: range.length - 2)
                    self.storage.addAttributes([
                        .foregroundColor: dimmed ? style.dimInk : style.mutedInk,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: style.rubric.withAlphaComponent(0.6),
                    ], range: words)
                }
                newChecks.append(CheckEntry(index: range.location, checked: checked, dimmed: dimmed))
            } else if paragraph.trimmingCharacters(in: .whitespaces) == Glyph.fleuron {
                self.storage.addAttributes([.paragraphStyle: fleuronParagraph, .foregroundColor: UIColor.clear], range: enclosing)
                newFleurons.append(range.location)
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
        checkEntries = newChecks
        fleuronIndices = newFleurons
        initialView.configure(letter: newInitialLetter, font: style.initialFont, top: style.rubricTop, deep: style.rubricDeep, bottom: style.rubricBottom)
        titleRule.configure(fleuron: style.gold, rule: style.rule)
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

        // Fleuron rule under the title, once there is a second line.
        let firstBreak = string.range(of: "\n")
        if firstBreak.location != NSNotFound, firstBreak.location > 0 {
            let titleGlyphs = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: 0, length: firstBreak.location),
                actualCharacterRange: nil
            )
            let lastGlyph = max(0, NSMaxRange(titleGlyphs) - 1)
            let used = layoutManager.lineFragmentUsedRect(forGlyphAt: lastGlyph, effectiveRange: nil)
            titleRule.frame = CGRect(x: origin.x + padding, y: origin.y + used.maxY + 14, width: width, height: 22)
            titleRule.isHidden = false
        } else {
            titleRule.isHidden = true
        }

        // Illuminated initial: a box two lines tall, with text flowing around it.
        if let index = initialIndex, index < string.length {
            let side = ceil(style.bodyFont.lineHeight * 2 + bodyLineSpacing) - 2
            let glyph = layoutManager.glyphIndexForCharacter(at: index)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let exclusion = CGRect(x: 0, y: line.minY, width: padding + side + 11, height: side + 4)
            if exclusionRect.isNull || abs(exclusion.minY - exclusionRect.minY) > 0.5 || abs(exclusion.width - exclusionRect.width) > 0.5 {
                exclusionRect = exclusion
                textContainer.exclusionPaths = [UIBezierPath(rect: exclusion)]
            }
            initialView.frame = CGRect(x: origin.x + padding, y: origin.y + line.minY + 4, width: side, height: side)
            initialView.isHidden = false
        } else {
            if !textContainer.exclusionPaths.isEmpty {
                textContainer.exclusionPaths = []
            }
            exclusionRect = .null
            initialView.isHidden = true
        }

        // Drawn checkboxes over the hidden ☐ / ☑ characters.
        while checkViews.count < checkEntries.count {
            let view = CheckboxMarkView()
            addSubview(view)
            checkViews.append(view)
        }
        for (position, view) in checkViews.enumerated() {
            guard position < checkEntries.count, checkEntries[position].index < string.length else {
                view.isHidden = true
                continue
            }
            let entry = checkEntries[position]
            let glyph = layoutManager.glyphIndexForCharacter(at: entry.index)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let location = layoutManager.location(forGlyphAt: glyph)
            let baseline = line.minY + location.y
            let centerY = baseline - style.bodyFont.xHeight / 2 - 1
            view.frame = CGRect(x: origin.x + line.minX + location.x, y: origin.y + centerY - checkSide / 2, width: checkSide, height: checkSide)
            view.configure(index: entry.index, checked: entry.checked, ink: entry.dimmed ? style.dimInk : style.rubric)
            view.isHidden = false
        }

        // Fleuron rules over hidden ❦ lines.
        while ruleViews.count < fleuronIndices.count {
            let view = FlourishRuleView()
            addSubview(view)
            ruleViews.append(view)
        }
        for (position, view) in ruleViews.enumerated() {
            guard position < fleuronIndices.count, fleuronIndices[position] < string.length else {
                view.isHidden = true
                continue
            }
            let glyph = layoutManager.glyphIndexForCharacter(at: fleuronIndices[position])
            let used = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            view.frame = CGRect(x: origin.x + padding, y: origin.y + used.midY - 11, width: width, height: 22)
            view.configure(fleuron: style.gold, rule: style.rule)
            view.isHidden = false
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
        for (position, view) in checkViews.enumerated() where !view.isHidden && position < checkEntries.count {
            if view.frame.insetBy(dx: -12, dy: -9).contains(point) {
                return checkEntries[position].index
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

/// The gilded initial drawn over the hidden first letter.
final class IlluminatedCapView: UIView {
    private let label = UILabel()
    private var baseFont = UIFont.systemFont(ofSize: 40)
    private var top = UIColor.red
    private var deep = UIColor.red
    private var bottom = UIColor.red

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        isOpaque = false
        contentMode = .redraw
        label.textAlignment = .center
        label.layer.shadowColor = UIColor(hex: 0x280C04).cgColor
        label.layer.shadowOpacity = 0.65
        label.layer.shadowRadius = 0
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(label)
        layer.shadowColor = UIColor(hex: 0x3C2610).cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(letter: String, font: UIFont, top: UIColor, deep: UIColor, bottom: UIColor) {
        label.text = letter
        baseFont = font
        self.top = top
        self.deep = deep
        self.bottom = bottom
        setNeedsLayout()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = bounds.height
        guard side > 0 else { return }
        label.font = baseFont.withSize(side * 0.74)
        label.frame = bounds.offsetBy(dx: 0, dy: side * 0.06)
        label.textColor = UIColor(patternImage: Self.goldLeaf(height: side))
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let colors = [top.cgColor, deep.cgColor, bottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.52, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.maxX, y: bounds.maxY), options: [])
        }
        context.setFillColor(UIColor(hex: 0xFFEECD, alpha: 0.24).cgColor)
        let spacing: CGFloat = 7
        var y = spacing / 2
        while y < bounds.maxY {
            var x = spacing / 2
            while x < bounds.maxX {
                context.fillEllipse(in: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6))
                x += spacing
            }
            y += spacing
        }
        context.setStrokeColor(Palette.giltUI.cgColor)
        context.setLineWidth(1.6)
        context.stroke(bounds.insetBy(dx: 0.8, dy: 0.8))
        context.setStrokeColor(UIColor(hex: 0xE9C779, alpha: 0.45).cgColor)
        context.setLineWidth(1)
        context.stroke(bounds.insetBy(dx: 3.5, dy: 3.5))
    }

    /// A vertical gold-leaf gradient used as the letter's color.
    private static func goldLeaf(height: CGFloat) -> UIImage {
        let size = CGSize(width: 2, height: max(1, height))
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [0xFFF4CF, 0xEBC66C, 0xB8862B, 0xF4D88E, 0xC99A3C].map { UIColor(hex: UInt32($0)).cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.32, 0.6, 0.84, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }
}

/// A drawn checkbox. The tick is drawn on like a pen stroke.
final class CheckboxMarkView: UIView {
    private let tick = CAShapeLayer()
    private var representedIndex: Int?
    private var isChecked = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        layer.borderWidth = 1.7
        layer.cornerRadius = 3.5
        tick.fillColor = nil
        tick.lineWidth = 2.6
        tick.lineCap = .round
        tick.lineJoin = .round
        tick.strokeEnd = 0
        layer.addSublayer(tick)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(index: Int, checked: Bool, ink: UIColor) {
        layer.borderColor = ink.cgColor
        tick.strokeColor = ink.cgColor
        let animate = representedIndex == index && checked && !isChecked && !UIAccessibility.isReduceMotionEnabled
        representedIndex = index
        isChecked = checked
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tick.strokeEnd = checked ? 1 : 0
        CATransaction.commit()
        if animate {
            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.duration = 0.28
            draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
            tick.add(draw, forKey: "draw")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: w * 0.2, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.41, y: h * 0.73))
        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.24))
        tick.frame = bounds
        tick.path = path.cgPath
    }
}

/// Hairline — ❦ — hairline, fading at the ends.
final class FlourishRuleView: UIView {
    private let leftRule = CAGradientLayer()
    private let rightRule = CAGradientLayer()
    private let fleuron = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        fleuron.text = Glyph.fleuron
        fleuron.font = .systemFont(ofSize: 18)
        fleuron.textAlignment = .center
        leftRule.startPoint = CGPoint(x: 0, y: 0.5)
        leftRule.endPoint = CGPoint(x: 1, y: 0.5)
        rightRule.startPoint = CGPoint(x: 0, y: 0.5)
        rightRule.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(leftRule)
        layer.addSublayer(rightRule)
        addSubview(fleuron)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(fleuron color: UIColor, rule: UIColor) {
        fleuron.textColor = color
        leftRule.colors = [rule.withAlphaComponent(0).cgColor, rule.cgColor]
        rightRule.colors = [rule.cgColor, rule.withAlphaComponent(0).cgColor]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let glyphWidth: CGFloat = 28
        let gap: CGFloat = 8
        let midX = bounds.midX
        let midY = round(bounds.midY)
        fleuron.frame = CGRect(x: midX - glyphWidth / 2, y: 0, width: glyphWidth, height: bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        leftRule.frame = CGRect(x: 0, y: midY, width: max(0, midX - glyphWidth / 2 - gap), height: 1)
        let rightStart = midX + glyphWidth / 2 + gap
        rightRule.frame = CGRect(x: rightStart, y: midY, width: max(0, bounds.width - rightStart), height: 1)
        CATransaction.commit()
    }
}
