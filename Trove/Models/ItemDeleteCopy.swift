import Foundation

/// What deleting an owned item says for itself, in the one place both routes
/// to that deletion will read from: `ItemListView`'s swipe (T015) and
/// `ItemDetailView`'s overflow menu (T017). Same construction as
/// `WishlistDeleteCopy`, and for the same reason — two entry points to one
/// deletion must not drift apart about what it costs.
///
/// The content extends the alert `ItemDetailView` already shipped (T002's
/// finding: it named the photo cascade and permanence, but not the Sell Plan
/// consequence spec.md requires). The sell-plan line matters because it isn't
/// guessable from the button: gear picked to fund a wishlist purchase
/// silently drops out of that plan when it's deleted, and the plan's math
/// changes without a word unless the alert says so here.
enum ItemDeleteCopy {
    static func title(for name: String) -> String {
        "Delete \(name)?"
    }

    /// All three consequences of deleting an *owned* item, deliberately:
    /// photos cascade, sell plans drop it (the nullify direction — the *plan*
    /// loses the item, the item never takes the plan down), and there's no
    /// undo. `ItemDeleteCopyTests` pins each one.
    ///
    /// A sold item is on no plan (006, P13), so its message drops the
    /// sell-plan sentence and keeps the rest. Both entry points — the list's
    /// swipe and the detail's menu — pass the item's own `isSold`, so neither
    /// side can promise the wrong thing.
    static func message(isSold: Bool) -> String {
        isSold
            ? "Its photos go too. This can't be undone."
            : "Its photos go too. Any sell plan it's on drops it. This can't be undone."
    }

    static let confirm = "Delete"
    static let cancel = "Keep"
}
