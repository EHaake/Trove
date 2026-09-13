import Testing
@testable import Trove

/// The rule that decides which of four things an empty list says.
///
/// Worth its own suite because getting it wrong is invisible in code review and
/// obvious to a user: "add your first piece" shown to someone with forty items
/// who mistyped a search reads as the app having lost their collection.
@Suite("List empty reason")
struct ListEmptyReasonTests {
    // MARK: - Not empty

    @Test func aListWithRowsHasNoReason() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 3,
                searchText: "leica",
                categoryFilter: "Photography"
            ) == nil
        )
    }

    // MARK: - The precedence that matters

    /// The case this precedence exists for. An empty store plus a query in the
    /// field is *both* "nothing added" and "nothing matches" — and offering to
    /// clear a search that would reveal nothing is a dead end.
    @Test func anEmptyCollectionOutranksASearchThatMatchedNothing() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 0,
                visibleCount: 0,
                searchText: "leica",
                categoryFilter: ""
            ) == .nothingAdded
        )
    }

    @Test func anEmptyCollectionOutranksACategoryFilter() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 0,
                visibleCount: 0,
                searchText: "",
                categoryFilter: "Photography/Cameras"
            ) == .nothingAdded
        )
    }

    /// Search beats the other narrowings: it's the one the user typed most
    /// recently, so it's the one to point at.
    @Test func searchOutranksTheOtherFilters() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 0,
                searchText: "zzz",
                categoryFilter: "Photography",
                showsOnlyUnvalued: true
            ) == .searchMatchedNothing(query: "zzz")
        )
    }

    @Test func theUnvaluedFilterOutranksTheCategoryFilter() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 0,
                searchText: "",
                categoryFilter: "Photography",
                showsOnlyUnvalued: true
            ) == .everythingIsValued
        )
    }

    // MARK: - Each case on its own

    @Test func nothingAddedWhenTheCollectionIsEmpty() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 0,
                visibleCount: 0,
                searchText: "",
                categoryFilter: ""
            ) == .nothingAdded
        )
    }

    @Test func aCategoryThatHoldsNothing() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 0,
                searchText: "",
                categoryFilter: "Photography/Cameras"
            ) == .categoryMatchedNothing
        )
    }

    /// The state that made this a four-case problem: value the last un-valued
    /// item from the dashboard's callout and the filtered list empties. That's
    /// the callout succeeding, and it used to report "nothing here yet".
    @Test func valuingTheLastItemEmptiesTheUnvaluedFilter() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 0,
                searchText: "",
                categoryFilter: "",
                showsOnlyUnvalued: true
            ) == .everythingIsValued
        )
    }

    /// `.nothingSold` is not `reason(...)`'s to hand back. An empty Owned side
    /// with nothing narrowing it is `nothingAdded`, exactly as before the Sold
    /// side existed — the Sold side's case is chosen by
    /// `ItemListViewModel.emptyReason` alone, so a bug there can't be masked by
    /// this rule quietly agreeing.
    @Test func anEmptyUnnarrowedListIsNothingAddedNotNothingSold() {
        let reason = ListEmptyReason.reason(
            totalCount: 0,
            visibleCount: 0,
            searchText: "",
            categoryFilter: ""
        )

        #expect(reason == .nothingAdded)
        #expect(reason != .nothingSold)
    }

    // MARK: - The query it hands back

    /// The headline quotes it back, so it has to be what was typed, not the
    /// normalized form used for matching.
    @Test func theQueryComesBackTrimmedButNotNormalized() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 0,
                searchText: "  Leica M6  ",
                categoryFilter: ""
            ) == .searchMatchedNothing(query: "Leica M6")
        )
    }

    /// Whitespace isn't a search. Without this, clearing a query down to a
    /// space would offer "clear search" on a field that already looks clear.
    @Test func whitespaceAloneIsNotASearch() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 8,
                visibleCount: 0,
                searchText: "   ",
                categoryFilter: "Photography"
            ) == .categoryMatchedNothing
        )
    }
}
