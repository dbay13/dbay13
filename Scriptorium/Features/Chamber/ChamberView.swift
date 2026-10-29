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
                VStack(alignment: .leading, spacing: 30) {
                    section("Parchment") {
                        HStack(spacing: 10) {
                            ForEach(Parchment.allCases) { option in
                                ParchmentSwatch(parchment: option, isSelected: parchment == option) {
                                    parchment = option
                                }
                            }
                        }
                    }

                    section("Rubric ink") {
                        HStack(spacing: 14) {
                            ForEach(RubricInk.allCases) { option in
                                InkWell(ink: option, isSelected: ink == option) {
                                    ink = option
                                }
                            }
                            Spacer(minLength: 0)
                            Text(ink.name)
                                .font(scribe.body(17, italic: true))
                                .foregroundStyle(Palette.muted)
                        }
                    }

                    section("The hand") {
                        ChamberRow {
                            HStack {
                                rowLabel("Script")
                                Spacer()
                                Picker("Script", selection: $hand) {
                                    ForEach(ScriptHand.allCases) { option in
                                        Text(option.name).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                        ChamberRow {
                            Toggle(isOn: $illuminated) { rowLabel("Illuminated initials") }
                        }
                        ChamberRow {
                            Toggle(isOn: $canonicalHours) {
                                VStack(alignment: .leading, spacing: 2) {
                                    rowLabel("Hours of the day")
                                    Text(canonicalHours ? "Vespers, Compline, Matins…" : "Clock time")
                                        .font(scribe.body(15, italic: true, relativeTo: .footnote))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }

                    section("The quill") {
                        ChamberRow {
                            Toggle(isOn: $quillSounds) { rowLabel("Quill scratch sounds") }
                        }
                        ChamberRow {
                            Toggle(isOn: $quillHaptics) { rowLabel("Haptic quill") }
                        }
                        ChamberRow {
                            Stepper(value: $vigilMinutes, in: 5...90, step: 5) {
                                HStack {
                                    rowLabel("Vigil length")
                                    Spacer()
                                    Text("\(vigilMinutes) minutes")
                                        .font(scribe.body(17))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }

                    section("Safekeeping") {
                        ChamberRow {
                            ShareLink(
                                item: CodexExport(markdown: ScrollText.codexMarkdown(allScrolls)),
                                preview: SharePreview("Scriptorium.md")
                            ) {
                                chevronRow("Export all as Markdown")
                            }
                        }
                        ChamberRow {
                            NavigationLink {
                                AshesView()
                                    .scribeStyle()
                            } label: {
                                chevronRow("The Ashes", detail: ashesDetail)
                            }
                        }
                        Text("Thy scrolls are kept only on this iPhone. Nothing is collected, tracked or sent anywhere.")
                            .font(scribe.body(15, italic: true, relativeTo: .footnote))
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 10)
                    }

                    section("About") {
                        ChamberRow {
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    UserDefaults.standard.set(false, forKey: SettingsKey.hasSeenWelcome)
                                }
                            } label: {
                                chevronRow("Show the welcome again")
                            }
                        }
                        Text("Version \(appVersion). Set in Cinzel, EB Garamond and UnifrakturMaguntia, under the SIL Open Font License.")
                            .font(scribe.body(15, italic: true, relativeTo: .footnote))
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Palette.ground.ignoresSafeArea())
            .navigationTitle("The Chamber")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(scribe.rubric)
    }

    // MARK: Pieces

    private var ashesDetail: String {
        let count = allScrolls.filter { $0.burnedAt != nil }.count
        return count == 0 ? "empty" : "\(count) burned"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RubricLabel(title)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(scribe.body(18))
            .foregroundStyle(Palette.ink)
    }

    private func chevronRow(_ text: String, detail: String? = nil) -> some View {
        HStack {
            rowLabel(text)
            Spacer()
            if let detail {
                Text(detail)
                    .font(scribe.body(16, italic: true))
                    .foregroundStyle(Palette.muted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .contentShape(Rectangle())
    }
}

private struct ChamberRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
    }
}

private struct ParchmentSwatch: View {
    let parchment: Parchment
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                swatch
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.ruleStrong, lineWidth: 1))
                Text(parchment.name)
                    .font(scribe.body(16, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Palette.ink : Palette.ruleStrong, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(parchment.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var swatch: some View {
        switch parchment {
        case .vellum:
            page(ground: Color(hex: 0xF7EFDC), letter: Color(hex: 0x9E2B1B))
        case .candlelight:
            page(ground: Color(hex: 0x17110C), letter: Color(hex: 0xE3A944))
        case .bySun:
            HStack(spacing: 0) {
                Color(hex: 0xF7EFDC)
                Color(hex: 0x17110C)
            }
        }
    }

    private func page(ground: Color, letter: Color) -> some View {
        ZStack {
            ground
            Text("A")
                .font(Typeface.initial(30))
                .foregroundStyle(letter)
        }
    }
}

private struct InkWell: View {
    let ink: RubricInk
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(ink.color)
                .padding(4)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(isSelected ? Palette.ink : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ink.name) ink")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The whole codex as a Markdown file.
struct CodexExport: Transferable {
    let markdown: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { export in
            Data(export.markdown.utf8)
        }
        .suggestedFileName("Scriptorium.md")
    }
}
