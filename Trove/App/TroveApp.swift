import SwiftData
import SwiftUI

@main
struct TroveApp: App {
    private let store: TroveStore
    private let syncMonitor: SyncMonitor
    private let appearanceStore: AppearanceStore

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
            // The appearance choice lives in `UserDefaults`, read synchronously
            // so the first frame draws in the right palette. Under the in-memory
            // (`.ephemeral`) store a UI-test launch built, it reads from a
            // volatile, isolated suite so each run starts from Dark regardless
            // of what a previous run left — gated structurally on the mode of
            // the store that was actually built (the `UITestSeed` pattern), not
            // on a second read of the launch argument, so a persistent-store
            // launch can never pick up the volatile suite (plan.md §7, Q8).
            let appearanceDefaults: UserDefaults
            if store.mode == .ephemeral {
                let suiteName = "TroveUITests.appearance"
                let suite = UserDefaults(suiteName: suiteName)!
                // Wipe: `UserDefaults(suiteName:)` persists on disk, so an
                // unwiped suite could leak a prior run's choice into this one.
                suite.removePersistentDomain(forName: suiteName)
                appearanceDefaults = suite
            } else {
                appearanceDefaults = .standard
            }
            appearanceStore = AppearanceStore(defaults: appearanceDefaults)
            // 011: sweep whatever the previous session's share sheet left
            // staged — the launch half of criterion 10's "no residue"; the
            // per-export half lives in FileExportService.stage.
            FileExportService.purgeAtLaunch()
            // 003: the Sell Plan's seeded market history, for the one UI test
            // that needs a rising, a flat, a neutral and a falling candidate.
            // Gated on the store that was actually built being the in-memory
            // one — not on a second read of the launch argument above — so it
            // can only ever add rows to a test launch's own stores.
            if UITestSeed.shouldSeed(mode: store.mode, arguments: ProcessInfo.processInfo.arguments) {
                // Loud on purpose, and reachable only on a test launch: a seed
                // that half-wrote would leave the test asserting against a
                // collection nobody described.
                do {
                    try UITestSeed.sellPlan(into: store.container.mainContext, now: .now)
                } catch {
                    fatalError("Could not seed the UI test's collection: \(error)")
                }
            }
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
            // The palette and preferred colour scheme are no longer hardcoded
            // here: `ThemedRoot` drives both from the appearance choice, so a
            // choice change re-themes the whole app with no relaunch and a
            // device flip follows under `.system` (spec 004, plan.md §4, Q5).
            ThemedRoot(appearanceStore: appearanceStore) {
                ContentView()
                    // What the store actually turned out to be, for the views
                    // that say so out loud — the save bars' captions (T049a).
                    .environment(\.storageMode, store.mode)
                    // 013: why that mode isn't `.cloudKit`, when it isn't — the
                    // Settings screen's iCloud row is the first reader the
                    // store's recorded reason has had since 001.
                    .environment(\.storageFallbackReason, store.cloudKitFailure?.localizedDescription)
                    // How far along this device's copy is, for the empty states
                    // that would otherwise claim an unfinished import is an empty
                    // collection (Phase 12).
                    .environment(syncMonitor)
                    // The appearance choice, for Settings to read and change.
                    .environment(appearanceStore)
            }
        }
        .modelContainer(store.container)
    }
}
