import Foundation

/// Every user-facing string spec 015 fixes — its Copy section whole — pinned
/// by `PurchaseCopyTests` and read by the views and view models, never typed
/// inline. `SaleCopy`'s shape and rules, for the same reason: two surfaces
/// saying the same thing must not drift apart.
///
/// Its own table rather than rows added to `SaleCopy` (plan Q3): the spec's
/// non-goals forbid changing 006's fields, and one of the two should be
/// rewordable without opening the other.
///
/// Strings only. This is a `Trove/Models/` file, so it imports no SwiftUI and
/// names no colour.
nonisolated enum PurchaseCopy {
    // MARK: - Actions

    /// The ellipsis is `…` (`\u{2026}`), matching `SaleCopy.markAsSold`.
    static let markAsBought = "Mark as bought\u{2026}"

    /// The *visible* short form of this action in the two places whose width
    /// is short — the wishlist row's swipe, where "Mark as bought" does not
    /// fit beside a glyph, and (since T012a) the Sell Plan's toolbar button,
    /// which wears the word rather than a bag glyph that would read as
    /// *cart*. One short word for one action in both places; the spoken name
    /// stays `markAsBought` in each. `SaleCopy.swipeSell`'s arrangement, on
    /// the wanted side. The name still says "swipe" because that is where it
    /// started and both callers spell it the same way.
    static let swipeBuy = "Buy"

    // MARK: - The sheet

    /// No `sheetTitle`: T012a removed the sheet's navigation title, the
    /// person's decision at the device pass — it truncated to "Mark as bo…"
    /// beside a confirm button saying the same words, so the title was both
    /// redundant and broken.
    static let confirm = "Mark as bought"
    static let cancel = "Cancel"

    static let purchasePriceLabel = "Purchase price"
    static let purchaseDateLabel = "Purchase date"
    static let boughtFromLabel = "Bought from"
    static let boughtFromPlaceholder = "eBay, Reverb, a friend\u{2026}"
    static let conditionLabel = "Condition"

    // MARK: - A refused purchase

    /// The alert all three hosts show when a purchase is refused (T012b).
    /// Before this the reason was recorded in a view-model property no view
    /// read, so a refusal closed the sheet and said nothing at all.
    static let failureTitle = "Couldn't mark it bought"

    /// The one refusal a person can actually meet: the entry already carries
    /// a marker, so `WishlistPurchaseStore.markBought` threw
    /// `PurchaseError.alreadyBought` — which on a real device means it was
    /// bought elsewhere while this screen was open (B1, criterion 12).
    ///
    /// "Nothing was changed" is load-bearing and true: the guard sits ahead
    /// of the market clear, so a refused second purchase writes nothing at
    /// all.
    static let alreadyBought = "This one is already marked bought \u{2014} it may have been bought on another device. Nothing was changed."

    /// Any other refusal — a failed save, or a failed market clear. True
    /// for the same reason from the other end: the host rolls the context
    /// back, so none of the purchase's writes survive it.
    static let failureMessage = "Something went wrong saving the purchase. Nothing was changed."

    // MARK: - The comparison line

    /// The currency v1 speaks (`Int+Currency`'s note): USD only, no picker,
    /// so the composed figure names it the way `SaleCopy` does.
    private static let currencyCode = "USD"

    /// How the entered price compares to what the wanted entry estimated —
    /// "$120 less than you estimated" / "$85 more than you estimated" — or
    /// nil for the two silences (plan Q7).
    ///
    /// Nil when the estimate is 0, because `estimatedCostCents` is a
    /// non-optional `Int` whose 0 means "none", as the pre-fill already reads
    /// it. Nil, too, when the two are within a dollar: every money figure in
    /// the app draws whole dollars, so a 40-cent difference would otherwise
    /// render "$0 more than you estimated", which is worse than the silence
    /// the spec asks for at equality. The sub-dollar floor is the plan's, not
    /// the spec's.
    static func comparison(paidCents: Int, estimatedCostCents: Int) -> String? {
        guard estimatedCostCents != 0 else { return nil }
        let deltaCents = paidCents - estimatedCostCents
        guard abs(deltaCents) >= 100 else { return nil }
        let magnitude = abs(deltaCents).formattedAsWholeCurrency(currencyCode: currencyCode)
        return "\(magnitude) \(deltaCents < 0 ? "less" : "more") than you estimated"
    }
}
