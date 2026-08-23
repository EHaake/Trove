import SwiftData
import SwiftUI

@main
struct TroveApp: App {
    private let store: TroveStore
    private let syncMonitor: SyncMonitor

    /// Set by the UI test target so each run starts from a genuinely fresh
    /// install rather than whatever the last run left in the simulator.
    ///
    /// A test-only branch in shipping code is worth being uneasy about, so:
    /// the alternative is a UI test whose starting state is ambient, which
    /// would pass or fail depending on data no one in the test can see. That's
    /// the failure mode CLAUDE.md's "a passing test is not evidence it can
    /// fail" rule is about, arriving from the other direction. One flag, read
    /// in one place, is the smaller cost.
    ///
    /// It can only ever *lose* data, never expose any, and `ProcessInfo`
    /// launch arguments aren't settable on a shipped app.
    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    init() {
        do {
            // Which of the three configurations this is, and what happens when
            // CloudKit won't load, lives in `TroveStore` — the decisions are
            // worth testing, and a `ModelContainer` built inline in an `App`
            // initialiser can't be.
            store = try TroveStore.make(isUITesting: Self.isUITesting)
            // Built from the mode rather than independently: a store with no
            // CloudKit mirror has nothing to wait for, and the monitor is
            // what keeps every empty state from having to know that.
            syncMonitor = SyncMonitor(mode: store.mode)
        } catch {
            // Reachable only once the CloudKit configuration has already
            // failed and been retried without it, so the remaining causes are
            // about the disk rather than about sync. There's genuinely nothing
            // left to fall back to: an in-memory store would look like the app
            // silently forgetting the user's collection, which is worse than
            // failing loudly.
            fatalError("Could not create the model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, .dark)
                // What the store actually turned out to be, for the views
                // that say so out loud — the save bars' captions (T049a).
                .environment(\.storageMode, store.mode)
                // How far along this device's copy is, for the empty states
                // that would otherwise claim an unfinished import is an empty
                // collection (Phase 12).
                .environment(syncMonitor)
                // v1 is dark-only (spec.md defers light mode), and pinning the
                // scheme keeps system-drawn chrome — keyboards, pickers,
                // selection — matching the palette instead of fighting it.
                .preferredColorScheme(.dark)
        }
        .modelContainer(store.container)
    }
}
