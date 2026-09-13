import Foundation

/// Every user-facing string spec 006 fixes — its Copy section, the sheet's
/// labels by mode, and the composed lines — pinned whole by `SaleCopyTests`
/// and read by the views and view models, never typed inline. Same shape as
/// `StockPhotoCopy` and `MarketCopy`, and for the same reason: two surfaces
/// saying the same thing must not drift apart.
///
/// Strings only. This is a `Trove/Models/` file, so it imports no SwiftUI and
/// names no colour (plan Q11): the *rule* behind the colour is
/// `SaleOutcome.isLoss`, and each view maps that to `accentRustText` /
/// `accentMossText` itself.
///
/// The two outcome lines (`rowOutcome`, `pageOutcome`) are placeholders per
/// spec Decision 10 as clarified: what is fixed is that a row and the page
/// make the gain or loss and its amount unmistakable without colour carrying
/// it. The Design pass (T008) may settle a different form, in which case this
/// file and `SaleCopyTests` change with it — a copy change inside the spec,
/// not new copy.
nonisolated enum SaleCopy {
    // MARK: - Actions

    /// The ellipsis is `…` (`\u{2026}`), matching `StockPhotoCopy.findAPhoto`.
    /// Used by the detail's overflow menu and by a Sell Plan row.
    static let markAsSold = "Mark as sold\u{2026}"
    static let editSale = "Edit sale\u{2026}"
    static let returnToCollection = "Return to collection\u{2026}"
    // The sold page's third action, Delete, keeps reading `ItemDeleteCopy` —
    // one word for one deletion, whichever side the item is on.

    // MARK: - The sale sheet

    /// Title and confirm button by mode. Two constants each rather than a
    /// function of the sheet's mode, because the mode is a view-model type
    /// (T003) and this file stays a plain string table.
    static let sheetTitleMark = "Mark as sold"
    static let sheetTitleEdit = "Edit sale"
    static let confirmMark = "Mark as sold"
    static let confirmEdit = "Save"
    static let cancel = "Cancel"

    static let salePriceLabel = "Sale price"
    static let soldOnLabel = "Sold on"
    static let soldAtLabel = "Sold at"
    static let soldAtPlaceholder = "eBay, Reverb, a friend\u{2026}"
    static let noteLabel = "Note"

    // MARK: - Return to collection (the alert)

    static func returnTitle(_ name: String) -> String {
        "Return \(name) to your collection?"
    }

    static let returnMessage = "Its sale details will be removed."
    static let returnConfirm = "Return"
    static let returnCancel = "Keep as sold"

    // MARK: - The Items tab's switch

    static let owned = "Owned"
    static let sold = "Sold"

    // MARK: - The surfaces that carry the word

    /// Each surface carries its own literal rather than aliasing `sold`, so
    /// one of them can be reworded without silently rewording the others.
    static let soldMark = "Sold"
    static let cardHeader = "Sold"
    static let sellPlanFigureHeader = "Sold"
    static let sellPlanSectionTitle = "Sold"

    // MARK: - The Sold side

    static let emptyState = "Nothing sold yet. Mark an item as sold from its page or from a sell plan."

    // MARK: - Composed lines

    /// The middle dot every summary line in the app joins on
    /// (`\u{00B7}`), matching `MarketCopy.separator`.
    static let separator = "\u{00B7}"

    /// The currency v1 speaks (`Int+Currency`'s note): USD only, no picker,
    /// so the composed figures name it the way `MarketCopy` does.
    private static let currencyCode = "USD"

    /// The Dashboard card's figures — "3 items · $2,400". Pluralised the way
    /// `DashboardView.headerMeta` and `ItemListView.summaryLine` pluralise.
    static func dashboardSummary(_ totals: SaleTotals) -> String {
        let count = "\(totals.count) \(totals.count == 1 ? "item" : "items")"
        let proceeds = totals.proceedsCents.formattedAsWholeCurrency(currencyCode: currencyCode)
        return "\(count) \(separator) \(proceeds)"
    }

    /// The realised gain or loss beneath the card's figures — "+$350 vs
    /// paid". Zero reads "+$0 vs paid" through the Dashboard's own signed
    /// formatter, exactly as its Gain figure already does (plan Q11); the
    /// rows and the page say "Sold at cost" in words instead.
    static func realised(deltaCents: Int) -> String {
        "\(deltaCents.formattedAsSignedWholeCurrency(currencyCode: currencyCode)) vs paid"
    }

    /// The Sold side's summary — "3 sold · $2,400 · +$350 vs paid". Reads the
    /// same `SaleTotals` the card reads, so AC7's "the summary matches the
    /// card" is one sum, not two.
    static func soldSideSummary(_ totals: SaleTotals) -> String {
        [
            "\(totals.count) sold",
            totals.proceedsCents.formattedAsWholeCurrency(currencyCode: currencyCode),
            realised(deltaCents: totals.realisedDeltaCents),
        ].joined(separator: " \(separator) ")
    }

    /// What a sale at exactly what was paid says, on a row and on the page
    /// alike — the one outcome with no figure in it.
    static let atCost = "Sold at cost"

    /// A Sold-side row's outcome — "Gain $350" / "Loss $150" / "Sold at
    /// cost". The words, not the colour, carry which one it is.
    static func rowOutcome(deltaCents: Int) -> String {
        guard deltaCents != 0 else { return atCost }
        let magnitude = abs(deltaCents).formattedAsWholeCurrency(currencyCode: currencyCode)
        return deltaCents < 0 ? "Loss \(magnitude)" : "Gain \(magnitude)"
    }

    /// The sold page's outcome — "Sold at a gain of $350" / "Sold at a loss
    /// of $150" / "Sold at cost".
    static func pageOutcome(deltaCents: Int) -> String {
        guard deltaCents != 0 else { return atCost }
        let magnitude = abs(deltaCents).formattedAsWholeCurrency(currencyCode: currencyCode)
        return deltaCents < 0
            ? "Sold at a loss of \(magnitude)"
            : "Sold at a gain of \(magnitude)"
    }

    /// The sale in one line — "Sold 12 Sep 2026 · $1,200 · eBay", the place
    /// omitted when there isn't one. The date goes through the same
    /// `formatted(date: .abbreviated, time: .omitted)` the detail's "Bought"
    /// row uses, so it follows the device's own format (plan Q11) — "Sep 12,
    /// 2026" on a US device; the spec's example is the same date written in a
    /// day-first locale, not a fixed order.
    static func saleLine(_ sale: Sale) -> String {
        var parts = ["Sold \(sale.date.formatted(date: .abbreviated, time: .omitted))"]
        parts.append(sale.priceCents.formattedAsWholeCurrency(currencyCode: currencyCode))
        if let location = sale.location, !location.isEmpty {
            parts.append(location)
        }
        return parts.joined(separator: " \(separator) ")
    }

    /// The Sell Plan's third figure, captioned "2 items" beneath the header.
    static func sellPlanSoldCaption(count: Int) -> String {
        "\(count) \(count == 1 ? "item" : "items")"
    }
}
