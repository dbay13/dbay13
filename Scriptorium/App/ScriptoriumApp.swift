import SwiftData
import SwiftUI

@main
struct ScriptoriumApp: App {
    @State private var sealKeeper = SealKeeper()
    @State private var herald = Herald()

    init() {
        FontRegistrar.registerBundledFonts()
        ChromeAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sealKeeper)
                .environment(herald)
        }
        .modelContainer(for: Scroll.self)
    }
}

struct RootView: View {
    @AppStorage(SettingsKey.parchment) private var parchment: Parchment = .vellum
    @AppStorage(SettingsKey.hasSeenWelcome) private var hasSeenWelcome = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(SealKeeper.self) private var sealKeeper

    var body: some View {
        ScrollsView()
            .overlay(alignment: .bottom) {
                HeraldBanner()
                    .padding(.bottom, 110)
            }
            .scribeStyle()
            .fullScreenCover(isPresented: showWelcome) {
                WelcomeView { hasSeenWelcome = true }
                    .scribeStyle()
            }
            .overlay {
                // Hide open sealed scrolls from the app switcher.
                if scenePhase != .active && sealKeeper.hasOpenSeals {
                    PrivacyCover()
                        .scribeStyle()
                }
            }
            .onAppear {
                WindowStyler.apply(parchment)
            }
            .onChange(of: parchment) { _, newValue in
                WindowStyler.apply(newValue)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    sealKeeper.resealAll()
                }
                if phase == .active {
                    WindowStyler.apply(parchment)
                }
            }
            .task {
                Housekeeping.seedIfNeeded(modelContext)
                Housekeeping.sweepAshes(modelContext)
            }
    }

    private var showWelcome: Binding<Bool> {
        Binding(
            get: { !hasSeenWelcome },
            set: { isShown in hasSeenWelcome = !isShown }
        )
    }
}

private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            ParchmentBackground()
            WaxSealImage(size: 132, seed: "privacy")
        }
    }
}
