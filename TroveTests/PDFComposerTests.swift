import Foundation
import PDFKit
import Testing
@testable import Trove

/// Guards over the composer's output, read back through `PDFKit` — an Apple
/// framework used on the test side only; the production module stays
/// CG/CT/ImageIO. Text assertions go through `page.string`, so what's
/// checked is extractable text — which is also what makes the document
/// searchable for the user.
struct PDFComposerTests {
    private let generated = Date(timeIntervalSince1970: 1_787_000_000)

    private func itemsCover(unvaluedCount: Int = 1) -> CoverSummary {
        CoverSummary(
            title: "Owned Items",
            coverageLabel: "All items",
            generatedAt: generated,
            itemCount: 3,
            totals: .items(currentValueCents: 443_000, paidCents: 397_000, unvaluedCount: unvaluedCount)
        )
    }

    private func wishlistCover() -> CoverSummary {
        CoverSummary(
            title: "Wishlist",
            coverageLabel: "Category: Amps",
            generatedAt: generated,
            itemCount: 4,
            totals: .wishlist(estimatedCostCents: 105_000)
        )
    }

    private func page(_ index: Int, of document: PDFDocumentModel) throws -> String {
        let data = try PDFComposer.render(document)
        let pdf = try #require(PDFDocument(data: data))
        return try #require(pdf.page(at: index)?.string)
    }

    // MARK: - Validity

    @Test func rendersAValidOnePageCoverOnlyPDF() throws {
        let data = try PDFComposer.render(PDFDocumentModel(cover: itemsCover(), entries: []))
        let pdf = try #require(PDFDocument(data: data))
        #expect(pdf.pageCount == 1)
    }

    // MARK: - Cover (T006)

    @Test func itemsCoverCarriesTitleMetaAndTotals() throws {
        let text = try page(0, of: PDFDocumentModel(cover: itemsCover(), entries: []))
        // The wordmark is tracked at 4pt, which PDFKit's extractor renders
        // as "T R O V E" — an artifact of wide kerning, not a drawing
        // defect. Collapsing spaces keeps the assertion about the letters
        // being real extractable text without pinning extractor behavior.
        #expect(text.replacingOccurrences(of: " ", with: "").contains("TROVE"))
        #expect(text.contains("Owned Items"))
        // The same local-day serialization the CSV uses, so the expectation
        // is computed the same way the composer computes it.
        #expect(text.contains("Generated \(ExportSchema.day(from: generated))"))
        #expect(text.contains("All items"))
        #expect(text.contains("3 items"))
        #expect(text.contains("TOTAL VALUE"))
        #expect(text.contains("$4,430"))
        #expect(text.contains("TOTAL PAID"))
        #expect(text.contains("$3,970"))
        #expect(text.contains("1 not yet valued"))
    }

    @Test func wishlistCoverTotalsEstimatedCostOnly() throws {
        let text = try page(0, of: PDFDocumentModel(cover: wishlistCover(), entries: []))
        #expect(text.contains("Wishlist"))
        #expect(text.contains("Category: Amps"))
        #expect(text.contains("4 wanted"))
        #expect(text.contains("TOTAL ESTIMATED COST"))
        #expect(text.contains("$1,050"))
        #expect(!text.contains("TOTAL PAID"))
        #expect(!text.contains("not yet valued"))
    }

    /// The floor note exists to keep the value figure honest; with nothing
    /// un-valued there's nothing to be honest about, and the line reading
    /// "0 not yet valued" would invent a caveat.
    @Test func fullyValuedItemsCoverOmitsTheFloorNote() throws {
        let text = try page(0, of: PDFDocumentModel(cover: itemsCover(unvaluedCount: 0), entries: []))
        #expect(!text.contains("not yet valued"))
    }
}
