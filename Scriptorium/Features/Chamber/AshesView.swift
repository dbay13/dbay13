import SwiftData
import SwiftUI

/// Burned scrolls, kept for 30 days before they turn to dust.
struct AshesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scribe) private var scribe
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Scroll> { $0.burnedAt != nil }, sort: \Scroll.updatedAt, order: .reverse)
    private var ashes: [Scroll]

    @State private var confirmEmpty = false

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 4) {
                Text("The Ashes")
                    .font(Typeface.display(30, .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Burned scrolls rest here for thirty days, then turn to dust. Swipe right to restore one.")
                    .font(scribe.body(16, italic: true, relativeTo: .footnote))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.bottom, 8)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(ashes) { scroll in
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: "flame")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.dim)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scroll.displayTitle)
                                .font(scribe.body(19, .semibold, relativeTo: .headline))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            SmallCaps(dustLine(scroll))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 14)
                    FadingRule()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading) {
                    Button {
                        restore(scroll)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(scribe.ink.deep)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(scroll)
                    } label: {
                        Label("Destroy", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        restore(scroll)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(scroll)
                    } label: {
                        Label("Destroy forever", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ParchmentBackground())
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    GlassBackLabel(title: "Chamber")
                }
                .buttonStyle(GlassButtonStyle())
                Spacer()
                Button("Empty") { confirmEmpty = true }
                    .font(scribe.body(18, .semibold))
                    .foregroundStyle(ashes.isEmpty ? Palette.dim : Palette.ember)
                    .frame(minHeight: 44)
                    .disabled(ashes.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .overlay {
            if ashes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "flame")
                        .font(.system(size: 36))
                        .foregroundStyle(Palette.dim)
                    Text("The hearth is cold")
                        .font(Typeface.display(19, .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("No scroll has been burned.")
                        .font(scribe.body(17, italic: true))
                        .foregroundStyle(Palette.muted)
                }
                .allowsHitTesting(false)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Destroy every burned scroll?", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("Destroy forever", role: .destructive) {
                for scroll in ashes {
                    modelContext.delete(scroll)
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func restore(_ scroll: Scroll) {
        withAnimation {
            scroll.burnedAt = nil
            scroll.updatedAt = .now
        }
    }

    private func dustLine(_ scroll: Scroll) -> String {
        switch scroll.daysUntilDust {
        case 0: return "Turns to dust today"
        case 1: return "Turns to dust tomorrow"
        case let days: return "Dust in \(ScribeDate.spelled(days).lowercased()) days"
        }
    }
}
