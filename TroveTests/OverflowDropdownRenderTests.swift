import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The overflow dropdown's new drawing (013 Amendment A, criteria 21–22),
/// checked in pixels rather than in call-site arguments: a `startsGroup`
/// wired to nothing or a disabled colour dropped would each leave every
/// source scan green. The desire-dial instrument — render, sample, measure.
///
/// Rendered with the first-row focus marking off, as every render test
/// must be (see `DropdownSurface`).
@Suite("Overflow dropdown render")
struct OverflowDropdownRenderTests {
    private let colors = ThemeColors.dark

    /// The floor `DesireDialColorTests` and `DesireGaugeTests` hold their
    /// stops to — two marks that must read differently are separated to the
    /// same standard here.
    private let floor = 0.06

    /// A column in the empty right-hand part of every row, clear of the
    /// titles, so what it crosses is the hairlines and the fill.
    private let sampleColumn: CGFloat = 200

    // MARK: - Group breaks

    /// Three hairlines cross the sample column between the top and bottom
    /// borders: the row separator under the first export, then the two
    /// group breaks. The breaks must read as a stronger rule than the
    /// separator — drawn in `divider`, not `surfaceInset` — by the Oklab
    /// floor, not by arithmetic.
    @Test func theTwoGroupBreaksReadStrongerThanTheRowSeparator() throws {
        let bitmap = try render(canExportCSV: true, canExportPDF: true)
        let hairlines = try hairlineRows(in: bitmap)
        try #require(hairlines.count == 3, "expected the separator and two breaks, found hairlines at \(hairlines.map(\.y))")

        let separator = hairlines[0].pixel
        let breaks = [hairlines[1].pixel, hairlines[2].pixel]
        for brk in breaks {
            #expect(
                Perceptual.distance(brk, separator) >= floor,
                "a group break (\(brk)) must be distinguishable from the separator (\(separator))"
            )
            #expect(
                Perceptual.distance(brk, colors.divider) < Perceptual.distance(brk, colors.surfaceInset),
                "a group break must be drawn in divider, not surfaceInset — got \(brk)"
            )
        }
        #expect(
            Perceptual.distance(separator, colors.surfaceInset) < Perceptual.distance(separator, colors.divider),
            "the row separator must stay surfaceInset — got \(separator)"
        )
    }

    // MARK: - Disabled rows

    /// SwiftUI's own disabled dimming on a `.plain` button's label: measured
    /// at T021 as a further 0.5 on the text's alpha, composited in sRGB. If
    /// the platform changes it, this is the number that goes stale — and
    /// the test that says so.
    private let buttonDimming = 0.5

    /// With something to export, the export rows' titles are `textBody`;
    /// with nothing, `textDisabled` — *under* the button's own dimming, the
    /// compound `SettingsActionRow` ships. Checked as the fraction of ink
    /// each title's brightest pixel carries over the surface, so a dropped
    /// token (a title dimmed by the button alone, at twice the ink) fails,
    /// where "closer to the disabled token than the body one" did not.
    @Test func theExportRowsDimWhenThereIsNothingToExport() throws {
        let disabled = inkFraction(try brightestTitlePixel(inRow: 0, of: try render(canExportCSV: false, canExportPDF: false)))
        let enabled = inkFraction(try brightestTitlePixel(inRow: 0, of: try render(canExportCSV: true, canExportPDF: true)))

        #expect(abs(enabled - bodyAlpha) < 0.03, "an enabled title is textBody (\(bodyAlpha)) — measured \(enabled)")
        #expect(
            abs(disabled - disabledAlpha * buttonDimming) < 0.03,
            "a disabled title is textDisabled (\(disabledAlpha)) under the button's \(buttonDimming) dimming — measured \(disabled)"
        )
    }

    /// 006: the two export rows carry *separate* gates (plan Q5) — an
    /// all-sold collection has a CSV to write and no PDF — so each row must
    /// dim on its own flag. Measured in pixels rather than at the call site
    /// for this file's founding reason: a second row wired to the first
    /// row's flag leaves every source scan green, because the argument
    /// `canExportPDF:` would still be there.
    ///
    /// Both directions, so neither row can be the one that happens to be
    /// right. Mutation: gate the PDF row on `canExportCSV` → red.
    @Test(arguments: [true, false])
    func eachExportRowDimsOnItsOwnGate(csvEnabled: Bool) throws {
        let bitmap = try render(canExportCSV: csvEnabled, canExportPDF: !csvEnabled)
        let csv = inkFraction(try brightestTitlePixel(inRow: 0, of: bitmap))
        let pdf = inkFraction(try brightestTitlePixel(inRow: 1, of: bitmap))

        let expectedCSV = csvEnabled ? bodyAlpha : disabledAlpha * buttonDimming
        let expectedPDF = csvEnabled ? disabledAlpha * buttonDimming : bodyAlpha
        #expect(
            abs(csv - expectedCSV) < 0.03,
            "the CSV row follows canExportCSV (\(csvEnabled)): expected \(expectedCSV), measured \(csv)"
        )
        #expect(
            abs(pdf - expectedPDF) < 0.03,
            "the PDF row follows canExportPDF (\(!csvEnabled)): expected \(expectedPDF), measured \(pdf)"
        )
    }

    private var bodyAlpha: Double { Double(colors.textBody.resolve(in: EnvironmentValues()).opacity) }
    private var disabledAlpha: Double { Double(colors.textDisabled.resolve(in: EnvironmentValues()).opacity) }

    // MARK: - Helpers

    /// How much ink a pixel carries over the surface, per channel averaged:
    /// the alpha the text was composited at, recovered from the sRGB bytes
    /// (SwiftUI composites in sRGB, which the T021 measurement confirmed to
    /// the byte).
    private func inkFraction(_ pixel: RGB8) -> Double {
        let ink = colors.textPrimary.resolve(in: EnvironmentValues())
        let surface = colors.surface.resolve(in: EnvironmentValues())
        func fraction(_ value: Int, _ top: Float, _ under: Float) -> Double {
            (Double(value) / 255 - Double(under)) / Double(top - under)
        }
        return (
            fraction(pixel.red, ink.red, surface.red)
                + fraction(pixel.green, ink.green, surface.green)
                + fraction(pixel.blue, ink.blue, surface.blue)
        ) / 3
    }

    private func render(canExportCSV: Bool, canExportPDF: Bool) throws -> Bitmap {
        let view = OverflowDropdown(
            canExportCSV: canExportCSV,
            canExportPDF: canExportPDF,
            exportCSV: {},
            exportPDF: {},
            importCSV: {},
            openSettings: {}
        )
        .environment(\.dropdownFocusesFirstRow, false)
        let image = try #require(renderBitmap(view), "ImageRenderer produced nothing to sample.")
        return try #require(Bitmap(image), "Couldn't read the rendered pixels.")
    }

    private struct Hairline {
        let y: Int
        let pixel: RGB8
    }

    /// Every row of pixels between the borders where the sample column is
    /// not surface — the hairlines, wherever the rows' heights put them.
    /// The plate's own bottom edge-shadow sits just above the bottom border
    /// and is excluded with it.
    private func hairlineRows(in bitmap: Bitmap) throws -> [Hairline] {
        var found: [Hairline] = []
        for y in 1..<(bitmap.height - 2) {
            let pixel = try #require(bitmap.pixel(at: CGPoint(x: sampleColumn, y: CGFloat(y))))
            if Perceptual.distance(pixel, colors.surface) >= floor / 2 {
                found.append(Hairline(y: y, pixel: pixel))
            }
        }
        return found
    }

    /// The brightest pixel in a row's title area, the row's band found from
    /// the hairlines rather than hard-coded, so row 1 is measured the same
    /// way row 0 always was and neither goes stale if a metric moves.
    private func brightestTitlePixel(inRow index: Int, of bitmap: Bitmap) throws -> RGB8 {
        let hairlines = try hairlineRows(in: bitmap)
        try #require(hairlines.count == 3, "expected the separator and two breaks, found \(hairlines.count)")
        let tops = [8, hairlines[0].y + 5]
        let bottoms = [hairlines[0].y - 4, hairlines[1].y - 4]
        let band = tops[index]..<bottoms[index]
        try #require(band.count > 10, "row \(index)'s title band came out as \(band)")

        var brightest = RGB8(red: 0, green: 0, blue: 0)
        for y in band {
            for x in 14..<120 {
                let pixel = try #require(bitmap.pixel(at: CGPoint(x: x, y: y)))
                if pixel.red + pixel.green + pixel.blue > brightest.red + brightest.green + brightest.blue {
                    brightest = pixel
                }
            }
        }
        return brightest
    }
}
