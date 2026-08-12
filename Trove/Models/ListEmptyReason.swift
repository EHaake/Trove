import Foundation

/// Why a browsing list is showing nothing.
///
/// The two list screens each have four of these, not the one an "empty state"
/// usually implies, and they want different words: an empty collection is an
/// invitation to add something, while a filter that excluded everything is an
/// invitation to widen it. Telling someone with forty items to "add your first
/// piece" because they typed a typo is the failure this type exists to prevent.
///
/// Derived here rather than in the view because it's a rule about the data, not
/// about layout — the same reasoning that moved the photo sort into
/// `ItemDetailViewModel`. Both list view models call `reason(...)`, so the two
/// screens can't drift into disagreeing about which case they're in.
enum ListEmptyReason: Equatable {
    /// The collection itself is empty — no filter is involved.
    case nothingAdded
    /// A query is in the field and nothing matches it.
    case searchMatchedNothing(query: String)
    /// A category chip is selected and nothing sits under it.
    case categoryMatchedNothing
    /// The un-valued filter is on and everything has a value. Items only —
    /// the wishlist has no such filter. Worth its own case because it's the
    /// *success* end of the dashboard's "Value →" callout, not a dead end:
    /// value the last item and this is what you land on.
    case everythingIsValued

    /// Which case a list is in, or `nil` when it isn't empty at all.
    ///
    /// - Parameters:
    ///   - totalCount: items before any narrowing.
    ///   - visibleCount: items after all of it.
    ///
    /// Precedence is deliberate and tested. `nothingAdded` outranks everything
    /// because a filter can't be the reason a collection of zero is empty —
    /// "nothing matches that" is technically true of an empty store and useless
    /// to read. Search comes next, being the narrowing the user typed most
    /// recently. The un-valued filter and the category filter can't currently
    /// both be on (`AppRouter` clears one when it sets the other), but they're
    /// ordered anyway so the answer never depends on that staying true.
    static func reason(
        totalCount: Int,
        visibleCount: Int,
        searchText: String,
        categoryFilter: String,
        showsOnlyUnvalued: Bool = false
    ) -> ListEmptyReason? {
        guard visibleCount == 0 else { return nil }
        guard totalCount > 0 else { return .nothingAdded }

        let query = SearchMatching.normalized(searchText)
        if !query.isEmpty {
            return .searchMatchedNothing(query: searchText.trimmingCharacters(in: .whitespaces))
        }
        if showsOnlyUnvalued {
            return .everythingIsValued
        }
        if !categoryFilter.isEmpty {
            return .categoryMatchedNothing
        }

        // Nothing narrowing, nothing showing, but the store isn't empty —
        // only reachable if a filter goes unaccounted for above. Falling back
        // to the collection-level copy is the safe wrong answer of the two.
        return .nothingAdded
    }
}
