import SwiftData
import SwiftUI

struct ScrollEditorView: View {
    @Bindable var scroll: Scroll

    @Environment(\.scribe) private var scribe
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SealKeeper.self) private var sealKeeper
    @Query(filter: #Predicate<Scroll> { $0.burnedAt == nil }) private var allScrolls: [Scroll]

    @AppStorage(SettingsKey.quillSounds) private var quillSounds = false
    @AppStorage(SettingsKey.quillHaptics) private var quillHaptics = true

    @StateObject private var controller = ManuscriptController()
    @State private var showVigil = false
    @State private var stamping = false
    @State private var showNoPasscode = false
    @State private var askNewTome = false
    @State private var newTomeName = ""
    @State private var share: ShareItems?

    var body: some View {
        VStack(spacing: 0) {
            Text(metaLine)
                .font(Typeface.display(11, .regular, relativeTo: .caption))
                .tracking(1.7)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 24)
                .padding(.top, 2)
                .padding(.bottom, 4)

            ManuscriptTextView(
                text: textBinding,
                controller: controller,
                style: .make(scribe: scribe, dark: colorScheme == .dark),
                onUserEdit: { QuillFeedback.shared.stroke(haptics: quillHaptics, sounds: quillSounds) }
            )
            .overlay(alignment: .top) {
                if scroll.text.isEmpty {
                    placeholder
                }
            }
        }
        .background(Palette.ground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorBar(
                scroll: scroll,
                controller: controller,
                tomes: tomeOptions,
                onNewTome: { askNewTome = true }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .overlay {
            if stamping {
                SealStamp()
            }
        }
        .fullScreenCover(isPresented: $showVigil) {
            VigilView(scroll: scroll)
                .scribeStyle()
        }
        .sheet(item: $share) { item in
            ActivityView(items: item.items)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .alert("A seal needs a passcode", isPresented: $showNoPasscode) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Set a passcode for this iPhone in Settings, then thou canst seal scrolls with Face ID.")
        }
        .alert("New tome", isPresented: $askNewTome) {
            TextField("Name", text: $newTomeName)
            Button("Cancel", role: .cancel) { newTomeName = "" }
            Button("Bind") {
                let name = newTomeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { scroll.tome = name }
                newTomeName = ""
            }
        } message: {
            Text("A tome gathers scrolls of a kind.")
        }
        .task {
            guard scroll.text.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(450))
            controller.beginEditing()
        }
    }

    // MARK: Pieces

    private var textBinding: Binding<String> {
        Binding(
            get: { scroll.text },
            set: { newValue in
                scroll.text = newValue
                scroll.updatedAt = .now
            }
        )
    }

    private var metaLine: String {
        var parts = [ScribeDate.long(scroll.createdAt, canonical: scribe.canonicalHours)]
        if !scroll.tome.isEmpty {
            parts.append(scroll.tome)
        }
        return parts.joined(separator: " · ").uppercased()
    }

    private var tomeOptions: [String] {
        let used = Set(allScrolls.map(\.tome).filter { !$0.isEmpty })
        return used.union(["Musings", "Quests", "Ledger"]).sorted()
    }

    private var placeholder: some View {
        VStack(spacing: 30) {
            Text("Title")
                .font(scribe.body(30, .semibold, relativeTo: .title))
            Text("Begin thy scroll beneath…")
                .font(scribe.body(19, italic: true))
        }
        .foregroundStyle(Palette.muted.opacity(0.7))
        .padding(.top, 10)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                controller.endEditing()
                showVigil = true
            } label: {
                Image(systemName: "flame")
            }
            .accessibilityLabel("Begin a vigil")

            Button(action: toggleSeal) {
                Image(systemName: scroll.isSealed ? "lock.fill" : "lock.open")
            }
            .accessibilityLabel(scroll.isSealed ? "Remove the seal" : "Seal this scroll")

            Menu {
                Button {
                    shareManuscript()
                } label: {
                    Label("Share as manuscript page", systemImage: "photo")
                }
                Button {
                    share = ShareItems(items: [scroll.text])
                } label: {
                    Label("Share as text", systemImage: "text.alignleft")
                }
                Divider()
                Button(role: .destructive) {
                    scroll.burnedAt = .now
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    dismiss()
                } label: {
                    Label("Burn scroll", systemImage: "flame.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }

    // MARK: Actions

    private func toggleSeal() {
        if scroll.isSealed {
            scroll.isSealed = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        guard Biometrics.canSeal else {
            showNoPasscode = true
            return
        }
        controller.endEditing()
        scroll.isSealed = true
        try? modelContext.save()
        sealKeeper.open(scroll)
        stamping = true
        Task {
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeOut(duration: 0.25)) { stamping = false }
        }
    }

    private func shareManuscript() {
        let page = ManuscriptPage(scroll: scroll, scribe: scribe)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: page)
        renderer.scale = 3
        if let image = renderer.uiImage {
            share = ShareItems(items: [image])
        }
    }
}

/// The wax seal pressed onto the page when a scroll is sealed.
private struct SealStamp: View {
    @State private var landed = false

    var body: some View {
        ZStack {
            Color.black.opacity(landed ? 0.12 : 0).ignoresSafeArea()
            WaxSeal(size: 170) {
                SealMonogram(size: 170)
            }
            .scaleEffect(landed ? 1 : 1.9)
            .opacity(landed ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                landed = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Scroll sealed")
    }
}

struct EditorBar: View {
    @Bindable var scroll: Scroll
    @ObservedObject var controller: ManuscriptController
    let tomes: [String]
    let onNewTome: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(spacing: 0) {
            Text("\(scroll.wordCount) words · Kept")
                .font(scribe.body(16, italic: true, relativeTo: .footnote))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 8)
                .accessibilityLabel("\(scroll.wordCount) words, saved")

            Spacer(minLength: 8)

            Button { controller.toggleChecklist() } label: {
                Image(systemName: "checklist")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Checklist")

            Button { controller.insertFlourish() } label: {
                Text(Glyph.fleuron)
                    .font(.system(size: 21))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Insert flourish divider")

            Menu {
                Picker("Tome", selection: $scroll.tome) {
                    Text("No tome").tag("")
                    ForEach(tomes, id: \.self) { tome in
                        Text(tome).tag(tome)
                    }
                }
                Button("New tome…", systemImage: "plus", action: onNewTome)
            } label: {
                Image(systemName: "books.vertical")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Move to tome")

            if controller.isEditing {
                Button { controller.endEditing() } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Hide keyboard")
            }
        }
        .font(.system(size: 18))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Palette.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
    }
}

struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
