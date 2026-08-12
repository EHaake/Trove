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
    @Environment(\.theme) private var theme

    @State private var router = AppRouter()

    var body: some View {
        // Design's three marks, not SF Symbols: a tachometer for the dashboard,
        // a 2×2 grid for items, and three ramping bars for the wishlist that
        // echo `DesireGauge` on purpose. Each is a single template-rendered
        // glyph, so the tint below draws both states and there's no separate
        // selected variant to keep in step with this one.
        TabView(selection: $router.selectedTab) {
            Tab("Overview", image: "TabDashboard", value: AppRouter.Tab.overview) {
                NavigationStack { DashboardView(modelContext: modelContext) }
            }
            Tab("Items", image: "TabItems", value: AppRouter.Tab.items) {
                NavigationStack(path: $router.itemsPath) {
                    ItemListView(modelContext: modelContext)
                }
            }
            Tab("Wishlist", image: "TabWishlist", value: AppRouter.Tab.wishlist) {
                NavigationStack { WishlistView(modelContext: modelContext) }
            }
        }
        // The selected tab was drawing in the system blue, which is the one
        // thing on screen that isn't from `tokens.md`.
        .tint(theme.colors.accentBrass)
        .environment(router)
    }
}

#Preview {
    ContentView()
        .environment(\.theme, .dark)
        .modelContainer(for: TroveSchema.models, inMemory: true)
}
