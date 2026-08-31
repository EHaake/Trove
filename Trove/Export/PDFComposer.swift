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

/// Renders the export PDF with CoreGraphics + CoreText (+ ImageIO from T008)
/// — deliberately no UIKit anywhere in this module, per plan.md's reviewed
/// renderer decision: `CTFramesetter` is the multi-page flow engine, and the
/// repo's own precedent (`RowThumbnailTests`) already chose CG over `UIImage`
/// to avoid a quiet UIKit dependency.
///
/// T005 lands the walking skeleton — a cover-only page proving the off-main
/// CG/CT pipeline compiles and runs under the project's MainActor default —
/// and T006–T008 build the real document on top of it.
nonisolated enum PDFComposer {
    /// US Letter, per plan.md's document design (v1 is US/USD-only).
    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 54

    static func render(_ document: PDFDocumentModel) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw PDFComposerError.contextUnavailable }

        context.beginPDFPage(nil)
        drawCoverSkeleton(document.cover, in: context)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// Skeleton only: the title, drawn through the same CTFont-from-
    /// PostScript-name path the real cover (T006) will use, so the pipeline
    /// being proven is the one that ships.
    private static func drawCoverSkeleton(_ cover: CoverSummary, in context: CGContext) {
        let font = CTFontCreateWithName(
            FontFamily.display.postScriptName(for: .semibold) as CFString, 26, nil
        )
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 0.1, alpha: 1),
        ]
        let title = NSAttributedString(string: cover.title, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(title)
        let bounds = CGRect(
            x: margin,
            y: margin,
            width: pageSize.width - margin * 2,
            height: pageSize.height - margin * 2
        )
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: 0),
            CGPath(rect: bounds, transform: nil),
            nil
        )
        CTFrameDraw(frame, context)
    }
}
