import Foundation
import SwiftData

enum Housekeeping {
    /// Adds a welcome scroll the first time the app opens.
    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: SettingsKey.didSeed) else { return }
        defaults.set(true, forKey: SettingsKey.didSeed)

        let welcome = Scroll(
            text: """
            Welcome to thy Scriptorium
            This is a scroll. Its first line is the title; everything beneath is thine to write. There are no folders to tend and nothing to save. Write, and it is kept.
            ☐ Tap a box to tick it off
            ☐ Press the red seal on the home screen for a new scroll
            ☐ Swipe a scroll to the left to burn it
            ❦
            Burned scrolls rest in the Ashes for thirty days. Light the candle above to begin a vigil, a quiet stretch of writing with nothing else on the page.
            """,
            tome: "Musings"
        )
        context.insert(welcome)
    }

    /// Destroys scrolls that have rested in the Ashes for more than 30 days.
    static func sweepAshes(_ context: ModelContext) {
        let cutoff = Date.now.addingTimeInterval(-Scroll.ashesLifetime)
        let descriptor = FetchDescriptor<Scroll>(predicate: #Predicate { $0.burnedAt != nil })
        guard let burned = try? context.fetch(descriptor) else { return }
        for scroll in burned where (scroll.burnedAt ?? .now) < cutoff {
            context.delete(scroll)
        }
    }
}
