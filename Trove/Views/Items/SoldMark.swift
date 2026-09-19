import SwiftUI

/// What a sold item's page says about its sale, under the title block —
/// below the photo and above the paid/value stats (`014` Decision 6; it sat
/// first in the scroll content through `006`). `006` plan §5 has the rest;
/// the artboards are `design/elements/006-mark-as-sold/DetailSoldGain` and
/// `DetailSoldLoss`: the SOLD tag, the outcome beside it, the sale line
/// beneath, and the sale's note under that when there is one (`006` spec
/// Decision 11).
///
/// Unplated, so the mark reads as a stamp on the page rather than another
/// card: the page below it is the familiar one, read-only.
///
/// Every word comes from `SaleCopy` — the same `pageOutcome` and `saleLine`
/// the Sold-side row reads, so a row and the page can't drift apart. The
/// *colour* is not `SaleCopy`'s business (it is a `Trove/Models/` file and
/// names none): the rule is `SaleOutcome.isLoss`, which this view maps to
/// `accentRustText` / `accentMossText` exactly as `ItemRow` maps its delta —
/// so a sale at cost is moss, the way a zero delta already is.
///
/// One element to VoiceOver (criterion 16): "Sold", the outcome and the sale
/// line arrive as one announcement rather than three stops.
struct SoldMark: View {
    let sale: Sale
    let outcome: SaleOutcome

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Centred, not baselined: the artboard sets the small caps tag
            // against a 15pt figure, and a shared baseline hangs the tag low.
            HStack(alignment: .center, spacing: 10) {
                tag
                Text(SaleCopy.pageOutcome(deltaCents: outcome.deltaCents))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(outcomeColor)
            }

            Text(saleLine)
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textBody)

            if let note = sale.note, !note.isEmpty {
                Text(note)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.colors.textQuiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sold.mark")
    }

    /// The word itself, inverted — the page's ink on the page's text colour,
    /// at the thumbnail's radius, which is the smallest corner the app draws.
    private var tag: some View {
        Text(SaleCopy.soldMark)
            .monoLabel(color: theme.colors.background)
            .padding(.leading, 7)
            .padding(.trailing, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius)
                    .fill(theme.colors.textPrimary)
            )
    }

    /// The moss/rust rule, from the model's `isLoss` rather than from the
    /// sign of a figure re-derived here.
    private var outcomeColor: Color {
        guard outcome.deltaCents != 0 else { return theme.colors.textBody }
        return outcome.isLoss ? theme.colors.accentRustText : theme.colors.accentMossText
    }

    /// "Sep 12, 2026 · $1,200 · eBay" with the price lifted — the Design
    /// pass's one emphasis inside the line.
    ///
    /// The string stays `SaleCopy`'s: the lift is applied to the second
    /// component, which is the price by `SaleCopy.saleLine`'s own order
    /// (date, price, place), rather than by formatting a second copy of the
    /// money here where it could drift from the one on the row.
    private var saleLine: AttributedString {
        let line = SaleCopy.saleLine(sale)
        var attributed = AttributedString(line)
        let parts = line.components(separatedBy: SaleCopy.separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count > 1, let price = attributed.range(of: parts[1]) else { return attributed }
        attributed[price].font = ThemeTypography.font(.mono, size: 11.5, weight: .medium)
        attributed[price].foregroundColor = theme.colors.textPrimary
        return attributed
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        SoldMark(
            sale: Sale(date: .now, priceCents: 120_000, location: "eBay", note: nil),
            outcome: SaleOutcome(salePriceCents: 120_000, purchasePriceCents: 85_000)
        )
        SoldMark(
            sale: Sale(date: .now, priceCents: 54_000, location: nil, note: "Kept the footswitch."),
            outcome: SaleOutcome(salePriceCents: 54_000, purchasePriceCents: 69_000)
        )
        SoldMark(
            sale: Sale(date: .now, priceCents: 66_000, location: nil, note: nil),
            outcome: SaleOutcome(salePriceCents: 66_000, purchasePriceCents: 66_000)
        )
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Theme.dark.colors.background)
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
