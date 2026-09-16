import Foundation
import Observation

/// Which tab is showing, and anything one tab has asked another to do.
///
/// Exists because the dashboard's two actions land in the Items tab: drilling
/// into a leaf category, and following the un-valued callout. Neither could be
/// built before the real `TabView` (T042) — a tab can't push onto a stack it
/// doesn't own — so both were deferred here rather than rigged against the
/// Phase 5 stand-in.
///
/// Holds `[UUID]` rather than a `NavigationPath` so it stays free of SwiftUI,
/// per CLAUDE.md; `ContentView` binds the array to the Items tab's stack, which
/// works because `UUID` is `Hashable`.
@Observable
final class AppRouter {
    enum Tab: String, Hashable, CaseIterable {
        case overview
        case items
        case wishlist
    }

    /// What the Items tab should be showing when it next appears.
    ///
    /// A request rather than a direct write: the router doesn't own
    /// `ItemListViewModel`, and reaching across to set its filter would put
    /// navigation in charge of another screen's state. `ItemListView` applies
    /// this and clears it.
    enum ItemsRequest: Hashable {
        case category(String)
        case unvalued
        /// Show the Items tab's Sold side. Carries nothing: the Sold side has
        /// no narrowing to ask for (`show(.sold)` clears all of it), so the
        /// request is the whole message.
        case sold
    }

    var selectedTab: Tab = .overview

    /// Items pushed onto the Items tab's stack, by id.
    var itemsPath: [UUID] = []

    private(set) var itemsRequest: ItemsRequest?

    /// Set when another screen has asked for the add-item form. `ItemListView`
    /// owns that sheet — it has to, so dismissing it can refetch the list — so
    /// this is how the dashboard's empty state reaches it.
    ///
    /// A flag the destination clears, rather than an `ItemsRequest` case: the
    /// requests narrow a list that's already showing, while this opens
    /// something on top of it. Folding them together would mean every caller
    /// reading "request" had to know which kind it got.
    private(set) var wantsAddItemForm = false

    // MARK: - Intents

    /// Show the Items tab narrowed to one category.
    func showItems(inCategory path: String) {
        itemsRequest = .category(path)
        popToItemsRoot()
    }

    /// Show the Items tab narrowed to what hasn't been valued yet.
    func showUnvaluedItems() {
        itemsRequest = .unvalued
        popToItemsRoot()
    }

    /// Show the Items tab's Sold side.
    ///
    /// The Dashboard's Sold card is the caller. Pops the same way the
    /// narrowing requests do — arriving at an item screen when you asked for
    /// a list is the same wrong place whichever side the list is on.
    func showSoldItems() {
        itemsRequest = .sold
        popToItemsRoot()
    }

    /// Open one item directly.
    ///
    /// The un-valued callout uses this when only one item is un-valued: a
    /// filtered list holding a single row costs a tap to get through and
    /// arrives at the same place. Decided at the Phase 7 review; see plan.md.
    func showItem(_ id: UUID) {
        // Clears any pending filter, so returning to the list behind this
        // screen shows the whole collection rather than a filter the user
        // never saw applied.
        itemsRequest = nil
        selectedTab = .items
        itemsPath = [id]
    }

    /// Open the add-item form, from wherever the user is.
    ///
    /// The dashboard's first-run empty state is the only caller: `design/brief.md`
    /// asks empty states to point at the add action, and landing someone on a
    /// second empty screen with its own button would be pointing at a pointer.
    /// Clears any pending narrowing for the same reason `showItem` does —
    /// arriving at a filtered list you never asked for is worse than arriving
    /// at all of them.
    func startAddingItem() {
        itemsRequest = nil
        wantsAddItemForm = true
        popToItemsRoot()
    }

    /// Called by `ItemListView` once the form is open, so returning to the tab
    /// later doesn't reopen it.
    func clearAddItemRequest() {
        wantsAddItemForm = false
    }

    /// Called by `ItemListView` once it has applied the request, so a later
    /// re-appearance doesn't silently re-narrow a list the user has since
    /// changed.
    func clearItemsRequest() {
        itemsRequest = nil
    }

    private func popToItemsRoot() {
        selectedTab = .items
        itemsPath = []
    }
}
