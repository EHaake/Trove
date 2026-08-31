import Foundation
import PDFKit
import Testing
@testable import Trove

/// Guards over the composer's output, read back through `PDFKit` — an Apple
/// framework used on the test side only; the production module stays
/// CG/CT/ImageIO. At T005 this covers the walking skeleton (validity, page
/// count, extractable cover text); T006–T008 grow it with the real layout.
struct PDFComposerTests {
    private func makeDocument(title: String = "Owned Items") -> PDFDocumentModel {
        PDFDocumentModel(
            cover: CoverSummary(
                title: title,
                coverageLabel: "All items",
                generatedAt: .now,
                itemCount: 3,
                totals: .items(currentValueCents: 443_000, paidCents: 397_000, unvaluedCount: 1)
            ),
            entries: []
        )
    }

    @Test func rendersAValidOnePageCoverOnlyPDF() throws {
        let data = try PDFComposer.render(makeDocument())
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount == 1)
    }

    /// The text must be *extractable*, not pixels — CoreText drawing into a
    /// PDF context embeds real text operations, which is also what makes the
    /// document searchable for the user.
    @Test func coverCarriesTheTitleAsRealText() throws {
        let data = try PDFComposer.render(makeDocument(title: "Wishlist"))
        let pdf = try #require(PDFDocument(data: data))
        let text = try #require(pdf.page(at: 0)?.string)
        #expect(text.contains("Wishlist"))
    }
}
