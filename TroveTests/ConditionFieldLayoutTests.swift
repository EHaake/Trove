import CoreGraphics
import SwiftUI
import Testing
@testable import Trove

/// G14's measured legs — `020` criterion 18 as widths rather than as a
/// sentence (plan §6, Amendment A): the six condition chips sit on one
/// sideways-scrolling row, and **no chip is squeezed** narrower than its
/// words need.
///
/// The chips are rendered **alone**, with `ImageRenderer` under a real theme
/// — `ItemListHeaderLayoutTests`' instrument — and never inside the
/// `ScrollView`: a static render cannot observe scrolling, so that the row
/// *is* one row, overflows, scrolls and opens on the selected grade is the UI
/// suite's (`testTheConditionRowIsOneScrollingRowAndOpensOnTheSelectedGrade`,
/// `testThePurchaseSheetsConditionRowIsOneScrollingRow`).
///
/// **Not tested anywhere:** the *look* of the chip cut off at the screen edge.
/// Leg (d) is the premise of that arithmetic, not its appearance.
@Suite("Condition field layout")
@MainActor
struct ConditionFieldLayoutTests {
    /// `ChoiceChip`'s horizontal padding, each side.
    private let chipPadding: CGFloat = 14

    /// The field's width on the phones the row is checked against: the
    /// window less the two screen gutters. 375 pt is the narrowest the app
    /// runs on (plan Q9); 402 pt the Pro the UI suite is pinned to; 440 pt
    /// the Pro Max.
    private let fieldWidths: [CGFloat] = [375, 402, 440].map { $0 - 2 * ThemeMetrics.standard.screenGutter }

    /// Leg (b): each chip is at least its title's rendered width plus the two
    /// paddings — none squeezed.
    ///
    /// Recorded, not asserted: each chip's width, the six-chip total with
    /// spacing, and that total against each field width. The total is why
    /// the row scrolls at all, but a scroll view reaches any chip at any
    /// width, so nothing here depends on which side of a width it falls.
    ///
    /// Mutation: `.frame(width: 60)` on `ChoiceChip` → red.
    @Test func noConditionChipIsNarrowerThanItsTitleAndPadding() throws {
        var widths: [(title: String, width: CGFloat)] = []

        for condition in Condition.allCases {
            let title = condition.rawValue.capitalized
            let chip = try #require(
                renderAt3x(ChoiceChip(title: title, isSelected: false) {}),
                "ImageRenderer produced nothing to measure for the \"\(title)\" chip."
            )
            let words = try #require(
                renderAt3x(Text(title).font(Theme.dark.typography.secondary)),
                "ImageRenderer produced nothing to measure for the title \"\(title)\"."
            )
            let needed = words.width + Int(2 * chipPadding) * 3

            #expect(
                chip.width >= needed,
                "the \"\(title)\" chip is \(chip.width) px wide at 3× — its title needs \(words.width) px plus two \(chipPadding) pt paddings, \(needed) px, so it is squeezed"
            )
            widths.append((title, CGFloat(chip.width) / 3))
        }

        try #require(widths.count == 6, "the condition row has \(widths.count) chips, expected 6")

        let total = widths.reduce(0) { $0 + $1.width } + ConditionField.chipSpacing * CGFloat(widths.count - 1)
        let chips = widths
            .map { "\($0.title) \(String(format: "%.2f", $0.width))" }
            .joined(separator: ", ")
        let against = fieldWidths
            .map { "\(Int($0)) pt: \(total > $0 ? "overflows by" : "fits with") \(String(format: "%.2f", abs(total - $0))) pt" }
            .joined(separator: "; ")
        var trailingEdges: [String] = []
        var edge: CGFloat = 0
        for chip in widths {
            edge += chip.width
            trailingEdges.append("\(chip.title) \(String(format: "%.2f", edge))")
            edge += ConditionField.chipSpacing
        }
        print("ConditionField chips — widths: \(chips); six-chip total with \(ConditionField.chipSpacing) pt spacing: \(String(format: "%.2f", total)) pt; against \(against); trailing edges from the row's start: \(trailingEdges.joined(separator: ", "))")
    }

    /// Leg (d): the chips sit closer together than the gutter is wide. That
    /// is the premise of the cut-off chip — with the gap between two chips
    /// narrower than the gutter the row draws through, the gutter can never
    /// hold only a gap on a side that has more to scroll to.
    ///
    /// The premise of the arithmetic, not its look: nothing here renders the
    /// row at the screen edge.
    ///
    /// Mutation: `chipSpacing = 24` → red.
    @Test func theChipsSitCloserTogetherThanTheGutterIsWide() {
        #expect(
            ConditionField.chipSpacing < ThemeMetrics.standard.screenGutter,
            "the chips are \(ConditionField.chipSpacing) pt apart and the gutter is \(ThemeMetrics.standard.screenGutter) pt — a gap that wide can fill the gutter, leaving no chip cut off at the edge to show the row scrolls"
        )
    }

    /// A view rendered at 3×, the device's scale, so a fraction of a point
    /// shows as whole pixels rather than rounding away.
    private func renderAt3x(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.environment(\.theme, .dark))
        renderer.scale = 3
        return renderer.cgImage
    }
}
