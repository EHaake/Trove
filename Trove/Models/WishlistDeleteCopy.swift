import Foundation

/// What deleting a wanted item says for itself, in the one place both routes
/// to that deletion read from.
///
/// Two screens can delete the same record — the detail screen's overflow menu
/// and the list's swipe — and the pre-merge review found them diverging: the
/// detail alert explained the cascade/nullify asymmetry and the swipe said
/// nothing at all. Sharing the strings is what keeps the explanation from
/// drifting apart again the way the "not yet valued" copy once did; the
/// consequence line matters because none of it is guessable from the button
/// ("Delete" doesn't say photos die with it, or that sell-plan gear doesn't).
///
/// `010` unified the verb with the item side — "Delete", matching
/// `delete(id:)` and not softening a permanent action — and added the
/// undo-sentence, equally true here. spec.md's Resolved decisions record why.
enum WishlistDeleteCopy {
    static func title(for name: String) -> String {
        "Delete \(name)?"
    }

    /// All three promises, deliberately: photos cascade, sell-plan items are
    /// merely unlinked, and there's no undo. `DeletionGuardTests` pins each.
    static let message = "Its photos go too. Anything on its sell plan stays where it is. This can't be undone."

    static let confirm = "Delete"
    static let cancel = "Keep"
}
