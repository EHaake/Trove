import CoreGraphics
import CoreText
import Foundation
import ImageIO
import SwiftData
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

    /// - Parameter imageData: hands back the blob for an entry's photo
    ///   identifier, or nil when it can't — the live service backs this with
    ///   batched background fetches (T008); nil means the entry lays out
    ///   photo-free, exactly like an entry that never had one.
    static func render(
        _ document: PDFDocumentModel,
        imageData: (PersistentIdentifier) -> Data? = { _ in nil }
    ) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw PDFComposerError.contextUnavailable }

        let writer = PageWriter(context: context)
        drawCover(document.cover, on: writer)
        // The cover stands alone; the collection begins on its own page.
        if !document.entries.isEmpty {
            writer.newPage()
        }
        for entry in document.entries {
            autoreleasepool {
                drawEntry(entry, on: writer, imageData: imageData)
            }
        }
        writer.endPageIfOpen()
        context.closePDF()
        return data as Data
    }

    // MARK: - Entries

    /// The reserved photo box (T008 draws into it); text narrows beside it.
    static let photoBox = CGSize(width: 132, height: 99)
    private static let photoGap: CGFloat = 16
    /// The gap between the photo box and its credit line (005, §7).
    private static let creditGap: CGFloat = 4
    private static let fieldLabelWidth: CGFloat = 96
    private static let fieldColumnGap: CGFloat = 10

    /// One item entry: rule, eyebrow + name (photo box top-right when the
    /// entry has one), the field grid, then notes flowed at full width.
    ///
    /// Pagination per plan.md: the rule-to-first-field head is kept together
    /// — an entry never opens at the very bottom of a page — while field
    /// rows may break between rows and notes flow across pages via
    /// continuation frames.
    private static func drawEntry(
        _ entry: PDFEntry,
        on writer: PageWriter,
        imageData: (PersistentIdentifier) -> Data?
    ) {
        // Resolve before layout: an identifier that yields no image (deleted
        // mid-export, undecodable blob) lays the entry out photo-free — the
        // decided skip-the-photo-keep-the-entry behavior, with no reserved
        // gap where a picture should have been.
        let image = entry.photoID
            .flatMap { imageData($0) }
            .flatMap { downsampledImage(from: $0, maxPixelSize: photoBox.width * 2) }
        let hasPhoto = image != nil
        let columnWidth = hasPhoto ? contentWidth - photoBox.width - photoGap : contentWidth

        // 005: a stock photo's credit rides under its picture. Only when the
        // picture is actually drawn — a credit without its image would credit
        // nothing (spec P4) — and only for a `.fetched` leading photo, which
        // is what `photoCredit` already means (guard G11).
        let creditText = (hasPhoto ? entry.photoCredit : nil).map {
            styled($0, font: PrintType.sans(6.5), color: PrintPalette.secondary)
        }
        let creditHeight = creditText.map { creditGap + measuredHeight($0, width: photoBox.width) } ?? 0
        let photoColumnHeight = hasPhoto ? photoBox.height + creditHeight : 0

        let eyebrowText = styled(
            entry.eyebrow.uppercased(),
            font: PrintType.mono(7.5, weight: .medium),
            color: PrintPalette.secondary,
            kern: 1.2
        )
        let nameText = styled(entry.name, font: PrintType.display(14), color: PrintPalette.ink)

        // Keep-together floor: rule, head, and the first field row (or the
        // photo box if taller) must fit, else the entry starts a new page.
        let headHeight = measuredHeight(eyebrowText, width: columnWidth) + 5
            + measuredHeight(nameText, width: columnWidth) + 10
        let firstRowHeight = entry.fields.first.map { fieldRowHeight($0, width: columnWidth) } ?? 0
        let keepTogether = 18 + 0.75 + 14
            + max(headHeight + firstRowHeight, photoColumnHeight)
        if writer.remaining < keepTogether {
            writer.newPage()
        }

        writer.advance(18)
        writer.drawRule()
        writer.advance(14)

        let entryTopCursor = writer.cursor
        let entryTopPage = writer.pageIndex

        if let image {
            let box = CGRect(
                x: margin + contentWidth - photoBox.width,
                y: entryTopCursor - photoBox.height,
                width: photoBox.width,
                height: photoBox.height
            )
            writer.context.draw(image, in: aspectFitRect(for: image, in: box))
            if let creditText {
                writer.drawFixed(
                    creditText,
                    x: box.minX,
                    top: box.minY - creditGap,
                    width: photoBox.width
                )
            }
        }

        writer.draw(eyebrowText, width: columnWidth)
        writer.advance(5)
        writer.draw(nameText, width: columnWidth)
        writer.advance(10)

        for field in entry.fields {
            drawFieldRow(field, columnWidth: columnWidth, on: writer)
        }

        // Notes clear the photo box — but only while still on the entry's
        // first page; a page break has already cleared it otherwise.
        if hasPhoto, writer.pageIndex == entryTopPage {
            // The credit counts as part of the photo column, so notes clear
            // it too rather than flowing across the credit line.
            let photoBottom = entryTopCursor - photoColumnHeight
            if writer.cursor > photoBottom {
                writer.advance(writer.cursor - photoBottom)
            }
        }

        if let notes = entry.notes {
            writer.advance(10)
            drawFlowed(
                styled(notes, font: PrintType.sans(10), color: PrintPalette.ink),
                on: writer
            )
        }
        writer.advance(4)
    }

    /// ImageIO decode-to-target-size: `kCGImageSourceThumbnailMaxPixelSize`
    /// at 2× the drawn box means the full-resolution bitmap is never
    /// materialized and the embedded image is print-sharp without ballooning
    /// the file — the reviewer's highest-leverage catch (plan.md's Photos
    /// section), guarded by the size-bound test.
    static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ] as [CFString: Any] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    /// Fit inside the box, anchored to its top-right corner — the entry's
    /// visual anchor; CG's origin is bottom-left, so "top" is `maxY`.
    private static func aspectFitRect(for image: CGImage, in box: CGRect) -> CGRect {
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(box.width / imageSize.width, box.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: box.maxX - size.width,
            y: box.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private static func fieldTexts(_ field: PDFField) -> (label: NSAttributedString, value: NSAttributedString) {
        (
            styled(
                field.label.uppercased(),
                font: PrintType.mono(7.5, weight: .medium),
                color: PrintPalette.secondary,
                kern: 1.0
            ),
            styled(
                field.value,
                font: field.isMono ? PrintType.mono(10.5) : PrintType.sans(10.5),
                color: PrintPalette.ink
            )
        )
    }

    private static func fieldRowHeight(_ field: PDFField, width: CGFloat) -> CGFloat {
        let (label, value) = fieldTexts(field)
        return max(
            measuredHeight(label, width: fieldLabelWidth),
            measuredHeight(value, width: width - fieldLabelWidth - fieldColumnGap)
        ) + 7
    }

    /// Rows may break between rows: a row that doesn't fit starts the next
    /// page, so even a pathologically tall field grid can't clip data.
    private static func drawFieldRow(_ field: PDFField, columnWidth: CGFloat, on writer: PageWriter) {
        if writer.remaining < fieldRowHeight(field, width: columnWidth) {
            writer.newPage()
        }
        let (label, value) = fieldTexts(field)
        writer.drawRow(
            label: label,
            labelWidth: fieldLabelWidth,
            value: value,
            gap: fieldColumnGap,
            width: columnWidth
        )
    }

    /// Notes flow: draw as much as fits, `CTFrameGetVisibleStringRange`
    /// yields the resume point, continuation frames fill fresh pages until
    /// the text is spent — plan.md's mid-notes split.
    private static func drawFlowed(_ text: NSAttributedString, on writer: PageWriter) {
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var location = 0
        var retriedOnFreshPage = false
        while location < text.length {
            if writer.remaining < 24 {
                writer.newPage()
            }
            let capacity = writer.remaining
            let rect = CGRect(x: margin, y: writer.cursor - capacity, width: contentWidth, height: capacity)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: location, length: 0),
                CGPath(rect: rect, transform: nil),
                nil
            )
            CTFrameDraw(frame, writer.context)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else {
                // Nothing fit. Once is a page-boundary sliver; twice — on a
                // fresh full page — means the text can never fit, and
                // looping forever would be worse than stopping.
                if retriedOnFreshPage { return }
                retriedOnFreshPage = true
                writer.newPage()
                continue
            }
            retriedOnFreshPage = false
            location += visible.length
            if location < text.length {
                writer.newPage()
            } else {
                let used = CTFramesetterSuggestFrameSizeWithConstraints(
                    framesetter,
                    visible,
                    nil,
                    CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    nil
                ).height
                writer.advance(ceil(used))
            }
        }
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
    private(set) var pageIndex = -1
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
        pageIndex += 1
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

    /// A label/value pair sharing one top edge — the field grid's row. The
    /// caps label sits a couple of points lower so its smaller face reads
    /// aligned with the value's first line.
    func drawRow(
        label: NSAttributedString,
        labelWidth: CGFloat,
        value: NSAttributedString,
        gap: CGFloat,
        width: CGFloat
    ) {
        let valueWidth = width - labelWidth - gap
        let labelHeight = PDFComposer.measuredHeight(label, width: labelWidth)
        let valueHeight = PDFComposer.measuredHeight(value, width: valueWidth)
        drawAt(label, x: PDFComposer.margin, top: cursor - 2, width: labelWidth, height: labelHeight)
        drawAt(value, x: PDFComposer.margin + labelWidth + gap, top: cursor, width: valueWidth, height: valueHeight)
        advance(max(labelHeight, valueHeight) + 7)
    }

    /// Draws at an absolute top edge and leaves the cursor alone — the photo
    /// column's credit line sits beside the flowing text, not in it, exactly
    /// as the photo itself is drawn straight into the context.
    func drawFixed(_ text: NSAttributedString, x: CGFloat, top: CGFloat, width: CGFloat) {
        drawAt(
            text,
            x: x,
            top: top,
            width: width,
            height: PDFComposer.measuredHeight(text, width: width)
        )
    }

    private func drawAt(
        _ text: NSAttributedString,
        x: CGFloat,
        top: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        let rect = CGRect(x: x, y: top - height - 1, width: width, height: height + 2)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: 0),
            CGPath(rect: rect, transform: nil),
            nil
        )
        CTFrameDraw(frame, context)
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
