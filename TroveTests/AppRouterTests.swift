import Foundation
import Testing
@testable import Trove

@Suite("AppRouter")
struct AppRouterTests {
    @Test func startsOnTheOverviewTabWithNothingPending() {
        let router = AppRouter()

        #expect(router.selectedTab == .overview)
        #expect(router.itemsPath.isEmpty)
        #expect(router.itemsRequest == nil)
    }

    @Test func showingACategorySwitchesTabsAndAsksForThatCategory() {
        let router = AppRouter()
        router.showItems(inCategory: "Photography/Cameras")

        #expect(router.selectedTab == .items)
        #expect(router.itemsRequest == .category("Photography/Cameras"))
    }

    @Test func showingUnvaluedItemsSwitchesTabsAndAsksForThem() {
        let router = AppRouter()
        router.showUnvaluedItems()

        #expect(router.selectedTab == .items)
        #expect(router.itemsRequest == .unvalued)
    }

    @Test func showingOneItemPushesItOntoTheItemsStack() {
        let router = AppRouter()
        let id = UUID()
        router.showItem(id)

        #expect(router.selectedTab == .items)
        #expect(router.itemsPath == [id])
    }

    /// Arriving at a filtered list while an item screen is still on the stack
    /// would leave the user looking at the item, not the list they asked for.
    @Test func askingForAListPopsAnyItemAlreadyPushed() {
        let router = AppRouter()
        router.showItem(UUID())
        #expect(router.itemsPath.count == 1)

        router.showItems(inCategory: "Music/Amps")
        #expect(router.itemsPath.isEmpty)

        router.showItem(UUID())
        router.showUnvaluedItems()
        #expect(router.itemsPath.isEmpty)
    }

    /// Jumping straight to an item must not leave a filter queued behind it —
    /// backing out would land on a narrowed list the user never asked for.
    @Test func openingAnItemClearsAnyPendingFilter() {
        let router = AppRouter()
        router.showUnvaluedItems()
        router.showItem(UUID())

        #expect(router.itemsRequest == nil)
    }

    /// The list clears the request once it has applied it, so coming back to
    /// the tab later doesn't silently re-narrow what the user has since changed.
    @Test func aRequestIsClearedOnceApplied() {
        let router = AppRouter()
        router.showItems(inCategory: "Music/Amps")
        router.clearItemsRequest()

        #expect(router.itemsRequest == nil)
        // Clearing the request is not the same as leaving the tab.
        #expect(router.selectedTab == .items)
    }

    @Test func aLaterRequestReplacesAnEarlierOne() {
        let router = AppRouter()
        router.showItems(inCategory: "Music/Amps")
        router.showUnvaluedItems()

        #expect(router.itemsRequest == .unvalued)
    }
}
