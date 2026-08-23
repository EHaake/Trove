import Foundation

/// What deleting a wanted item says for itself, in the one place both routes
/// to that deletion read from.
///
/// Two screens can delete the same record — the detail screen's overflow menu
/// and the list's swipe — and the pre-merge review found them diverging: the
/// detail alert explained the cascade/nullify asymmetry and the swipe said
/// nothing at all. Sharing the strings is what keeps the explanation from
/// drifting apart again the way the "not yet valued" copy once did; the
/// consequence line matters because neither half of it is guessable from the
/// button ("Remove" doesn't say photos die with it, or that sell-plan gear
/// doesn't).
enum WishlistDeleteCopy {
    static func title(for name: String) -> String {
        "Remove \(name)?"
    }

    /// Both halves of the asymmetry, deliberately: photos cascade, sell-plan
    /// items are merely unlinked. `WishlistDeleteCopyTests` pins each half.
    static let message = "Its photos go too. Anything on its sell plan stays where it is."

    static let confirm = "Remove"
    static let cancel = "Keep"
}
