import Testing
@testable import Trove

/// T011. Mirrors how `WishlistDeleteCopy`'s content is asserted in
/// `DeletionGuardTests` — promise-by-promise, case-insensitive, quoting the
/// message on failure — because the two copy sources make parallel claims
/// and should be guarded in parallel. The structural half (both item entry
/// points actually reading this) arrives with the call sites, T015/T017.
@Suite("Item delete copy")
struct ItemDeleteCopyTests {
    /// All three promises: the cascade, the sell-plan drop spec.md requires,
    /// and the permanence sentence carried over from the shipped alert.
    @Test func theMessageKeepsAllThreePromises() {
        let message = ItemDeleteCopy.message

        #expect(message.localizedCaseInsensitiveContains("photos"), "\(message)")
        #expect(message.localizedCaseInsensitiveContains("sell plan"), "\(message)")
        #expect(message.localizedCaseInsensitiveContains("undone"), "\(message)")
    }

    /// The two entities' sell-plan lines run in opposite directions — the
    /// wishlist item's deletion *spares* planned gear, the owned item's
    /// deletion *drops out* of plans — and both messages contain "sell
    /// plan", so the promise check above can't tell them apart. Pasting the
    /// wishlist's line in here would tell the user the exact opposite of
    /// the truth while every contains-check stays green.
    @Test func theSellPlanLineStatesTheDropNotTheSpare() {
        let message = ItemDeleteCopy.message

        #expect(message.localizedCaseInsensitiveContains("drops"), "\(message)")
        #expect(!message.localizedCaseInsensitiveContains("stays where it is"), "\(message)")
        #expect(message != WishlistDeleteCopy.message)
    }

    @Test func theConfirmButtonAndTitleSayDelete() {
        #expect(ItemDeleteCopy.confirm == "Delete")
        #expect(ItemDeleteCopy.title(for: "Leica M6") == "Delete Leica M6?")
    }
}
