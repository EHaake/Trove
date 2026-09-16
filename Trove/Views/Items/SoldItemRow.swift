import SwiftUI

/// One sold item on the Items tab's Sold side, per the Design pass's
/// `design/elements/006-mark-as-sold/Main` artboard: the Owned row's shape —
/// the same plate, the same 52 pt thumbnail, the same padding — with the sale
/// where the category and the current value used to be.
///
/// No dial and no trend arrow, deliberately (plan §4): both speak about gear
/// you still own. A sold item has no desire to keep and no market line, and
/// drawing either would be the page asserting something it withdrew when the
/// sale was recorded.
///
/// The words are `SaleCopy`'s — `rowOutcome` is the string the sold page shows
/// too, so a row and the page cannot drift (Decision 11). The *colour* is not
/// `SaleCopy`'s business: the rule is `SaleOutcome.isLoss`, which this view
/// maps to `accentRustText` / `accentMossText` exactly as `SoldMark` does, and
/// the words carry the meaning on their own — the colour only repeats them
/// (Decision 10).
///
/// One element to VoiceOver (criterion 16): name, sold date, price and outcome
/// arrive as one announcement rather than four stops.
struct SoldItemRow: View {
    let item: Item

    @Environment(\.theme) private var theme

    private var sale: Sale? { item.sale }
    private var outcome: SaleOutcome? { item.saleOutcome }

    // The three composed lines below are internal rather than private so
    // `SoldItemRowTests` can read what the row says — a rendered `Text` can be
    // measured for colour but not for words, and "a loss row reads Loss $150"
    // is exactly the claim worth guarding.

    /// "SOLD SEP 12, 2026" once `monoLabel` has raised it — the sale's own
    /// date, through the `formatted(date: .abbreviated, time: .omitted)` every
    /// other date in the app goes through, so it follows the device's format.
    /// The word is `SaleCopy.soldMark` rather than a literal typed here
    /// (plan Q11): the row's date line and the page's tag say the same thing
    /// about the same fact.
    var dateLine: String? {
        guard let sale else { return nil }
        return "\(SaleCopy.soldMark) \(sale.date.formatted(date: .abbreviated, time: .omitted))"
    }

    /// What it sold for — never what it is worth now, which a sold item no
    /// longer has an opinion about.
    var priceText: String? {
        guard let sale else { return nil }
        return sale.priceCents.formattedAsWholeCurrency(currencyCode: item.currencyCode)
    }

    /// "Gain $350 vs paid" / "Loss $150 vs paid" / "At cost".
    var outcomeText: String? {
        guard let outcome else { return nil }
        return SaleCopy.rowOutcome(deltaCents: outcome.deltaCents)
    }

    var body: some View {
        HStack(spacing: theme.metrics.rowContentGap) {
            RowThumbnail(photos: item.photos ?? [])

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)

                if let dateLine {
                    Text(dateLine)
                        .monoLabel()
                        .lineLimit(1)
                }

                valueLine
            }

            Spacer(minLength: 0)
        }
        .padding(theme.metrics.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .extrudedPlate()
        .accessibilityElement(children: .combine)
        // The `005` corner mark rides a sold row too (Design pass), so it
        // carries the same announcement `ItemRow` gives it — same predicate,
        // so the visible mark and the spoken one can't drift.
        .accessibilityValue(PhotoSelection.leadsWithStock(item.photos ?? [])
            ? StockPhotoCopy.badgeAccessibilityLabel : "")
    }

    /// The price, then the outcome in words — the Owned row's value line with
    /// "vs paid" measured against the sale rather than against today.
    private var valueLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let priceText {
                Text(priceText)
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
            }

            if let outcomeText {
                Text(outcomeText)
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(outcomeColor)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }
        }
    }

    /// The moss/rust rule from the model's `isLoss`, not from the sign of a
    /// figure re-derived here. A sale at exactly what was paid is neither, so
    /// it takes the row's quiet label tone and lets the word "At cost" say it.
    private var outcomeColor: Color {
        guard let outcome, outcome.deltaCents != 0 else { return theme.colors.textLabelSecondary }
        return outcome.isLoss ? theme.colors.accentRustText : theme.colors.accentMossText
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 10) {
            SoldItemRow(item: sold(
                name: "Technics SL-1200",
                paid: 85_000,
                price: 120_000,
                daysAgo: 2
            ))
            SoldItemRow(item: sold(
                name: "Vox AC15C1",
                paid: 66_000,
                price: 66_000,
                daysAgo: 11
            ))
            SoldItemRow(item: sold(
                name: "Fender Blues Junior IV",
                paid: 69_000,
                price: 54_000,
                daysAgo: 15
            ))
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

@MainActor
private func sold(name: String, paid: Int, price: Int, daysAgo: Int) -> Item {
    let item = Item(name: name, categoryPath: "Music/Amps", purchasePriceCents: paid)
    item.sale = Sale(
        date: .now.addingTimeInterval(TimeInterval(-daysAgo * 24 * 60 * 60)),
        priceCents: price,
        location: "eBay",
        note: nil
    )
    return item
}
