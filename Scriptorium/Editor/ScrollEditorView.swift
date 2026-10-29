import SwiftData
import SwiftUI

struct ScrollEditorView: View {
    @Bindable var scroll: Scroll

    @Environment(\.scribe) private var scribe
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext
    @Environment(SealKeeper.self) private var sealKeeper
    @Environment(Herald.self) private var herald
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
            topBar
            metaLine
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 2)

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
        .background(ParchmentBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorDock(
                scroll: scroll,
                controller: controller,
                tomes: tomeOptions,
                onNewTome: { askNewTome = true }
            )
            .padding(.bottom, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if stamping {
                SealStamp(seed: scroll.sealSeed)
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
        .alert("Bind a new tome", isPresented: $askNewTome) {
            TextField("Name", text: $newTomeName)
            Button("Cancel", role: .cancel) { newTomeName = "" }
            Button("Bind") {
                let name = newTomeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    scroll.tome = name
                    herald.announce("Bound into \(name)", symbol: "books.vertical.fill")
                }
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

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                GlassBackLabel(title: "Scrolls")
            }
            .buttonStyle(GlassButtonStyle())

            Spacer()

            Button {
                controller.endEditing()
                showVigil = true
            } label: {
                CandleIcon(size: 21)
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel("Begin a vigil")

            Button(action: toggleSeal) {
                Image(systemName: scroll.isSealed ? "lock.fill" : "lock.open")
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel(scroll.isSealed ? "Remove the seal" : "Seal this scroll")

            Menu {
                Button {
                    shareManuscript()
                } label: {
                    Label("Share as manuscript page", systemImage: "doc.richtext")
                }
                Button {
                    share = ShareItems(items: [scroll.text])
                } label: {
                    Label("Share as text", systemImage: "text.alignleft")
                }
                Divider()
                Button(role: .destructive) {
                    burn()
                } label: {
                    Label("Burn scroll", systemImage: "flame.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .modifier(GlassChip())
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            if scroll.isSealed {
                HStack(spacing: 5) {
                    WaxSealImage(size: 20, seed: scroll.sealSeed)
                    SmallCaps("Sealed", color: scribe.rubric)
                }
                SmallCaps("·")
            }
            SmallCaps(ScribeDate.long(scroll.createdAt, canonical: scribe.canonicalHours))
            if !scroll.tome.isEmpty {
                SmallCaps("·")
                SmallCaps(scroll.tome)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { scroll.text },
            set: { newValue in
                scroll.text = newValue
                scroll.updatedAt = .now
            }
        )
    }

    private var tomeOptions: [String] {
        let used = Set(allScrolls.map(\.tome).filter { !$0.isEmpty })
        return used.union(["Musings", "Quests", "Ledger"]).sorted()
    }

    private var placeholder: some View {
        VStack(spacing: 36) {
            Text("Title")
                .font(scribe.body(32, .semibold, relativeTo: .title))
            Text("Begin thy scroll beneath…")
                .font(scribe.body(19.5, italic: true))
        }
        .foregroundStyle(Palette.dim)
        .padding(.top, 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func toggleSeal() {
        if scroll.isSealed {
            scroll.isSealed = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            herald.announce("Seal removed", symbol: "lock.open.fill")
            return
        }
        guard !scroll.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            herald.announce("Write something first, then seal it", symbol: "lock.fill")
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
        Task {
            // Render the seal first, so the stamp lands as real wax, not a placeholder.
            let pixels = Int((SealStamp.size * max(2, displayScale)).rounded())
            _ = await WaxSealRenderer.image(WaxSealSpec(ink: scribe.ink, seed: scroll.sealSeed, pixels: pixels))
            stamping = true
            try? await Task.sleep(for: .milliseconds(1300))
            withAnimation(.easeOut(duration: 0.3)) { stamping = false }
        }
    }

    private func burn() {
        guard !scroll.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            dismiss()
            return
        }
        let burned = scroll
        burned.burnedAt = .now
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
        herald.announce("Scroll burned", symbol: "flame.fill") {
            withAnimation { burned.burnedAt = nil }
        }
    }

    private func shareManuscript() {
        let spec = WaxSealSpec(ink: scribe.ink, emblem: .letter("S"), seed: scroll.sealSeed, pixels: 200)
        Task {
            let seal = await WaxSealRenderer.image(spec)
            let page = ManuscriptPage(scroll: scroll, scribe: scribe, seal: seal)
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: page)
            renderer.scale = max(3, displayScale)
            if let image = renderer.uiImage {
                share = ShareItems(items: [image])
            }
        }
    }
}

/// The wax seal pressed onto the page when a scroll is sealed.
private struct SealStamp: View {
    static let size: CGFloat = 196

    let seed: String

    @State private var landed = false
    @State private var settled = false

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.black.opacity(landed ? 0.16 : 0), .clear], center: .center, startRadius: 0, endRadius: 320)
                .ignoresSafeArea()
            WaxSealImage(size: Self.size, seed: seed)
                .scaleEffect(x: landed ? (settled ? 1 : 0.96) : 1.7, y: landed ? (settled ? 1 : 1.03) : 1.7)
                .rotationEffect(.degrees(landed ? 0 : -14))
                .opacity(landed ? 1 : 0)
                .blur(radius: landed ? 0 : 3)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                landed = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(240))
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    settled = true
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Scroll sealed")
    }
}

/// The floating toolbar at the foot of the page.
struct EditorDock: View {
    @Bindable var scroll: Scroll
    @ObservedObject var controller: ManuscriptController
    let tomes: [String]
    let onNewTome: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(spacing: 2) {
            Text(scroll.wordCount == 1 ? "1 word" : "\(scroll.wordCount) words")
                .font(scribe.body(16, italic: true, relativeTo: .footnote))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .accessibilityLabel("\(scroll.wordCount) words, saved")

            Button { controller.toggleChecklist() } label: {
                Image(systemName: "checklist")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Checklist")

            Button { controller.insertFlourish() } label: {
                Text(Glyph.fleuron)
                    .font(.system(size: 21))
                    .foregroundStyle(Palette.gold)
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
                Button("Bind a new tome…", systemImage: "plus", action: onNewTome)
            } label: {
                Image(systemName: "books.vertical")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Move to tome")

            if controller.isEditing {
                Rectangle()
                    .fill(Palette.ruleStrong)
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, 4)
                Button { controller.endEditing() } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Hide keyboard")
            }
        }
        .font(.system(size: 18))
        .foregroundStyle(Palette.ink)
        .buttonStyle(.plain)
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Palette.glass, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.ruleStrong.opacity(0.7), lineWidth: 1))
        .shadow(color: Palette.shadow, radius: 15, y: 10)
        .animation(.easeOut(duration: 0.2), value: controller.isEditing)
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
