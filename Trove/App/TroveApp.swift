import SwiftData
import SwiftUI

@main
struct TroveApp: App {
    private let modelContainer: ModelContainer

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
            // Local-only: no `cloudKitDatabase:` argument, because T002 is
            // deferred pending a paid Developer Program membership. The schema
            // already satisfies CloudKit's rules (CloudKitSchemaTests proves
            // it), so enabling sync later means adding the configuration here
            // and handling the not-signed-in case — not a migration.
            modelContainer = try ModelContainer(
                for: TroveSchema.schema,
                configurations: ModelConfiguration(
                    schema: TroveSchema.schema,
                    isStoredInMemoryOnly: Self.isUITesting
                )
            )
        } catch {
            // Nothing sensible to fall back to: an in-memory store would look
            // like the app silently forgetting the user's collection, which is
            // worse than failing loudly. Revisit if this ever shows up in the
            // wild.
            fatalError("Could not create the model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, .dark)
                // v1 is dark-only (spec.md defers light mode), and pinning the
                // scheme keeps system-drawn chrome — keyboards, pickers,
                // selection — matching the palette instead of fighting it.
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
