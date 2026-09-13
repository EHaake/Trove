import Testing
@testable import Trove

/// 013/T004: the Delete All alerts' copy, pinned pure — the
/// `ItemDeleteCopyTests` precedent. Every consequence the spec promises is
/// asserted by name, the iCloud sentence is asserted present *and* absent
/// (Decision 13), and the singular form the person asked for at plan
/// review is a whole-string pin.
@Suite("Delete All copy")
struct DeleteAllCopyTests {
    @Test func titlesCarryTheExactCountAndPluralize() {
        #expect(DeleteAllCopy.title(count: 309, target: .items) == "Delete all 309 items?")
        #expect(DeleteAllCopy.title(count: 12, target: .wishlist) == "Delete all 12 wishlist items?")
        #expect(DeleteAllCopy.title(count: 2, target: .items) == "Delete all 2 items?")
    }

    @Test func aListOfOneReadsAsYourOnlyItem() {
        #expect(DeleteAllCopy.title(count: 1, target: .items) == "Delete your only item?")
        #expect(DeleteAllCopy.title(count: 1, target: .wishlist) == "Delete your only wishlist item?")
    }

    @Test func theItemsMessageNamesEveryConsequenceWhenSyncing() {
        #expect(
            DeleteAllCopy.message(for: .items, count: 309, mode: .cloudKit)
                == "Their photos go too. Every sell plan loses its items. "
                + "If you're signed in to iCloud, they're removed from your other devices as well. "
                + "This can't be undone."
        )
    }

    @Test func theWishlistMessageNamesTheAsymmetryWhenSyncing() {
        #expect(
            DeleteAllCopy.message(for: .wishlist, count: 12, mode: .cloudKit)
                == "Their photos go too. Their sell plans go with them; the gear on those plans stays. "
                + "If you're signed in to iCloud, they're removed from your other devices as well. "
                + "This can't be undone."
        )
    }

    /// Decision 13: the iCloud sentence is present exactly when the store
    /// is configured for iCloud, and absent for both other modes — a
    /// local-only fallback syncs nothing whether or not you're signed in.
    @Test func theICloudSentenceFollowsTheStorageMode() {
        for target in [DeleteTarget.items, .wishlist] {
            for count in [1, 5] {
                let syncing = DeleteAllCopy.message(for: target, count: count, mode: .cloudKit)
                #expect(syncing.contains("If you're signed in to iCloud"), "\(target) ×\(count)")
                for mode in [StorageMode.localOnly, .ephemeral] {
                    let local = DeleteAllCopy.message(for: target, count: count, mode: mode)
                    #expect(!local.contains("iCloud"), "\(target) ×\(count) in \(mode) mentions iCloud")
                    #expect(!local.contains("other devices"), "\(target) ×\(count) in \(mode)")
                }
            }
        }
    }

    @Test func theLocalOnlyMessagesStillNameTheOtherConsequences() {
        #expect(
            DeleteAllCopy.message(for: .items, count: 4, mode: .localOnly)
                == "Their photos go too. Every sell plan loses its items. This can't be undone."
        )
        #expect(
            DeleteAllCopy.message(for: .wishlist, count: 4, mode: .ephemeral)
                == "Their photos go too. Their sell plans go with them; the gear on those plans stays. "
                + "This can't be undone."
        )
    }

    /// A list of one reads like the single-item alert it effectively is —
    /// the same sentences `ItemDeleteCopy` and `WishlistDeleteCopy` use.
    @Test func aListOfOneReadsLikeTheSingleItemAlert() {
        #expect(
            DeleteAllCopy.message(for: .items, count: 1, mode: .cloudKit)
                == "Its photos go too. Any sell plan it's on drops it. "
                + "If you're signed in to iCloud, it's removed from your other devices as well. "
                + "This can't be undone."
        )
        #expect(
            DeleteAllCopy.message(for: .wishlist, count: 1, mode: .localOnly)
                == "Its photos go too. Anything on its sell plan stays where it is. This can't be undone."
        )
        // Shared by pin, not by coincidence: in a local-only mode a list of
        // one *is* the single-item alert, word for word, on both sides — so
        // rewording either single-item alert turns this red (the sweep's S6
        // replaced a magic-number prefix check with these).
        #expect(DeleteAllCopy.message(for: .items, count: 1, mode: .localOnly) == ItemDeleteCopy.message(isSold: false))
        #expect(DeleteAllCopy.message(for: .wishlist, count: 1, mode: .localOnly) == WishlistDeleteCopy.message)
    }

    @Test func everyMessageEndsWithNoUndo() {
        for target in [DeleteTarget.items, .wishlist] {
            for count in [1, 2] {
                for mode in [StorageMode.cloudKit, .localOnly, .ephemeral] {
                    #expect(
                        DeleteAllCopy.message(for: target, count: count, mode: mode)
                            .hasSuffix("This can't be undone."),
                        "\(target) ×\(count) in \(mode)"
                    )
                }
            }
        }
    }

    @Test func buttonsFooterAndFailureAreTheSpecsWords() {
        #expect(DeleteAllCopy.confirm == "Delete All")
        #expect(DeleteAllCopy.cancel == "Keep")
        #expect(DeleteAllCopy.footer == "Export first if you want a copy.")
        #expect(DeleteAllCopy.failureTitle == "Couldn't delete")
        #expect(DeleteAllCopy.failureMessage == "Deleting failed. Nothing was deleted.")
        #expect(DeleteAllCopy.failureMessage.hasSuffix("Nothing was deleted."))
    }
}
