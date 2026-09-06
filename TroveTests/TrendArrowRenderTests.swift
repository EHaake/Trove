import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The trend arrow in pixels (spec criterion 13, Decision 8): moss up, rust
/// down, and — the half that can only be checked by measuring — *nothing at
/// all* for a flat or absent trend.
///
/// The desire-dial instrument again: render, sample, measure. A token swapped
/// for a neighbouring accent leaves every source scan green, and "the flat
/// case draws `EmptyView`" is a claim about layout, not about a branch: the
/// arrow could take the row's space while drawing no ink and no assertion
/// over the source would notice.
@Suite("TrendArrow render")
struct TrendArrowRenderTests {
    private let colors = ThemeColors.dark

    /// The rendered ink is the token itself at full strength, so the
    /// tolerance only has to cover 8-bit rounding — nothing like the 0.06
    /// perceptual floor the ramps are held to, which is a "these two must
    /// look different" distance rather than "this is that colour".
    private let tolerance = 0.02

    @Test func aRisingTrendDrawsInTheMossTextTone() throws {
        let ink = try ink(of: .up)
        #expect(
            Perceptual.distance(ink, colors.accentMossText) < tolerance,
            "a rising arrow is accentMossText — measured \(ink), ΔE \(Perceptual.distance(ink, colors.accentMossText))"
        )
        #expect(
            Perceptual.distance(ink, colors.accentMossText) < Perceptual.distance(ink, colors.accentRustText),
            "a rising arrow read closer to the falling tone — measured \(ink)"
        )
    }

    @Test func aFallingTrendDrawsInTheRustTextTone() throws {
        let ink = try ink(of: .down)
        #expect(
            Perceptual.distance(ink, colors.accentRustText) < tolerance,
            "a falling arrow is accentRustText — measured \(ink), ΔE \(Perceptual.distance(ink, colors.accentRustText))"
        )
        #expect(
            Perceptual.distance(ink, colors.accentRustText) < Perceptual.distance(ink, colors.accentMossText),
            "a falling arrow read closer to the rising tone — measured \(ink)"
        )
    }

    /// The two tones are also the row's own delta colours, which is the
    /// point: the arrow says the same thing in the same voice. What it must
    /// *not* be is the brass the figure itself is set in.
    @Test func neitherArrowIsTheBrassTheFiguresWear() throws {
        for trend in [MarketTrend.up, .down] {
            let ink = try ink(of: trend)
            #expect(
                Perceptual.distance(ink, colors.accentBrass) > tolerance,
                "\(trend) drew in accentBrass — measured \(ink)"
            )
        }
    }

    /// Measured positively, so "flat draws nothing" is falsifiable: the host
    /// is exactly as wide with a flat arrow in it as without one, while an
    /// arrow that *does* draw widens the same host. Without that second half
    /// the test would pass over a `TrendArrow` that had been deleted.
    @Test(arguments: [MarketTrend.flat, nil])
    func aFlatOrAbsentTrendTakesNoRoomInTheRow(trend: MarketTrend?) throws {
        let bare = try width(of: HStack { Text("X") })
        let withArrow = try width(of: HStack { Text("X"); TrendArrow(trend: trend) })
        let withRise = try width(of: HStack { Text("X"); TrendArrow(trend: .up) })

        #expect(withArrow == bare, "a \(String(describing: trend)) arrow took \(withArrow - bare) points of the row")
        #expect(withRise > bare, "the control failed: even a rising arrow took no room, so this measures nothing")
    }

    // MARK: - Helpers

    /// The arrow's own ink: the sampled pixel furthest from the transparent
    /// black the renderer composites onto, which is the fill at full
    /// strength — every other pixel is an antialiased fraction of it.
    private func ink(of trend: MarketTrend) throws -> RGB8 {
        let image = try #require(renderBitmap(TrendArrow(trend: trend)), "ImageRenderer produced nothing to sample.")
        let bitmap = try #require(Bitmap(image), "Couldn't read the rendered pixels.")
        let backdrop = RGB8(red: 0, green: 0, blue: 0)

        var brightest: RGB8?
        var distance = 0.0
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                let reach = Perceptual.distance(pixel, backdrop)
                if reach > distance {
                    distance = reach
                    brightest = pixel
                }
            }
        }

        return try #require(brightest, "the \(trend) arrow drew no ink at all")
    }

    private func width(of view: some View) throws -> Int {
        try #require(renderBitmap(view), "ImageRenderer produced nothing to measure.").width
    }
}

/// Where the arrow is drawn — the half the render tests can't see, since a
/// row that never composes a `TrendArrow` renders perfectly well.
///
/// Both branches of the item row's value line carry it (the trend describes
/// the market, not the person's own figure, so "Not yet valued" gets one
/// too), the wanted row carries exactly one and carries it *after* the cost,
/// and both lists hand their view model's trend to the row rather than
/// leaving the parameter at its default.
@Suite("TrendArrow wiring")
struct TrendArrowWiringTests {
    @Test func bothBranchesOfTheItemRowsValueLineDrawTheArrow() throws {
        let code = try SourceScan.production("Trove/Views/Items/ItemRow.swift")
        let valueLine = try body(of: "private var valueLine: some View {", in: code)

        #expect(
            valueLine.ranges(of: "TrendArrow(trend:").count == 2,
            "the value line draws \(valueLine.ranges(of: "TrendArrow(trend:").count) arrows — one per branch is two"
        )
    }

    @Test func theWantedRowDrawsOneArrowAfterTheCost() throws {
        let code = try SourceScan.production("Trove/Views/Wishlist/WishlistView.swift")
        let arrows = code.ranges(of: "TrendArrow(trend:")
        try #require(arrows.count == 1, "the wanted row draws \(arrows.count) arrows — Decision 8 gives it one mark and no other")

        let cost = try #require(
            code.range(of: "Text(item.estimatedCostCents"),
            "the cost the arrow sits beside is gone"
        )
        #expect(arrows[0].lowerBound > cost.upperBound, "the arrow reads before the cost, whose own label should come first")
    }

    @Test(arguments: [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ])
    func bothListsHandTheirRowsTheViewModelsTrend(file: String) throws {
        let code = try SourceScan.production(file)
        #expect(
            code.contains("trend: viewModel.trend(for:"),
            "\(file): the row is built without a trend, so every arrow would be the parameter's nil default"
        )
    }

    /// `valueLine`'s own body, brace-matched — a scan over the whole file
    /// would be satisfied by the preview, or by one branch drawing two.
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
