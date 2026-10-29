import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings.
struct ChamberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scribe) private var scribe

    @AppStorage(SettingsKey.parchment) private var parchment: Parchment = .vellum
    @AppStorage(SettingsKey.ink) private var ink: RubricInk = .vermilion
    @AppStorage(SettingsKey.hand) private var hand: ScriptHand = .bookHand
    @AppStorage(SettingsKey.illuminated) private var illuminated = true
    @AppStorage(SettingsKey.canonicalHours) private var canonicalHours = true
    @AppStorage(SettingsKey.quillSounds) private var quillSounds = false
    @AppStorage(SettingsKey.quillHaptics) private var quillHaptics = true
    @AppStorage(SettingsKey.vigilMinutes) private var vigilMinutes = 25

    @Query private var allScrolls: [Scroll]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("The Chamber")
                            .font(Typeface.display(30, .semibold, relativeTo: .largeTitle))
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(scribe.body(18, .semibold))
                            .foregroundStyle(scribe.rubric)
                            .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 14)

                    section("Parchment") {
                        HStack(spacing: 12) {
                            ForEach(Parchment.allCases) { option in
                                ParchmentSwatch(parchment: option, isSelected: parchment == option) {
                                    parchment = option
                                }
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    section("Sealing wax & rubric") {
                        HStack(spacing: 6) {
                            ForEach(RubricInk.allCases) { option in
                                WaxWell(ink: option, isSelected: ink == option) {
                                    ink = option
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }

                    section("The hand") {
                        row {
                            rowLabel("Script")
                            Spacer()
                            SegmentedChoice(selection: $hand, options: ScriptHand.allCases) { $0.name }
                        }
                        rule
                        row {
                            Toggle(isOn: $illuminated) {
                                rowLabel("Illuminated initials", detail: "A gilded first letter on every scroll")
                            }
                        }
                        rule
                        row {
                            Toggle(isOn: $canonicalHours) {
                                rowLabel("Hours of the day", detail: canonicalHours ? "Vespers, Compline, Matins…" : "Clock time")
                            }
                        }
                    }

                    section("The quill") {
                        row {
                            Toggle(isOn: $quillSounds) { rowLabel("Quill scratch sounds") }
                        }
                        rule
                        row {
                            Toggle(isOn: $quillHaptics) { rowLabel("Haptic quill") }
                        }
                        rule
                        row {
                            Stepper(value: $vigilMinutes, in: 5...90, step: 5) {
                                HStack {
                                    rowLabel("Vigil length")
                                    Spacer()
                                    Text("\(vigilMinutes) minutes")
                                        .font(scribe.body(16, italic: true))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        section("Safekeeping") {
                            row {
                                ShareLink(
                                    item: CodexExport(markdown: ScrollText.codexMarkdown(allScrolls)),
                                    preview: SharePreview("Scriptorium.md")
                                ) {
                                    linkRow("Export all as Markdown", symbol: "square.and.arrow.down", tile: Color(hex: 0x5B6B3A))
                                }
                            }
                            rule
                            row {
                                NavigationLink {
                                    AshesView()
                                        .scribeStyle()
                                } label: {
                                    linkRow("The Ashes", symbol: "flame.fill", tile: Color(hex: 0xA3471F), detail: ashesDetail)
                                }
                            }
                        }
                        note("Thy scrolls are kept only on this iPhone. Nothing is collected, tracked or sent anywhere.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        section("About") {
                            row {
                                Button {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        UserDefaults.standard.set(false, forKey: SettingsKey.hasSeenWelcome)
                                    }
                                } label: {
                                    linkRow("Show the welcome again", symbol: "book.closed.fill", tile: Color(hex: 0x7A5A1E))
                                }
                            }
                        }
                        note("Version \(appVersion). Set in Cinzel, EB Garamond and UnifrakturMaguntia, under the SIL Open Font License.")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .background(ParchmentBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(scribe.ink.deep)
    }

    // MARK: Pieces

    private var ashesDetail: String {
        let count = allScrolls.filter { $0.burnedAt != nil }.count
        return count == 0 ? "Empty" : "\(count) burned"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var rule: some View {
        Rectangle().fill(Palette.rule).frame(height: 1)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RubricLabel(title)
                .padding(.leading, 6)
            ParchmentCard {
                content()
            }
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }

    private func rowLabel(_ text: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(text)
                .font(scribe.body(18))
                .foregroundStyle(Palette.ink)
            if let detail {
                Text(detail)
                    .font(scribe.body(14.5, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func linkRow(_ text: String, symbol: String, tile: Color, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0xF8F0DD))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(tile))
            rowLabel(text)
            Spacer()
            if let detail {
                Text(detail)
                    .font(scribe.body(16, italic: true))
                    .foregroundStyle(Palette.muted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .contentShape(Rectangle())
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(scribe.body(15, italic: true, relativeTo: .footnote))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 6)
    }
}

/// A two-way choice drawn as a recessed pill.
private struct SegmentedChoice<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(scribe.body(16, isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Palette.ground)
                                    .shadow(color: Palette.shadow, radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
    }
}

/// A tiny page preview for each parchment.
private struct ParchmentSwatch: View {
    let parchment: Parchment
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    switch parchment {
                    case .vellum:
                        MiniPage(ground: Color(hex: 0xF3E9D2), ink: Color(hex: 0x2A1F17), line: Color(hex: 0x8E7B62))
                    case .candlelight:
                        MiniPage(ground: Color(hex: 0x1A130D), ink: Color(hex: 0xECDDBE), line: Color(hex: 0x7D6D58))
                    case .bySun:
                        MiniPage(ground: Color(hex: 0xF3E9D2), ink: Color(hex: 0x2A1F17), line: Color(hex: 0x8E7B62))
                        MiniPage(ground: Color(hex: 0x1A130D), ink: Color(hex: 0xECDDBE), line: Color(hex: 0x7D6D58))
                            .mask { DiagonalHalf() }
                    }
                }
                .aspectRatio(0.78, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.ruleStrong, lineWidth: 1))
                .shadow(color: Palette.shadow, radius: 4, y: 3)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(isSelected ? scribe.rubric : .clear, lineWidth: 2.5)
                )
                Text(parchment.name)
                    .font(scribe.body(16, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(parchment.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MiniPage: View {
    let ground: Color
    let ink: Color
    let line: Color

    var body: some View {
        ZStack(alignment: .top) {
            ground
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(ink).frame(height: 6).padding(.horizontal, 14).padding(.bottom, 3)
                HStack(alignment: .top, spacing: 5) {
                    Text("S")
                        .font(Typeface.initial(12))
                        .foregroundStyle(Color(hex: 0xEBC66C))
                        .frame(width: 16, height: 16)
                        .background(Color(hex: 0x9B2A1A))
                        .overlay(Rectangle().strokeBorder(Palette.gilt, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(line.opacity(0.55)).frame(height: 4)
                        Capsule().fill(line.opacity(0.55)).frame(height: 4).padding(.trailing, 10)
                    }
                    .padding(.top, 2)
                }
                Capsule().fill(line.opacity(0.55)).frame(height: 4)
                Capsule().fill(line.opacity(0.55)).frame(height: 4).padding(.trailing, 18)
                Capsule().fill(line.opacity(0.55)).frame(height: 4).padding(.trailing, 6)
            }
            .padding(10)
        }
    }
}

private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A drop of sealing wax for each ink.
private struct WaxWell: View {
    let ink: RubricInk
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                WaxSealImage(size: 60, emblem: .plain, seed: "drop-\(ink.rawValue)", ink: ink)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Palette.gilt : .clear, lineWidth: 2)
                            .padding(-5)
                    )
                    .scaleEffect(isSelected ? 1.04 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                Text(ink.name)
                    .font(scribe.body(15, isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ink.name) wax")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The whole codex as a Markdown file.
struct CodexExport: Transferable {
    let markdown: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText) { export in
            Data(export.markdown.utf8)
        }
        .suggestedFileName("Scriptorium.md")
    }
}
