import SwiftData
import SwiftUI

@main
struct TroveApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            // Local-only: no `cloudKitDatabase:` argument, because T002 is
            // deferred pending a paid Developer Program membership. The schema
            // already satisfies CloudKit's rules (CloudKitSchemaTests proves
            // it), so enabling sync later means adding the configuration here
            // and handling the not-signed-in case — not a migration.
            modelContainer = try ModelContainer(for: TroveSchema.schema)
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
