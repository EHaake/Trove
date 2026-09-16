import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// T015. What a Sold-side row says and what colour it says it in — criterion
/// 7's "each row making unmistakable whether it sold at a gain or at a loss
/// and by how much", which is two claims, not one.
///
/// The words are read off the row's own composed lines rather than off
/// `SaleCopy` directly, so a row that started composing its own wording fails
/// here; the colour is measured on a render, the `SellPlanMarketLines` /
/// `TrendArrow` instrument, because no source scan can tell a moss pixel from
/// a rust one.
@Suite("Sold item row")
@MainActor
struct SoldItemRowTests {
    private let colors = ThemeColors.dark

    /// Full-strength token ink against 8-bit rounding and the anti-aliasing a
    /// glyph's stem carries — the tolerance the other render suites measure
    /// palette tokens with.
    private let tolerance = 0.02

    /// Wide enough that neither the price nor the outcome truncates.
    private let rowWidth: CGFloat = 360

    // MARK: - What the row says (Decision 11)

    /// A sale under what was paid reads the loss and its amount, in words.
    ///
    /// **Mutation:** gate `SaleCopy.rowOutcome` on `deltaCents > 0` only
    /// (rather than `!= 0`) → a loss reads "At cost" → red.
    @Test func aRowOverALossReadsTheLossAndItsAmount() throws {
        let row = SoldItemRow(item: sold(paid: 69_000, price: 54_000))

        #expect(row.outcomeText == "Loss $150 vs paid")
    }

    @Test func aRowOverAGainReadsTheGainAndItsAmount() throws {
        let row = SoldItemRow(item: sold(paid: 85_000, price: 120_000))

        #expect(row.outcomeText == "Gain $350 vs paid")
    }

    /// The one outcome with no figure in it — breaking even is not a loss
    /// (`SaleOutcome.isLoss`'s `< 0` boundary), and the row says so in words.
    @Test func aRowOverEqualFiguresReadsAtCost() throws {
        let row = SoldItemRow(item: sold(paid: 66_000, price: 66_000))

        #expect(row.outcomeText == "At cost")
    }

    /// The date line is the *sale's* date, not the purchase's — the two are
    /// years apart here, so reading the wrong one shows.
    @Test func theRowNamesTheSaleDateAndNotThePurchaseDate() throws {
        let row = SoldItemRow(item: sold(
            paid: 85_000,
            price: 120_000,
            purchased: date(year: 2019, month: 4, day: 2),
            soldOn: date(year: 2026, month: 9, day: 12)
        ))
        let line = try #require(row.dateLine)

        #expect(line.hasPrefix("Sold "), "the row's date line doesn't say what happened: \(line)")
        #expect(line.contains("2026"), "the row doesn't show the year it sold in: \(line)")
        #expect(!line.contains("2019"), "the row's date line is the purchase date: \(line)")
    }

    /// The figure is what it sold for. The item also carries a current value,
    /// which is the figure an Owned row would show and the wrong one here.
    @Test func theRowShowsTheSalePriceAndNotTheValueOrTheCost() throws {
        let item = sold(paid: 85_000, price: 120_000)
        item.currentValueCents = 99_900

        #expect(SoldItemRow(item: item).priceText == "$1,200")
    }

    /// An item with no sale has no business on this side, and reaching the row
    /// with one anyway draws the name alone rather than inventing a sale —
    /// `Item.sale` is optional by type, so the case exists whether or not the
    /// list can produce it.
    @Test func anUnsoldItemDrawsNoSaleLines() throws {
        let row = SoldItemRow(item: Item(name: "Leica M6", purchasePriceCents: 290_000))

        #expect(row.dateLine == nil)
        #expect(row.priceText == nil)
        #expect(row.outcomeText == nil)
    }

    // MARK: - What colour it says it in (plan Q11)

    /// The colour repeats the word and never replaces it: rust for a loss,
    /// moss for a gain.
    ///
    /// **Mutation:** invert the `isLoss` arm of `outcomeColor` → the loss row
    /// paints moss and the gain row rust → both halves red.
    @Test func aLossPaintsRustAndAGainPaintsMoss() throws {
        let loss = try pixels(of: sold(paid: 69_000, price: 54_000))
        let gain = try pixels(of: sold(paid: 85_000, price: 120_000))

        print("SoldItemRow ink — loss: rust \(closest(loss, colors.accentRustText)), moss \(closest(loss, colors.accentMossText)); gain: rust \(closest(gain, colors.accentRustText)), moss \(closest(gain, colors.accentMossText))")

        #expect(contains(loss, colors.accentRustText), "a loss row draws no rust text")
        #expect(!contains(loss, colors.accentMossText), "a loss row draws the gain tone")
        #expect(contains(gain, colors.accentMossText), "a gain row draws no moss text")
        #expect(!contains(gain, colors.accentRustText), "a gain row draws the loss tone")
    }

    /// The control for the pair above: a sale at cost wears neither tone, so
    /// the two expectations there are reading the outcome rather than some
    /// other ink the row happens to carry.
    @Test func anAtCostRowPaintsNeitherTone() throws {
        let atCost = try pixels(of: sold(paid: 66_000, price: 66_000))

        #expect(!contains(atCost, colors.accentRustText), "a row that sold at cost draws the loss tone")
        #expect(!contains(atCost, colors.accentMossText), "a row that sold at cost draws the gain tone")
    }

    // MARK: - Fixtures and instruments

    private func sold(
        paid: Int,
        price: Int,
        purchased: Date = Date(timeIntervalSince1970: 1_500_000_000),
        soldOn: Date = Date(timeIntervalSince1970: 1_780_000_000),
        name: String = "Technics SL-1200"
    ) -> Item {
        let item = Item(
            name: name,
            categoryPath: "Audio/Turntables",
            purchasePriceCents: paid,
            purchaseDate: purchased
        )
        item.sale = Sale(date: soldOn, priceCents: price, location: "eBay", note: nil)
        return item
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func pixels(of item: Item) throws -> Bitmap {
        let image = try #require(
            renderBitmap(SoldItemRow(item: item).frame(width: rowWidth)),
            "ImageRenderer produced nothing to sample."
        )
        return try #require(Bitmap(image), "Couldn't read the rendered pixels.")
    }

    private func contains(_ bitmap: Bitmap, _ color: Color) -> Bool {
        closest(bitmap, color) < tolerance
    }

    /// The nearest any pixel comes to a token, printed by the colour test so a
    /// threshold that stopped finding anything shows as a number rather than
    /// as a silent pass.
    private func closest(_ bitmap: Bitmap, _ color: Color) -> Double {
        var best = Double.greatestFiniteMagnitude
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                best = min(best, Perceptual.distance(pixel, color))
            }
        }
        return best
    }
}
