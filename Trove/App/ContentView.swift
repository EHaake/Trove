import SwiftData
import SwiftUI

/// The app's root: three tabs, each its own `NavigationStack`.
///
/// Three, not four. A Sell Plan tab came up at the Phase 7 review and is
/// deferred to its own spec (`009-sell-plan-list` in ROADMAP.md) — it's a new,
/// undesigned screen rather than a rearrangement of these.
///
/// Separate stacks matter: the dashboard drills into scoped copies of itself
/// and the item list pushes item detail, and neither should end up on the
/// other's stack. `AppRouter` is what lets the dashboard's two actions land in
/// the Items tab without either screen reaching into the other.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var router = AppRouter()

    /// Seeding has to finish before any screen loads, or the first one to
    /// appear fetches an empty store and shows an empty state over real data.
    /// A `.task` on the container loses that race.
    @State private var hasSeeded = false

    var body: some View {
        Group {
            if hasSeeded {
                TabView(selection: $router.selectedTab) {
                    Tab("Overview", systemImage: "circle.circle", value: AppRouter.Tab.overview) {
                        NavigationStack { DashboardView(modelContext: modelContext) }
                    }
                    Tab("Items", systemImage: "square", value: AppRouter.Tab.items) {
                        NavigationStack(path: $router.itemsPath) {
                            ItemListView(modelContext: modelContext)
                        }
                    }
                    Tab("Wishlist", systemImage: "circle.dashed", value: AppRouter.Tab.wishlist) {
                        NavigationStack { WishlistView(modelContext: modelContext) }
                    }
                }
            } else {
                Color.clear
            }
        }
        .environment(router)
        .onAppear {
            guard !hasSeeded else { return }
            seedCategoriesIfNeeded()
            hasSeeded = true
        }
    }

    /// Sample gear so the list, filters and totals have something real to show
    /// on a fresh install.
    ///
    /// Still here after T042 replaced the harness around it: there's no
    /// onboarding or import yet, so a fresh install with an empty store can't
    /// exercise any of these screens. Goes away when T045's empty states give
    /// a real first-run experience to land on.
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
            // A fourth top-level category, so the dashboard breakdown runs off
            // the end of the three accent swatches onto the neutral, and one
            // filed with no sub-category, which can't be drilled into.
            ("Peak Design Everyday", "Accessories", 22_000, 16_000, 4),
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

        let wanted: [(String, String, Int, String?, Int)] = [
            ("Leica Summicron 35mm f/2 (v4)", "Photography/Lenses", 240_000, "v4 only, no haze", 3),
            ("Vox AC15 Custom", "Music/Amps", 105_000, nil, 1),
            ("Hasselblad 80mm f/2.8 CF", "Photography/Lenses", 95_000, nil, 2),
            ("Focal Clear MG", "Audio/Headphones", 149_000, "Open-back, used is fine", 2),
        ]

        for (index, entry) in wanted.enumerated() {
            modelContext.insert(
                WishlistItem(
                    name: entry.0,
                    categoryPath: entry.1,
                    estimatedCostCents: entry.2,
                    notes: entry.3,
                    desireToOwn: entry.4,
                    sortOrder: index
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
