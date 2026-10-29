import SwiftData
import SwiftUI

/// Burned scrolls, kept for 30 days before they turn to dust.
struct AshesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scribe) private var scribe

    @Query(filter: #Predicate<Scroll> { $0.burnedAt != nil }, sort: \Scroll.updatedAt, order: .reverse)
    private var ashes: [Scroll]

    @State private var confirmEmpty = false

    var body: some View {
        List {
            Text("Burned scrolls rest here for thirty days. Restore one by swiping right.")
                .font(scribe.body(16, italic: true, relativeTo: .footnote))
                .foregroundStyle(Palette.muted)
                .listRowBackground(Palette.ground)
                .listRowSeparator(.hidden)

            ForEach(ashes) { scroll in
                VStack(alignment: .leading, spacing: 3) {
                    Text(scroll.displayTitle)
                        .font(scribe.body(19, .semibold, relativeTo: .headline))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(dustLine(scroll))
                        .font(Typeface.display(11, .regular, relativeTo: .caption))
                        .tracking(1.2)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.vertical, 6)
                .listRowBackground(Palette.ground)
                .listRowSeparatorTint(Palette.rule)
                .swipeActions(edge: .leading) {
                    Button {
                        restore(scroll)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(scribe.rubric)
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
        .background(Palette.ground.ignoresSafeArea())
        .overlay {
            if ashes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "flame")
                        .font(.system(size: 34))
                        .foregroundStyle(Palette.gold)
                    Text("The hearth is cold")
                        .font(Typeface.display(18))
                        .foregroundStyle(Palette.ink)
                    Text("No scroll has been burned.")
                        .font(scribe.body(17, italic: true))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .navigationTitle("The Ashes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Empty", role: .destructive) { confirmEmpty = true }
                    .disabled(ashes.isEmpty)
            }
        }
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
        let days = scroll.daysUntilDust
        switch days {
        case 0: return "TURNS TO DUST TODAY"
        case 1: return "TURNS TO DUST TOMORROW"
        default: return "TURNS TO DUST IN \(days) DAYS"
        }
    }
}
