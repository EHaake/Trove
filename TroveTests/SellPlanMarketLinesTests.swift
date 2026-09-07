import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The Sell Plan's two new lines in pixels (003 plan §5), on the
/// `TrendArrowRenderTests` instrument: render, sample, measure.
///
/// Three claims a source scan cannot reach. The market line draws its arrow
/// in the moss tone and draws *nothing* without a trend. The reason line
/// **wraps rather than truncates** — criterion 11's testable substance, since
/// this app's type doesn't scale with the system size setting and a
/// `.accessibility5` override would measure nothing (plan Q10). And the row's
/// marks — checkbox and dial — stay on the same edge whether the row carries
/// the two lines or neither, which is the alignment half of the same
/// criterion.
@Suite("SellPlanMarketLines render")
@MainActor
struct SellPlanMarketLinesRenderTests {
    private let colors = ThemeColors.dark

    /// Full-strength token ink against 8-bit rounding, as the arrow's own
    /// render tests use — not the 0.06 perceptual floor, which asks a
    /// different question.
    private let tolerance = 0.02

    /// Fixed so the reason line's date, and so its width, never moves.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// The row's width in the proposal: enough that the left column is narrow
    /// enough for the sentence to need more than one line.
    private let rowWidth: CGFloat = 360

    /// The left column's own `VStack` spacing, which arrives with each line
    /// the column gains.
    private let columnSpacing = 5

    // MARK: - The market line's ink

    /// The whole line is sampled rather than the brightest pixel: unlike a
    /// bare `TrendArrow`, this view also draws `textQuiet` type, so "the
    /// furthest pixel from black" is the figure, not the arrow.
    @Test func aRisingMarketLineDrawsTheArrowInTheMossTextTone() throws {
        let bitmap = try pixels(of: SellPlanMarketLine(medianCents: 140_000, trend: .up))
        #expect(
            contains(bitmap, colors.accentMossText),
            "no pixel of the rising market line is accentMossText — the arrow isn't drawn, or isn't that tone"
        )
    }

    /// The negative half, and the reason the positive one above is needed as
    /// its control: a market line with no trend must draw neither tone.
    @Test func aMarketLineWithNoTrendDrawsNeitherArrowTone() throws {
        let bitmap = try pixels(of: SellPlanMarketLine(medianCents: 140_000, trend: nil))
        #expect(!contains(bitmap, colors.accentMossText), "a trendless market line drew the rising tone")
        #expect(!contains(bitmap, colors.accentRustText), "a trendless market line drew the falling tone")
    }

    // MARK: - The reason line wraps rather than truncating

    /// Three renders, two thresholds (plan §5, amended 2026-09-07 for
    /// T004a). Both lines now stack in the same column, so the old
    /// `withLines − plain` difference carried the market line's height too
    /// and `lineLimit(1)` on the sentence would have cleared a two-line
    /// floor. Isolating the sentence takes a third render: the row with the
    /// market line and no rise. Then `both − marketOnly` is the reason
    /// line's contribution alone — drop it and the difference is 0, cap it
    /// at `lineLimit(1)` and it is one line plus the column's 5 pt spacing,
    /// under two.
    ///
    /// The market line gets its own pin rather than a floor, so that it is
    /// proven present *and* single: `marketOnly − plain` is exactly one
    /// rendered `SellPlanMarketLine` plus that same 5 pt spacing. Drop the
    /// market line from the row and the difference is 0.
    @Test func theRowGrowsByAtLeastTwoLinesWhenTheReasonSentenceWraps() throws {
        let plain = try rowHeight(summary: nil, rise: nil)
        let marketOnly = try rowHeight(summary: risingSummary, rise: nil)
        let both = try rowHeight(summary: risingSummary, rise: try rise())
        let oneLine = try #require(
            renderBitmap(SellPlanReasonLine(rise: try rise(), now: now)),
            "ImageRenderer produced nothing to measure."
        ).height
        let oneMetaLine = try #require(
            renderBitmap(SellPlanMarketLine(medianCents: 140_000, trend: .up)),
            "ImageRenderer produced nothing to measure."
        ).height

        print("SellPlanRow heights — plain: \(plain), market line only: \(marketOnly), both lines: \(both), one secondary line: \(oneLine), one meta line: \(oneMetaLine)")

        #expect(
            both - marketOnly >= 2 * oneLine,
            "the row grew by \(both - marketOnly) pt for a sentence that needs two lines of \(oneLine) pt — it was dropped, or truncated"
        )
        #expect(
            marketOnly - plain == oneMetaLine + columnSpacing,
            "the row grew by \(marketOnly - plain) pt for a market line of \(oneMetaLine) pt plus the column's \(columnSpacing) pt spacing — it was dropped, or it is drawing more than one line"
        )
    }

    // MARK: - The marks stay on the same edge

    /// Criterion 11's alignment half. The checkbox is found as a brass block
    /// **bounded in both axes**: the selected card's own 1 pt border is one
    /// pixel deep along its top edge and one pixel wide along its left edge,
    /// so a locator bounded in one axis only finds the border instead — which
    /// it did, twice, at sign-off. A 1 pt stroke can never be 10 px in both.
    ///
    /// The instrument is checked before the mutation is believed (the T056
    /// rule): the located y on the healthy render is printed and pinned to
    /// `cardPadding`, because a locator that never found the checkbox at all
    /// would also "go red" under `.center`.
    @Test func theMarksStayWhereTheyWereWhenTheRowGainsItsLines() throws {
        let plain = try pixels(of: row(summary: nil, rise: nil).frame(width: rowWidth))
        let withLines = try pixels(of: row(summary: risingSummary, rise: try rise()).frame(width: rowWidth))

        let plainCheckbox = try #require(checkboxTop(in: plain), "no brass block in the left 40 pt of the plain row")
        let linedCheckbox = try #require(checkboxTop(in: withLines), "no brass block in the left 40 pt of the row with the lines")
        let plainRing = try #require(ringTop(in: plain), "no dial ring in the rightmost 50 pt of the plain row")
        let linedRing = try #require(ringTop(in: withLines), "no dial ring in the rightmost 50 pt of the row with the lines")

        print("SellPlanRow marks — checkbox top y: plain \(plainCheckbox), with lines \(linedCheckbox); dial ring top y: plain \(plainRing), with lines \(linedRing)")

        #expect(
            plainCheckbox == Int(ThemeMetrics.standard.cardPadding),
            "the locator found y \(plainCheckbox) on a top-aligned plain row, not the card's own \(ThemeMetrics.standard.cardPadding) pt padding — it is measuring something other than the checkbox"
        )
        // The ring locator is bounded in neither axis — the shape the checkbox
        // locator was found false twice for at sign-off — so it carries its
        // own instrument too: the dial's 2 pt stroke is centred on a circle
        // inscribed in the 36 pt frame, so its top ink sits exactly 1 pt
        // above the frame top, one above the checkbox. A locator that had
        // latched onto quiet text in the right column would land elsewhere.
        #expect(
            plainRing == Int(ThemeMetrics.standard.cardPadding) - 1,
            "the ring locator found y \(plainRing) on the plain row, not the stroke's 1 pt spill above the \(ThemeMetrics.standard.cardPadding) pt padding — it is measuring something other than the dial"
        )
        #expect(plainCheckbox == linedCheckbox, "the checkbox moved from y \(plainCheckbox) to y \(linedCheckbox) when the row gained its two lines")
        #expect(plainRing == linedRing, "the dial moved from y \(plainRing) to y \(linedRing) when the row gained its two lines")
    }

    // MARK: - Fixtures

    private var item: Item {
        Item(
            name: "Fender Blues Junior IV",
            categoryPath: "Music/Amps",
            currentValueCents: 64_000,
            desireToKeep: 2
        )
    }

    /// `MarketSummary` has one initialiser and `MarketSnapshotValue` one
    /// under it, so the fixture is built the way `MarketIndexTests` builds
    /// one: a record in memory, no context.
    private var risingSummary: MarketSummary {
        let record = MarketFigureRecord(subjectID: UUID(), subjectKind: .owned, productID: 126_161, fetchedAt: now)
        record.medianCents = 140_000
        record.count = 5
        record.trendRawValue = MarketTrend.up.rawValue
        return MarketSummary(snapshot: MarketSnapshotValue(record: record), now: now)
    }

    /// +12 % against a reading in the previous calendar year, so the sentence
    /// carries its year too — the longest form the line can take.
    private func rise() throws -> MarketRise {
        try #require(MarketRise(comparison: MarketTrend.Comparison(
            latestCents: 140_000,
            previousCents: 125_000,
            previousAt: now.addingTimeInterval(-200 * 24 * 60 * 60),
            trend: .up
        )))
    }

    private func row(summary: MarketSummary?, rise: MarketRise?) -> some View {
        SellPlanRow(item: item, isSelected: true, toggle: {}, summary: summary, rise: rise, now: now)
    }

    // MARK: - Instruments

    private func pixels(of view: some View) throws -> Bitmap {
        let image = try #require(renderBitmap(view.background(colors.surface)), "ImageRenderer produced nothing to sample.")
        return try #require(Bitmap(image), "Couldn't read the rendered pixels.")
    }

    private func rowHeight(summary: MarketSummary?, rise: MarketRise?) throws -> Int {
        try #require(
            renderBitmap(row(summary: summary, rise: rise).frame(width: rowWidth)),
            "ImageRenderer produced nothing to measure."
        ).height
    }

    private func contains(_ bitmap: Bitmap, _ color: Color) -> Bool {
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                if Perceptual.distance(pixel, color) < tolerance { return true }
            }
        }
        return false
    }

    /// The topmost y at which at least `minimumColumns` adjacent columns of
    /// the left 40 pt each carry a run of at least `minimumRun` brass pixels
    /// starting there — a block bounded in both axes, which neither edge of a
    /// 1 pt border can satisfy.
    private func checkboxTop(in bitmap: Bitmap, minimumRun: Int = 10, minimumColumns: Int = 10) -> Int? {
        let searchWidth = min(40, bitmap.width)
        for y in 0..<max(0, bitmap.height - minimumRun) {
            var adjacent = 0
            for x in 0..<searchWidth {
                if isBrassRun(in: bitmap, x: x, from: y, length: minimumRun) {
                    adjacent += 1
                    if adjacent >= minimumColumns { return y }
                } else {
                    adjacent = 0
                }
            }
        }
        return nil
    }

    private func isBrassRun(in bitmap: Bitmap, x: Int, from y: Int, length: Int) -> Bool {
        for offset in 0..<length {
            guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y + offset)),
                  Perceptual.distance(pixel, colors.accentBrass) < tolerance
            else { return false }
        }
        return true
    }

    /// The dial's ring, sampled the way `DesireGaugeTests` samples the ramp:
    /// against the token it is drawn in. At desire 2 the filled arc reaches
    /// only the dial's left flank, so the ink at the top of the ring is the
    /// **track**, `divider` — and the selected card's border is brass here,
    /// so nothing else in the rightmost 50 pt wears it.
    private func ringTop(in bitmap: Bitmap) -> Int? {
        let start = max(0, bitmap.width - 50)
        for y in 0..<bitmap.height {
            for x in start..<bitmap.width {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                if Perceptual.distance(pixel, colors.divider) < tolerance { return y }
            }
        }
        return nil
    }
}

/// Where the two lines are drawn, and what they are allowed to be — the half
/// the render tests can't see, since a row that composes neither renders
/// perfectly well, and a label moved off the `Text` and onto the `HStack`
/// changes not one pixel.
@Suite("SellPlanMarketLines wiring")
struct SellPlanMarketLinesWiringTests {
    private static let lines = "Trove/Views/Market/SellPlanMarketLines.swift"
    private static let screen = "Trove/Views/Wishlist/SellPlanView.swift"

    /// Inside `SellPlanRow`'s own brace-matched body, so a preview or a
    /// helper nobody calls can't satisfy it.
    @Test func theRowComposesBothLinesAndStaysTopAlignedAndCombined() throws {
        let code = try SourceScan.production(Self.screen)
        let row = try body(of: "struct SellPlanRow: View {", in: code)

        #expect(row.contains("SellPlanMarketLine("), "the row draws no market line")
        #expect(row.contains("SellPlanReasonLine("), "the row draws no reason line")
        #expect(
            row.contains("trend: summary?.currentTrend"),
            "the row builds the market line without the summary's current trend, so every arrow on the plan would be the parameter's nil"
        )
        #expect(
            row.contains("HStack(alignment: .top"),
            "the row's stack isn't top-aligned, so its marks drift as the lines arrive (criterion 11)"
        )
        #expect(
            row.contains(".accessibilityElement(children: .combine)"),
            "the row is no longer combined, so the market line's label reads as a stop of its own rather than part of the row's sentence"
        )
    }

    /// The list hands over all three readers — the row derives nothing.
    @Test(arguments: [
        "summary: viewModel.summary(for:",
        "rise: viewModel.rise(for:",
        "now: viewModel.loadedAt",
    ])
    func theListPassesEveryReaderIntoTheRow(wiring: String) throws {
        let code = try SourceScan.production(Self.screen)
        #expect(code.contains(wiring), "\(Self.screen): the row is built without `\(wiring)`")
    }

    @Test(arguments: [
        "\"sellPlan.market\"",
        "\"sellPlan.reason\"",
        "MarketCopy.sellPlanMarketLine(",
        "MarketCopy.sellPlanReason(",
        "MarketCopy.figureAccessibilityLabel(",
    ])
    func theLinesCarryTheirIdentifiersAndReadEveryStringThroughMarketCopy(token: String) throws {
        let code = try SourceScan.production(Self.lines)
        #expect(code.contains(token), "\(Self.lines): `\(token)` is gone")
    }

    /// The label belongs to the figure, not to the pair. On the `Text` it
    /// joins the arrow's "trending up" under the row's `.combine`; on the
    /// `HStack` it replaces it, and the row stops saying which way the market
    /// went. Both halves are needed: the first finds it before the arrow, the
    /// second finds none after it.
    @Test func theFiguresLabelSitsOnTheTextAndNotOnTheStackAroundTheArrow() throws {
        let code = try SourceScan.production(Self.lines)
        let figure = try #require(code.range(of: "Text(MarketCopy.sellPlanMarketLine("), "the market line's Text is gone")
        let arrows = code.ranges(of: "TrendArrow(")
        let firstArrow = try #require(arrows.first, "the market line draws no arrow")

        #expect(
            code[figure.upperBound..<firstArrow.lowerBound].contains(".accessibilityLabel("),
            "the figure's label isn't in the Text's own modifier chain"
        )
        #expect(
            !code[arrows[arrows.count - 1].upperBound...].contains(".accessibilityLabel("),
            "a label sits after the arrow — on the HStack, which would swallow the arrow's own half of the sentence"
        )
    }

    /// `TrendArrowWiringTests`' helper: a scan over the whole file would be
    /// satisfied by a preview or by a neighbouring declaration.
    private func body(of declaration: String, in code: String) throws -> String {
        let start = try #require(code.range(of: declaration), "\(declaration) is gone")
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        Issue.record("\(declaration) never closes")
        return ""
    }
}
