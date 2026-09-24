import Foundation

/// Which list a Settings "Delete All" acts on — its own type rather than a
/// `Bool`, so the copy, the alert case, and the commit path all say the same
/// word (013). `CaseIterable` since 009 Amendment A added the third target, so
/// the copy tests iterate every case rather than a list a new one can miss.
enum DeleteTarget: Equatable, Sendable, CaseIterable {
    case items
    case wishlist
    /// 009 Amendment A (Decision 18): every sell plan, active and completed —
    /// the plans only, never the entries they belong to.
    case sellPlans

    var singular: String {
        switch self {
        case .items: "item"
        case .wishlist: "wishlist item"
        case .sellPlans: "sell plan"
        }
    }

    var plural: String {
        switch self {
        case .items: "items"
        case .wishlist: "wishlist items"
        case .sellPlans: "sell plans"
        }
    }
}

/// What deleting a whole list says for itself — `ItemDeleteCopy`'s shape,
/// for the Delete All rows on the Settings screen (013; the third, sell plans,
/// from 009 Amendment A). Read by the
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
    /// delete and should read like one: for items and wishlist items the
    /// singular consequences are the single-item alerts' own sentences, so
    /// the two kinds of deletion share a vocabulary rather than merely a
    /// button pair. Not for sell plans (009 Amendment A, QA4): the single
    /// plan's own delete message depends on which side the plan is on, which
    /// a count cannot know, so its singular is its own sentence.
    ///
    /// The iCloud sentence names **the plans** for that target — after "What
    /// sold toward them stays…", a bare "they're" would read as the sales.
    ///
    /// 009 T021a: deleting items can leave completed plans showing a
    /// placeholder where the bought item's picture was. The plural always
    /// says so; the singular says so only when `picturesACompletedPlan` —
    /// the only item is the one a completed plan was bought as — matching
    /// `ItemDeleteCopy`'s owned sentence for the same flag. The flag is read
    /// for a single item only.
    static func message(
        for target: DeleteTarget,
        count: Int,
        mode: StorageMode,
        picturesACompletedPlan: Bool
    ) -> String {
        let consequences = switch (target, count == 1) {
        case (.items, false):
            "Their photos go too. Every sell plan loses its items, and completed plans lose their pictures."
        case (.items, true):
            picturesACompletedPlan
                ? "Its photos go too. Any sell plan it's on drops it, "
                    + "and the completed plan it was bought for loses its picture."
                : "Its photos go too. Any sell plan it's on drops it."
        case (.wishlist, false):
            "Their photos go too. Their sell plans go with them; the gear on those plans stays."
        case (.wishlist, true):
            "Its photos go too. Anything on its sell plan stays where it is."
        case (.sellPlans, false):
            "Nothing you own or sold is touched, and everything on your wishlist stays there. "
                + "What sold toward them stays on the record."
        case (.sellPlans, true):
            "Nothing you own or sold is touched, and everything on your wishlist stays there. "
                + "What sold toward it stays on the record."
        }

        let removed = switch (target, count == 1) {
        case (.sellPlans, false): "the plans are"
        case (.sellPlans, true): "the plan is"
        case (.items, false), (.wishlist, false): "they're"
        case (.items, true), (.wishlist, true): "it's"
        }

        let sync = switch mode {
        case .cloudKit:
            " If you're signed in to iCloud, \(removed) removed from your other devices as well."
        case .localOnly, .ephemeral:
            ""
        }

        return consequences + sync + " This can't be undone."
    }

    static let confirm = "Delete All"
    static let cancel = "Keep"

    /// Under the three rows: the mitigation sits on the same screen. It stays
    /// as it is under the sell-plans row too (009 Amendment A, RA3), although
    /// no export carries a plan.
    static let footer = "Export first if you want a copy."

    /// The mirror of import's "Nothing was imported." — one save, so a
    /// failure means the store is exactly as it was.
    static let failureTitle = "Couldn't delete"
    static let failureMessage = "Deleting failed. Nothing was deleted."
}
