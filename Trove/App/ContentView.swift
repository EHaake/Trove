import SwiftData
import SwiftUI

/// The app's root: four tabs, each its own `NavigationStack`.
///
/// The fourth, Plans, is `009-sell-plan-list`'s: every sell plan in one
/// place, Active and Completed, where before a plan was only reachable from
/// the wishlist item it funds. It pushes `SellPlanView` on its own stack
/// (`plansPath`) so the dashboard can land on it the way it lands on Items.
///
/// Separate stacks matter: the dashboard drills into scoped copies of itself
/// and the item list pushes item detail, and neither should end up on the
/// other's stack. `AppRouter` is what lets the dashboard's two actions land in
/// the Items tab without either screen reaching into the other.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @Environment(SyncMonitor.self) private var syncMonitor

    @State private var router = AppRouter()

    var body: some View {
        // Design's four marks, not SF Symbols: a tachometer for the dashboard,
        // a 2×2 grid for items, three ramping bars for the wishlist that
        // echo `DesireGauge` on purpose, and for plans a faint square joined by
        // an arrow to a solid one — gear funding a want. Each is a single
        // template-rendered glyph, so the tint below draws both states and
        // there's no separate selected variant to keep in step with this one.
        TabView(selection: $router.selectedTab) {
            Tab("Overview", image: "TabDashboard", value: AppRouter.Tab.overview) {
                NavigationStack { DashboardView(modelContext: modelContext, syncMonitor: syncMonitor) }
            }
            Tab("Items", image: "TabItems", value: AppRouter.Tab.items) {
                NavigationStack(path: $router.itemsPath) {
                    ItemListView(modelContext: modelContext, syncMonitor: syncMonitor)
                }
            }
            Tab("Wishlist", image: "TabWishlist", value: AppRouter.Tab.wishlist) {
                NavigationStack { WishlistView(modelContext: modelContext, syncMonitor: syncMonitor) }
            }
            Tab(SellPlanCopy.tab, image: "TabPlans", value: AppRouter.Tab.plans) {
                NavigationStack(path: $router.plansPath) {
                    PlansView(modelContext: modelContext, syncMonitor: syncMonitor)
                }
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
        .environment(SyncMonitor.notSyncing)
        .modelContainer(for: TroveSchema.allModels, inMemory: true)
}
