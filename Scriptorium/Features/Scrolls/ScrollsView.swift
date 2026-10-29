import SwiftData
import SwiftUI

/// Home: every scroll, newest first.
struct ScrollsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scribe) private var scribe

    @Query(filter: #Predicate<Scroll> { $0.burnedAt == nil }, sort: \Scroll.updatedAt, order: .reverse)
    private var scrolls: [Scroll]

    @State private var path: [Scroll] = []
    @State private var selectedTome: String?
    @State private var searchText = ""
    @State private var showChamber = false
    @State private var sealToBreak: Scroll?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                header
                    .listRowBackground(Palette.ground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))

                ForEach(visibleScrolls) { scroll in
                    ZStack {
                        NavigationLink(value: scroll) { EmptyView() }
                            .opacity(0)
                        ScrollRow(scroll: scroll)
                    }
                    .listRowBackground(Palette.ground)
                    .listRowSeparatorTint(Palette.rule)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            burn(scroll)
                        } label: {
                            Label("Burn", systemImage: "flame")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleSeal(scroll)
                        } label: {
                            Label(scroll.isSealed ? "Unseal" : "Seal", systemImage: scroll.isSealed ? "lock.open" : "lock")
                        }
                        .tint(scribe.rubric)
                    }
                    .contextMenu {
                        Button {
                            toggleSeal(scroll)
                        } label: {
                            Label(scroll.isSealed ? "Remove seal" : "Seal", systemImage: scroll.isSealed ? "lock.open" : "lock")
                        }
                        Button(role: .destructive) {
                            burn(scroll)
                        } label: {
                            Label("Burn", systemImage: "flame")
                        }
                    }
                }

                if !scrolls.isEmpty && visibleScrolls.isEmpty {
                    Text("No scroll bears those words.")
                        .font(scribe.body(18, italic: true))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .listRowBackground(Palette.ground)
                        .listRowSeparator(.hidden)
                }

                Color.clear
                    .frame(height: 90)
                    .listRowBackground(Palette.ground)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.ground)
            .navigationTitle("Thy Scrolls")
            .searchable(text: $searchText, prompt: "Search thy scrolls")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChamber = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("The Chamber (settings)")
                }
            }
            .navigationDestination(for: Scroll.self) { scroll in
                ScrollDestination(scroll: scroll)
            }
            .overlay {
                if scrolls.isEmpty {
                    EmptyCodexView()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                NewScrollButton(action: newScroll)
                    .padding(.trailing, 22)
                    .padding(.bottom, 16)
            }
            .sheet(isPresented: $showChamber) {
                ChamberView()
                    .scribeStyle()
            }
            .onChange(of: path) { _, newPath in
                guard newPath.isEmpty else { return }
                Task {
                    // Let the back animation finish before removing a blank scroll.
                    try? await Task.sleep(for: .milliseconds(700))
                    if path.isEmpty {
                        sweepEmptyScrolls()
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(subtitle)
                .font(scribe.body(17, italic: true, relativeTo: .subheadline))
                .foregroundStyle(Palette.muted)

            if !tomes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TomeChip(title: "All", isSelected: selectedTome == nil) {
                            selectedTome = nil
                        }
                        ForEach(tomes, id: \.self) { tome in
                            TomeChip(title: tome, isSelected: selectedTome == tome) {
                                selectedTome = selectedTome == tome ? nil : tome
                            }
                        }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        guard let latest = scrolls.first else { return "An empty codex awaits." }
        let count = scrolls.count
        let noun = count == 1 ? "scroll" : "scrolls"
        let when = ScribeDate.time(latest.updatedAt, canonical: scribe.canonicalHours)
        let day = Calendar.current.isDateInToday(latest.updatedAt) ? "at \(when)" : "on \(latest.updatedAt.formatted(.dateTime.day().month(.wide)))"
        return "\(ScribeDate.countWord(count)) \(noun) · last inked \(day)"
    }

    private var tomes: [String] {
        Array(Set(scrolls.map(\.tome).filter { !$0.isEmpty })).sorted()
    }

    private var visibleScrolls: [Scroll] {
        scrolls.filter { scroll in
            (selectedTome == nil || scroll.tome == selectedTome) && scroll.matches(searchText)
        }
    }

    // MARK: Actions

    private func newScroll() {
        let scroll = Scroll(tome: selectedTome ?? "")
        modelContext.insert(scroll)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        path.append(scroll)
    }

    private func burn(_ scroll: Scroll) {
        withAnimation {
            scroll.burnedAt = .now
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func toggleSeal(_ scroll: Scroll) {
        if scroll.isSealed {
            Task {
                let opened = await Biometrics.authenticate(reason: "Break the seal on “\(scroll.displayTitle)”.")
                if opened {
                    withAnimation { scroll.isSealed = false }
                }
            }
        } else if Biometrics.canSeal {
            withAnimation { scroll.isSealed = true }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    /// Scrolls opened and left blank are swept away rather than cluttering the codex.
    private func sweepEmptyScrolls() {
        for scroll in scrolls where scroll.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(scroll)
        }
    }
}

/// Shows the sealed screen until the seal is broken.
struct ScrollDestination: View {
    let scroll: Scroll

    @Environment(SealKeeper.self) private var sealKeeper

    var body: some View {
        if scroll.isSealed && !sealKeeper.isOpen(scroll) {
            SealedView(scroll: scroll)
        } else {
            ScrollEditorView(scroll: scroll)
        }
    }
}

struct ScrollRow: View {
    let scroll: Scroll

    @Environment(\.scribe) private var scribe

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if scroll.isSealed {
                WaxSeal(size: 44) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.onRubric)
                }
            } else {
                IlluminatedInitial(letter: scroll.initialLetter, size: 44)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(scroll.displayTitle)
                    .font(scribe.body(20, .semibold, relativeTo: .headline))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Group {
                    if scroll.isSealed {
                        Text("Sealed. Only thy face may break it.")
                            .font(scribe.body(16, italic: true, relativeTo: .subheadline))
                    } else if scroll.preview.isEmpty {
                        Text("No further words.")
                            .font(scribe.body(16, italic: true, relativeTo: .subheadline))
                    } else {
                        Text(scroll.preview)
                            .font(scribe.body(16, relativeTo: .subheadline))
                    }
                }
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)

                Text(meta)
                    .font(Typeface.display(11, .regular, relativeTo: .caption))
                    .tracking(1.3)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var meta: String {
        var parts = [ScribeDate.short(scroll.updatedAt, canonical: scribe.canonicalHours)]
        if !scroll.tome.isEmpty {
            parts.append(scroll.tome)
        }
        return parts.joined(separator: " · ").uppercased()
    }
}

struct TomeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Typeface.display(12, .semibold, relativeTo: .caption))
                .tracking(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .foregroundStyle(isSelected ? Palette.ground : Palette.ink)
                .background(Capsule().fill(isSelected ? Palette.ink : Color.clear))
                .overlay(Capsule().strokeBorder(isSelected ? Palette.ink : Palette.ruleStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The red wax seal that starts a new scroll.
struct NewScrollButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WaxSeal(size: 70) {
                QuillIcon(size: 30, lineWidth: 1.8)
                    .foregroundStyle(Palette.onRubric)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New scroll")
    }
}

struct EmptyCodexView: View {
    @Environment(\.scribe) private var scribe

    var body: some View {
        VStack(spacing: 16) {
            IlluminatedInitial(letter: "S", size: 88)
            Text("Thy codex is empty")
                .font(Typeface.display(20, .semibold))
                .foregroundStyle(Palette.ink)
            Text("Press the seal below to begin thy first scroll.")
                .font(scribe.body(18, italic: true))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .allowsHitTesting(false)
    }
}
