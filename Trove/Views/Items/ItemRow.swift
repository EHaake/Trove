import SwiftUI

/// One item in the list, per `design/screens/Trove Item List.png`: thumbnail,
/// name, category, what it's worth against what it cost, and the desire dial
/// small and quiet on the right.
struct ItemRow: View {
    let item: Item

    /// The market trend for this item, from the list's own view model
    /// (002/T012). Defaults to nothing so a caller with no market summaries
    /// — the previews, and any future list — reads as "no trend yet".
    var trend: MarketTrend?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.metrics.rowContentGap) {
            RowThumbnail(photos: item.photos ?? [])

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)

                categoryLine

                valueLine
            }

            Spacer(minLength: 0)

            // Read-only here; the brief asks for the dial small and quiet in
            // list contexts, editable on the form and detail screens.
            DesireDial(value: .constant(item.desireToKeep), diameter: 36)
        }
        .padding(theme.metrics.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .extrudedPlate()
        .accessibilityElement(children: .combine)
    }

    /// Design's meta line reads "LEICA · CAMERAS" — brand then category. There
    /// is no brand in the schema and guessing one from the name would be
    /// wrong as often as right, so this shows the category path's own
    /// segments, which keeps the rhythm and says something true.
    ///
    /// Capped at the trailing two: a three-level path rendered in full only
    /// truncates mid-word here, and the specific end of the path is the
    /// informative part. The detail screen shows the whole thing.
    private var categoryLine: some View {
        Text(CategoryPathHelper.trailingSegments(of: item.categoryPath).joined(separator: " · "))
            .monoLabel()
            .lineLimit(1)
    }

    private var valueLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let currentValueCents = item.currentValueCents {
                Text(currentValueCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)

                if let delta = item.valueDeltaCents {
                    Text("\(delta.formattedAsSignedWholeAmount) vs paid")
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(delta < 0 ? theme.colors.accentRustText : theme.colors.accentMossText)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }

                TrendArrow(trend: trend)
            } else {
                // Design never drew this case, but most items start here: a
                // value is optional at creation. Saying so plainly beats
                // showing $0, which would read as worthless.
                Text("Not yet valued")
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.colors.textQuiet)

                // Beside "Not yet valued" too: the arrow describes the
                // market, not the person's own figure, so an item they
                // haven't valued still shows where the asking prices went.
                TrendArrow(trend: trend)

            }
        }
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 10) {
            ItemRow(item: Item(
                name: "Leica M6 (0.72x)",
                categoryPath: "Photography/Cameras",
                purchasePriceCents: 290_000,
                currentValueCents: 345_000,
                desireToKeep: 5
            ))
            ItemRow(item: Item(
                name: "Fender Blues Junior IV",
                categoryPath: "Music/Amps",
                purchasePriceCents: 69_000,
                currentValueCents: 54_000,
                desireToKeep: 2
            ))
            ItemRow(item: Item(
                name: "Squier Classic Vibe 50s",
                categoryPath: "Music/Guitars/Electric",
                purchasePriceCents: 38_000,
                desireToKeep: 1
            ))
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}
