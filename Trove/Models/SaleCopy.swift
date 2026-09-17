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
/// The outcome line is one form on a row and on the page alike, settled by
/// the Design pass (spec Decision 11): "Gain $350 vs paid" / "Loss $150 vs
/// paid" / "At cost". The words, not the colour, carry which one it is — the
/// page only sets the same string larger, so `pageOutcome` forwards to
/// `rowOutcome` rather than composing its own.
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
    /// (T004) and this file stays a plain string table.
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
    static let notePlaceholder = "Anything worth remembering"

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

    static let nothingSoldHeadline = "Nothing sold yet."
    static let nothingSoldDetail = "Mark an item as sold from its page or from a sell plan."

    // MARK: - The Owned side, emptied by selling

    /// What the Owned side says once every item on it has been sold (spec
    /// Decision 12) — not the first-launch "No gear yet", because this person
    /// has been using the app. The detail is an invitation, and the state
    /// keeps the first-launch state's Add button so the door is the same one.
    static let everythingSoldHeadline = "Everything's sold."
    static let everythingSoldDetail = "Add something new."

    // MARK: - A sell plan whose every candidate has sold

    /// What a sell plan says once nothing is left to offer toward it (spec
    /// Decision 15) — not "Nothing to sell yet", which is the first-launch
    /// line and reads as though the sales listed directly beneath it never
    /// happened. Its own two constants rather than the Owned side's: the two
    /// states are emptied by the same act but sit under different figures,
    /// and either should be rewordable alone.
    ///
    /// No invitation in the detail, unlike the Owned side's: this state is
    /// only ever drawn above the plan's Sold section, so the useful thing to
    /// say is where the record went.
    static let planEverythingSoldHeadline = "Everything on this plan has sold."
    static let planEverythingSoldDetail = "The sales are listed below."

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
    /// rows and the page say "At cost" in words instead.
    static func realised(deltaCents: Int) -> String {
        "\(deltaCents.formattedAsSignedWholeCurrency(currencyCode: currencyCode)) vs paid"
    }

    /// The Sold side's summary — "3 sold · $2,400 · +$350 vs paid". Reads the
    /// same `SaleTotals` the card reads, so AC7's "the summary matches the
    /// card" is one sum, not two.
    ///
    /// It is always a line, never nothing (spec Decision 13, replacing
    /// Decision 11's hide-at-zero): the Sold side's header keeps the same
    /// slot the Owned side's item stats occupy, so the switch above it
    /// cannot jump as the sides change. At zero sales it reads "0 sold ·
    /// $0" — the realised part is dropped rather than set to "+$0 vs paid",
    /// because a gain measured over no sales states a measurement where
    /// there is none. That is the one shape difference, and it lives here
    /// so the two readers of this line can't spell the zero case
    /// differently.
    static func soldSideSummary(_ totals: SaleTotals) -> String {
        var parts = [
            "\(totals.count) sold",
            totals.proceedsCents.formattedAsWholeCurrency(currencyCode: currencyCode),
        ]
        if totals.count > 0 {
            parts.append(realised(deltaCents: totals.realisedDeltaCents))
        }
        return parts.joined(separator: " \(separator) ")
    }

    /// What a sale at exactly what was paid says, on a row and on the page
    /// alike — the one outcome with no figure in it. It drops the word
    /// "Sold" because the row's date line and the page's tag already say it
    /// (Decision 11).
    static let atCost = "At cost"

    /// A sold item's outcome — "Gain $350 vs paid" / "Loss $150 vs paid" /
    /// "At cost". Words first, then the amount, then the basis: "vs paid" is
    /// the app's existing phrase, and it names what the figure is measured
    /// against on a page where WORTH NOW sits just below (Decision 11).
    static func rowOutcome(deltaCents: Int) -> String {
        guard deltaCents != 0 else { return atCost }
        let magnitude = abs(deltaCents).formattedAsWholeCurrency(currencyCode: currencyCode)
        return "\(deltaCents < 0 ? "Loss" : "Gain") \(magnitude) vs paid"
    }

    /// The sold page's outcome — the same string the row shows, which the
    /// page sets larger. An alias rather than a second body, so the two
    /// surfaces cannot drift apart; the name stays so each call site reads
    /// for the surface it is on.
    static func pageOutcome(deltaCents: Int) -> String {
        rowOutcome(deltaCents: deltaCents)
    }

    /// The sale in one line — "Sep 12, 2026 · $1,200 · eBay", the place
    /// omitted when there isn't one. It drops the word "Sold": the tag above
    /// it on the sold page already says so (Decision 11). The date goes
    /// through the same `formatted(date: .abbreviated, time: .omitted)` the
    /// detail's "Bought" row uses, so it follows the device's own format
    /// (plan Q11) — "Sep 12, 2026" on a US device; the spec's example is the
    /// same date written in a day-first locale, not a fixed order.
    static func saleLine(_ sale: Sale) -> String {
        var parts = [sale.date.formatted(date: .abbreviated, time: .omitted)]
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
