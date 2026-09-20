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

    /// The *visible* word where a swipe button's width is short — "Mark as
    /// bought" does not fit beside a glyph — while the spoken name stays
    /// `markAsBought`. `SaleCopy.swipeSell`'s arrangement, on the wanted side.
    static let swipeBuy = "Buy"

    // MARK: - The sheet

    static let sheetTitle = "Mark as bought"
    static let confirm = "Mark as bought"
    static let cancel = "Cancel"

    static let purchasePriceLabel = "Purchase price"
    static let purchaseDateLabel = "Purchase date"
    static let boughtFromLabel = "Bought from"
    static let boughtFromPlaceholder = "eBay, Reverb, a friend\u{2026}"
    static let conditionLabel = "Condition"

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
