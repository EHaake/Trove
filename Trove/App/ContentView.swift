import SwiftData
import SwiftUI

/// Placeholder shell, replaced by the real root `TabView` in T042.
///
/// Until then it hosts whichever Phase 4 screen was built last, so each one
/// can be checked against `design/screens/` on a real device rather than only
/// in a preview.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ItemListView(modelContext: modelContext)
        }
        .task { seedCategoriesIfNeeded() }
    }

    /// Sample gear so the list, filters and totals have something real to show
    /// on a fresh install. Harness-only; it goes away with this view at T042.
    private func seedCategoriesIfNeeded() {
        let existing = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        guard existing.isEmpty else { return }

        let samples: [(String, String, Int, Int?, Int)] = [
            ("Leica M6 (0.72x)", "Photography/Cameras", 290_000, 345_000, 5),
            ("Hasselblad 500C/M", "Photography/Cameras", 125_000, 178_000, 5),
            ("Nikon 105mm f/2.5 Ai-S", "Photography/Lenses", 24_000, 31_000, 4),
            ("Fender Blues Junior IV", "Music/Amps", 69_000, 54_000, 2),
            ("Squier Classic Vibe 50s", "Music/Guitars/Electric", 34_900, 38_000, 1),
            ("Sennheiser HD 600", "Audio/Headphones", 39_900, nil, 3),
            // Collides with Music/Amps at the leaf, so both chips widen.
            ("Schiit Vali 2++", "Audio/Amps", 14_900, 12_000, 3),
        ]

        for (name, path, paid, worth, desire) in samples {
            modelContext.insert(
                Item(
                    name: name,
                    categoryPath: path,
                    purchasePriceCents: paid,
                    currentValueCents: worth,
                    desireToKeep: desire
                )
            )
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .environment(\.theme, .dark)
        .modelContainer(for: TroveSchema.models, inMemory: true)
}
