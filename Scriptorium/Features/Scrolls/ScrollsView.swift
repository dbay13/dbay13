import SwiftData
import SwiftUI

/// Home: every scroll, newest first.
struct ScrollsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scribe) private var scribe
    @Environment(Herald.self) private var herald

    @Query(filter: #Predicate<Scroll> { $0.burnedAt == nil }, sort: \Scroll.updatedAt, order: .reverse)
    private var scrolls: [Scroll]

    @State private var path: [Scroll] = []
    @State private var selectedTome: String?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showChamber = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ParchmentBackground()

                List {
                    header
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 4, trailing: 22))

                    ForEach(visibleScrolls) { scroll in
                        ZStack {
                            NavigationLink(value: scroll) { EmptyView() }
                                .opacity(0)
                            ScrollRow(scroll: scroll)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                burn(scroll)
                            } label: {
                                Label("Burn", systemImage: "flame.fill")
                            }
                            .tint(Palette.ember)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                toggleSeal(scroll)
                            } label: {
                                Label(scroll.isSealed ? "Unseal" : "Seal", systemImage: scroll.isSealed ? "lock.open.fill" : "seal.fill")
                            }
                            .tint(scribe.ink.deep)
                        }
                        .contextMenu {
                            Button {
                                toggleSeal(scroll)
                            } label: {
                                Label(scroll.isSealed ? "Break the seal" : "Seal", systemImage: scroll.isSealed ? "lock.open" : "seal")
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
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Color.clear
                        .frame(height: 110)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .top, spacing: 0) { topBar }
                .overlay {
                    if scrolls.isEmpty {
                        EmptyCodexView()
                    }
                }

                LinearGradient(colors: [Palette.ground.opacity(0), Palette.ground.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)

                NewScrollButton(action: newScroll)
                    .padding(.trailing, 18)
                    .padding(.bottom, 10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Scroll.self) { scroll in
                ScrollDestination(scroll: scroll)
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

    private var topBar: some View {
        HStack(spacing: 10) {
            WaxSealImage(size: 34, seed: "brand")
            RubricLabel("Scriptorium")
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isSearching.toggle()
                }
                if isSearching {
                    searchFocused = true
                } else {
                    searchText = ""
                }
            } label: {
                Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel(isSearching ? "Close search" : "Search scrolls")

            Button {
                showChamber = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(GlassButtonStyle())
            .accessibilityLabel("The Chamber (settings)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(
            Palette.ground.opacity(0.94)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            SmallCaps(todayLine)
            Text("Thy Scrolls")
                .font(Typeface.display(36, .semibold, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(scribe.body(17.5, italic: true, relativeTo: .subheadline))
                .foregroundStyle(Palette.muted)
                .padding(.top, 2)

            if isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Palette.muted)
                    TextField("Search thy scrolls", text: $searchText)
                        .font(scribe.body(17))
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Capsule().fill(Palette.card))
                .overlay(Capsule().strokeBorder(Palette.rule, lineWidth: 1))
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !tomes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 22) {
                        TomeTab(title: "All", isSelected: selectedTome == nil) {
                            selectedTome = nil
                        }
                        ForEach(tomes, id: \.self) { tome in
                            TomeTab(title: tome, isSelected: selectedTome == tome) {
                                selectedTome = selectedTome == tome ? nil : tome
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    private var todayLine: String {
        let now = Date.now
        let day = Calendar.current.component(.day, from: now)
        return "\(now.formatted(.dateTime.weekday(.wide))) · the \(ScribeDate.ordinal(day)) of \(now.formatted(.dateTime.month(.wide)))"
    }

    private var subtitle: String {
        guard let latest = scrolls.first else { return "An empty codex awaits thy quill." }
        let count = scrolls.count
        let noun = count == 1 ? "scroll" : "scrolls"
        let when = Calendar.current.isDateInToday(latest.updatedAt)
            ? "at \(ScribeDate.time(latest.updatedAt, canonical: scribe.canonicalHours))"
            : "on \(latest.updatedAt.formatted(.dateTime.day().month(.wide)))"
        return "\(ScribeDate.countWord(count)) \(noun), last inked \(when)"
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
        // Save now so the scroll gets its permanent ID before it is pushed or sealed.
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        path.append(scroll)
    }

    private func burn(_ scroll: Scroll) {
        withAnimation {
            scroll.burnedAt = .now
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        herald.announce("Scroll burned", symbol: "flame.fill") {
            withAnimation {
                scroll.burnedAt = nil
            }
        }
    }

    private func toggleSeal(_ scroll: Scroll) {
        if scroll.isSealed {
            Task {
                let opened = await Biometrics.authenticate(reason: "Break the seal on “\(scroll.displayTitle)”.")
                if opened {
                    withAnimation { scroll.isSealed = false }
                    herald.announce("Seal broken", symbol: "lock.open.fill")
                }
            }
        } else if Biometrics.canSeal {
            withAnimation { scroll.isSealed = true }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            herald.announce("Scroll sealed", sealSeed: scroll.sealSeed)
        } else {
            herald.announce("Set a passcode in Settings to use seals", symbol: "lock.fill")
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
        Group {
            if scroll.isSealed && !sealKeeper.isOpen(scroll) {
                SealedView(scroll: scroll)
            } else {
                ScrollEditorView(scroll: scroll)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ScrollRow: View {
    let scroll: Scroll

    @Environment(\.scribe) private var scribe

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                if scroll.isSealed {
                    WaxSealImage(size: 50, seed: scroll.sealSeed)
                        .padding(-1)
                } else {
                    IlluminatedInitial(letter: scroll.initialLetter, size: 48)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(scroll.displayTitle)
                        .font(scribe.body(20.5, .semibold, relativeTo: .headline))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    Group {
                        if scroll.isSealed {
                            Text("Sealed. Only thy face may break it.")
                                .font(scribe.body(16.5, italic: true, relativeTo: .subheadline))
                        } else if scroll.preview.isEmpty {
                            Text("No further words.")
                                .font(scribe.body(16.5, italic: true, relativeTo: .subheadline))
                        } else {
                            Text(scroll.preview)
                                .font(scribe.body(16.5, relativeTo: .subheadline))
                        }
                    }
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)

                    HStack(spacing: 7) {
                        SmallCaps(ScribeDate.day(scroll.updatedAt))
                        dot
                        SmallCaps(ScribeDate.time(scroll.updatedAt, canonical: scribe.canonicalHours))
                        if !scroll.tome.isEmpty {
                            dot
                            SmallCaps(scroll.tome, color: scribe.rubric)
                        }
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 16)
            FadingRule()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var dot: some View {
        Circle()
            .fill(Palette.dim)
            .frame(width: 3, height: 3)
    }
}

/// Tome filter: small caps with a rubric underline and diamond when chosen.
struct TomeTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.scribe) private var scribe

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(Typeface.display(12.5, .semibold, relativeTo: .caption))
                    .tracking(1.8)
                    .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                ZStack {
                    Capsule()
                        .fill(scribe.rubric)
                        .frame(width: 26, height: 2)
                    Rectangle()
                        .fill(scribe.rubric)
                        .frame(width: 6, height: 6)
                        .rotationEffect(.degrees(45))
                }
                .scaleEffect(isSelected ? 1 : 0.01)
                .opacity(isSelected ? 1 : 0)
            }
            .frame(minHeight: 44)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The wax seal with a quill pressed into it: starts a new scroll.
struct NewScrollButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WaxSealImage(size: 86, emblem: .quill, seed: "new-scroll")
        }
        .buttonStyle(SealPressStyle())
        .accessibilityLabel("New scroll")
    }
}

private struct SealPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -4 : 0))
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct EmptyCodexView: View {
    @Environment(\.scribe) private var scribe

    var body: some View {
        VStack(spacing: 16) {
            IlluminatedInitial(letter: "S", size: 96)
            Text("Thy codex is empty")
                .font(Typeface.display(20, .semibold))
                .foregroundStyle(Palette.ink)
            Text("Press the wax seal below to begin thy first scroll.")
                .font(scribe.body(18, italic: true))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .allowsHitTesting(false)
    }
}
