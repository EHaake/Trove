import CoreGraphics
import CoreText
import Foundation
// SwiftUI here is for `Font.Weight` alone — `FontFamily.postScriptName(for:)`
// takes it, and reusing that one source of face names is what keeps
// `FontRegistrationTests` covering the PDF (plan.md's typography decision).
// Nothing else from SwiftUI belongs in this module.
import SwiftUI

nonisolated enum PDFComposerError: Error {
    case contextUnavailable
}

/// The print-only palette from plan.md's document design, recorded in
/// `design/tokens.md` (T016). The dark-UI tokens are for screens; this is a
/// document for paper — including the brass, darkened from the UI's
/// `#C79A56` to clear 4.5:1 on white.
nonisolated enum PrintPalette {
    static var paper: CGColor { color(0xFFFFFF) }
    static var ink: CGColor { color(0x1C1A17) }
    static var secondary: CGColor { color(0x6A645C) }
    static var hairline: CGColor { color(0xD8D3CA) }
    static var brass: CGColor { color(0x8F6E3E) }

    private static func color(_ hex: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The print type scale — the same three faces as the app via
/// `FontFamily.postScriptName(for:)`, at a deliberately separate,
/// print-specific set of sizes (plan.md: `ThemeTypography` holds opaque
/// screen-sized `Font` values, so sizes can't be shared; nobody should later
/// "unify" them).
nonisolated enum PrintType {
    static func display(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName(FontFamily.display.postScriptName(for: .semibold) as CFString, size, nil)
    }

    static func sans(_ size: CGFloat) -> CTFont {
        CTFontCreateWithName(FontFamily.body.postScriptName(for: .regular) as CFString, size, nil)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> CTFont {
        CTFontCreateWithName(FontFamily.mono.postScriptName(for: weight) as CFString, size, nil)
    }
}

/// Renders the export PDF with CoreGraphics + CoreText (+ ImageIO from T008)
/// — deliberately no UIKit anywhere in this module, per plan.md's reviewed
/// renderer decision: `CTFramesetter` is the multi-page flow engine, and the
/// repo's own precedent (`RowThumbnailTests`) already chose CG over `UIImage`
/// to avoid a quiet UIKit dependency.
nonisolated enum PDFComposer {
    /// US Letter, per plan.md's document design (v1 is US/USD-only).
    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 54
    static var contentWidth: CGFloat { pageSize.width - margin * 2 }

    static func render(_ document: PDFDocumentModel) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw PDFComposerError.contextUnavailable }

        let writer = PageWriter(context: context)
        drawCover(document.cover, on: writer)
        writer.endPageIfOpen()
        context.closePDF()
        return data as Data
    }

    // MARK: - Cover

    /// plan.md's cover: wordmark, rule, title, the meta lines (generated
    /// date, coverage, count), then the totals block — figures computed by
    /// the view model (criterion 8) and drawn with the app's own display
    /// formatters.
    private static func drawCover(_ cover: CoverSummary, on writer: PageWriter) {
        writer.beginPage()
        writer.draw(styled("TROVE", font: PrintType.display(26), color: PrintPalette.ink, kern: 4))
        writer.advance(14)
        writer.drawRule()
        writer.advance(30)
        writer.draw(styled(cover.title, font: PrintType.display(20), color: PrintPalette.ink))
        writer.advance(14)

        let meta = [
            "Generated \(ExportSchema.day(from: cover.generatedAt))",
            cover.coverageLabel,
            countLine(for: cover),
        ]
        for line in meta {
            writer.draw(styled(line, font: PrintType.mono(10.5), color: PrintPalette.secondary))
            writer.advance(7)
        }
        writer.advance(20)

        switch cover.totals {
        case .items(let currentValueCents, let paidCents, let unvaluedCount):
            drawTotal(label: "TOTAL VALUE", cents: currentValueCents, color: PrintPalette.brass, on: writer)
            drawTotal(label: "TOTAL PAID", cents: paidCents, color: PrintPalette.ink, on: writer)
            if unvaluedCount > 0 {
                // The same honesty rule as the list header and dashboard:
                // un-valued items contribute nothing, so the figure above is
                // a floor and the document says so.
                writer.draw(styled(
                    "\(unvaluedCount) not yet valued — the value total is a floor",
                    font: PrintType.sans(9.5),
                    color: PrintPalette.secondary
                ))
                writer.advance(6)
            }
        case .wishlist(let estimatedCostCents):
            drawTotal(label: "TOTAL ESTIMATED COST", cents: estimatedCostCents, color: PrintPalette.brass, on: writer)
        }
    }

    private static func drawTotal(label: String, cents: Int, color: CGColor, on writer: PageWriter) {
        writer.draw(styled(label, font: PrintType.mono(7.5, weight: .medium), color: PrintPalette.secondary, kern: 1.2))
        writer.advance(4)
        writer.draw(styled(
            cents.formattedAsWholeCurrency(currencyCode: "USD"),
            font: PrintType.mono(15, weight: .medium),
            color: color
        ))
        writer.advance(16)
    }

    private static func countLine(for cover: CoverSummary) -> String {
        switch cover.totals {
        case .items: "\(cover.itemCount) \(cover.itemCount == 1 ? "item" : "items")"
        case .wishlist: "\(cover.itemCount) wanted"
        }
    }

    // MARK: - Text plumbing

    static func styled(
        _ string: String,
        font: CTFont,
        color: CGColor,
        kern: CGFloat = 0
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        if kern != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = kern
        }
        return NSAttributedString(string: string, attributes: attributes)
    }

    static func measuredHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: width, height: .greatestFiniteMagnitude),
            nil
        )
        return ceil(size.height)
    }
}

// MARK: - Page writer

/// Cursor-based page bookkeeping over the CG PDF context. The context's
/// origin is bottom-left; the cursor tracks the next free y from the top of
/// the content area downward, so "draw then advance" reads in document
/// order.
private nonisolated final class PageWriter {
    let context: CGContext
    private(set) var cursor: CGFloat = 0
    private var pageIsOpen = false

    init(context: CGContext) {
        self.context = context
    }

    /// Space left above the bottom margin.
    var remaining: CGFloat { cursor - PDFComposer.margin }

    func beginPage() {
        context.beginPDFPage(nil)
        context.setFillColor(PrintPalette.paper)
        context.fill(CGRect(origin: .zero, size: PDFComposer.pageSize))
        cursor = PDFComposer.pageSize.height - PDFComposer.margin
        pageIsOpen = true
    }

    func newPage() {
        endPageIfOpen()
        beginPage()
    }

    func endPageIfOpen() {
        guard pageIsOpen else { return }
        context.endPDFPage()
        pageIsOpen = false
    }

    func advance(_ height: CGFloat) {
        cursor -= height
    }

    func drawRule() {
        context.setFillColor(PrintPalette.hairline)
        context.fill(CGRect(
            x: PDFComposer.margin,
            y: cursor - 0.75,
            width: PDFComposer.contentWidth,
            height: 0.75
        ))
        advance(0.75)
    }

    /// Draws at the cursor and advances by the measured height. The frame
    /// rect gets a two-point allowance over the measurement so CoreText's
    /// own rounding never drops the last line.
    func draw(
        _ text: NSAttributedString,
        x: CGFloat = PDFComposer.margin,
        width: CGFloat = PDFComposer.contentWidth
    ) {
        let height = PDFComposer.measuredHeight(text, width: width)
        let rect = CGRect(x: x, y: cursor - height - 1, width: width, height: height + 2)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: 0),
            CGPath(rect: rect, transform: nil),
            nil
        )
        CTFrameDraw(frame, context)
        advance(height)
    }
}
