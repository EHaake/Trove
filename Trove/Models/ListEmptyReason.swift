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

    /// The Items tab's Sold side is empty — nothing has been sold yet.
    ///
    /// Never returned by `reason(...)`: the Sold side has no narrowing to
    /// weigh (`ItemListViewModel.show(.sold)` clears all three filters), so
    /// its emptiness has exactly one cause and no precedence to settle.
    /// `ItemListViewModel.emptyReason` picks this case directly when the side
    /// is `.sold`, and `reason(...)` stays the rule for the narrowed sides.
    case nothingSold

    /// The collection may not all be here yet: CloudKit hasn't finished its
    /// first import on this device, so what's on screen is what has arrived
    /// rather than what exists. T048 measured that window at several minutes.
    case stillSyncing

    /// Appended to the empty states that survive mid-sync, since their claim
    /// is narrower but not truer — see the precedence note on `reason`.
    static let stillArrivingNote = "Your collection is still arriving from iCloud, so this may not be all of it."

    /// The detail line for an empty state that kept its case mid-import.
    ///
    /// Here rather than in each view so the two list screens can't drift on
    /// when the note appears, and so the rule is testable — a copy decision
    /// this easy to forget at one of four call sites shouldn't live only in
    /// a view.
    static func detail(_ base: String, mayStillBeImporting: Bool) -> String {
        mayStillBeImporting ? "\(base) \(stillArrivingNote)" : base
    }

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
    ///
    /// **Where `stillSyncing` sits, and why (T053).** It replaces the two
    /// cases that assert absence across the whole collection — `nothingAdded`
    /// and `everythingIsValued` — and yields to the two the user's own typing
    /// produced.
    ///
    /// The reasoning tasks.md proposed for that split doesn't survive
    /// contact: "no matches for *hasselblad*" mid-import is exactly the same
    /// kind of claim as "you own nothing," not a lesser one. Both assert
    /// absence over a collection the app hasn't finished receiving, and if
    /// the Hasselblad is among the items still in flight, both are false. The
    /// split is right for two other reasons:
    ///
    /// - **The filtered cases are feedback on an action taken a second ago.**
    ///   Replacing the result of what someone just typed with a message about
    ///   iCloud loses the connection between the two, and leaves them unsure
    ///   whether the search even ran.
    /// - **`categoryMatchedNothing` is close to unreachable mid-import
    ///   anyway**, because the chips are built from the items already fetched
    ///   — a category can't be offered until something in it has arrived.
    ///
    /// So they stay, and `stillArrivingNote` is appended to them instead:
    /// the narrower claim keeps its context and stops being stated as final.
    /// `everythingIsValued` doesn't get that treatment because it isn't a
    /// narrowing the user typed, it's a *success* claim about the whole
    /// collection — congratulating someone on a complete set of values that
    /// might be a third of their gear is the failure this phase is about.
    static func reason(
        totalCount: Int,
        visibleCount: Int,
        searchText: String,
        categoryFilter: String,
        showsOnlyUnvalued: Bool = false,
        mayStillBeImporting: Bool = false
    ) -> ListEmptyReason? {
        guard visibleCount == 0 else { return nil }
        guard totalCount > 0 else {
            return mayStillBeImporting ? .stillSyncing : .nothingAdded
        }

        let query = SearchMatching.normalized(searchText)
        if !query.isEmpty {
            return .searchMatchedNothing(query: searchText.trimmingCharacters(in: .whitespaces))
        }
        if showsOnlyUnvalued {
            return mayStillBeImporting ? .stillSyncing : .everythingIsValued
        }
        if !categoryFilter.isEmpty {
            return .categoryMatchedNothing
        }

        // Nothing narrowing, nothing showing, but the store isn't empty —
        // only reachable if a filter goes unaccounted for above. Falling back
        // to the collection-level copy is the safe wrong answer of the two.
        return mayStillBeImporting ? .stillSyncing : .nothingAdded
    }
}
