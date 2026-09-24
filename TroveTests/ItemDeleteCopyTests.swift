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
        let message = ItemDeleteCopy.message(isSold: false, picturesACompletedPlan: false)

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
        let message = ItemDeleteCopy.message(isSold: false, picturesACompletedPlan: false)

        #expect(message.localizedCaseInsensitiveContains("drops"), "\(message)")
        #expect(!message.localizedCaseInsensitiveContains("stays where it is"), "\(message)")
        #expect(message != WishlistDeleteCopy.message)
    }

    /// 006, P13: a sold item is on no plan, so its message drops the
    /// sell-plan sentence and keeps the other two promises. Reusing the owned
    /// message here — the tempting shortcut, since every other promise is the
    /// same — turns this red (G17).
    @Test func theSoldMessageDropsTheSellPlanLineAndKeepsTheRest() {
        let message = ItemDeleteCopy.message(isSold: true, picturesACompletedPlan: false)

        #expect(message.localizedCaseInsensitiveContains("photos"), "\(message)")
        #expect(message.localizedCaseInsensitiveContains("undone"), "\(message)")
        #expect(!message.localizedCaseInsensitiveContains("sell plan"), "\(message)")
        #expect(message != ItemDeleteCopy.message(isSold: false, picturesACompletedPlan: false), "\(message)")
    }

    /// 009 T021a: every branch, whole. The completed-plan clause appears
    /// only when the item is the picture a completed plan shows, on either
    /// side; without it both messages are byte for byte what they were.
    @Test func theCompletedPlanClauseAppearsOnlyForABoughtItem() {
        #expect(
            ItemDeleteCopy.message(isSold: false, picturesACompletedPlan: false)
                == "Its photos go too. Any sell plan it's on drops it. This can't be undone."
        )
        #expect(
            ItemDeleteCopy.message(isSold: false, picturesACompletedPlan: true)
                == "Its photos go too. Any sell plan it's on drops it, "
                + "and the completed plan it was bought for loses its picture. This can't be undone."
        )
        #expect(
            ItemDeleteCopy.message(isSold: true, picturesACompletedPlan: false)
                == "Its photos go too. This can't be undone."
        )
        #expect(
            ItemDeleteCopy.message(isSold: true, picturesACompletedPlan: true)
                == "Its photos go too, and the completed plan it was bought for loses its picture. "
                + "This can't be undone."
        )
    }

    @Test func theConfirmButtonAndTitleSayDelete() {
        #expect(ItemDeleteCopy.confirm == "Delete")
        #expect(ItemDeleteCopy.title(for: "Leica M6") == "Delete Leica M6?")
    }
}
