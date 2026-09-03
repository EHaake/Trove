import Foundation

/// Which list a Settings "Delete All" acts on — its own type rather than a
/// `Bool`, so the copy, the alert case, and the commit path all say the same
/// word (013).
enum DeleteTarget: Equatable, Sendable {
    case items
    case wishlist

    var singular: String {
        switch self {
        case .items: "item"
        case .wishlist: "wishlist item"
        }
    }

    var plural: String {
        switch self {
        case .items: "items"
        case .wishlist: "wishlist items"
        }
    }
}

/// What deleting a whole list says for itself — `ItemDeleteCopy`'s shape,
/// for the two Delete All rows on the Settings screen (013). Read by the
/// Settings view model alone, so the alert can't drift from the row that
/// opened it; `DeleteAllCopyTests` pins every string.
///
/// The iCloud sentence appears **only when the store is configured for
/// iCloud** (spec Decision 13). In the local-only fallback nothing syncs
/// whether or not you're signed in — and the iCloud row two sections up
/// says exactly that, so the alert must not contradict it. The same rule
/// `SaveCaption` follows.
enum DeleteAllCopy {
    /// "Delete all 309 items?" — and, decided at plan review, a single row
    /// reads "Delete your only item?" rather than "Delete all 1 item?".
    static func title(count: Int, target: DeleteTarget) -> String {
        count == 1
            ? "Delete your only \(target.singular)?"
            : "Delete all \(count) \(target.plural)?"
    }

    /// Count-aware, because deleting a list of one *is* a single-item
    /// delete and should read like one: the singular consequences are the
    /// single-item alerts' own sentences, so the two kinds of deletion
    /// share a vocabulary rather than merely a button pair.
    static func message(for target: DeleteTarget, count: Int, mode: StorageMode) -> String {
        let consequences = switch (target, count == 1) {
        case (.items, false):
            "Their photos go too. Every sell plan loses its items."
        case (.items, true):
            "Its photos go too. Any sell plan it's on drops it."
        case (.wishlist, false):
            "Their photos go too. Their sell plans go with them; the gear on those plans stays."
        case (.wishlist, true):
            "Its photos go too. Anything on its sell plan stays where it is."
        }

        let sync = switch mode {
        case .cloudKit:
            count == 1
                ? " If you're signed in to iCloud, it's removed from your other devices as well."
                : " If you're signed in to iCloud, they're removed from your other devices as well."
        case .localOnly, .ephemeral:
            ""
        }

        return consequences + sync + " This can't be undone."
    }

    static let confirm = "Delete All"
    static let cancel = "Keep"

    /// Under the two rows: the mitigation sits on the same screen.
    static let footer = "Export first if you want a copy."

    /// The mirror of import's "Nothing was imported." — one save, so a
    /// failure means the store is exactly as it was.
    static let failureTitle = "Couldn't delete"
    static let failureMessage = "Deleting failed. Nothing was deleted."
}
