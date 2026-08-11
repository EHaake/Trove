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
    }

    var selectedTab: Tab = .overview

    /// Items pushed onto the Items tab's stack, by id.
    var itemsPath: [UUID] = []

    private(set) var itemsRequest: ItemsRequest?

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
