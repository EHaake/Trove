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

    // MARK: - Entries (T007)

    private func entry(
        name: String,
        paidCents: Int = 100_000,
        serial: String? = nil,
        notes: String? = nil
    ) -> PDFEntry {
        PDFEntry(record: ItemExportRecord(
            name: name,
            categoryPath: "Music/Guitars",
            purchasePriceCents: paidCents,
            currencyCode: "USD",
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            purchaseLocation: nil,
            currentValueCents: 150_000,
            desireToKeep: 4,
            conditionRawValue: "good",
            conditionNotes: nil,
            serialNumber: serial,
            notes: notes,
            firstPhotoID: nil
        ))
    }

    private func render(entries: [PDFEntry]) throws -> PDFDocument {
        let data = try PDFComposer.render(PDFDocumentModel(cover: itemsCover(), entries: entries))
        return try #require(PDFDocument(data: data))
    }

    private func fullText(_ pdf: PDFDocument) -> String {
        (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    }

    @Test func entriesStartOnTheirOwnPageWithTheFullFieldGrid() throws {
        let pdf = try render(entries: [entry(name: "Squier Classic Vibe 50s", serial: "SN-XYZ-001")])
        #expect(pdf.pageCount == 2)

        let text = try #require(pdf.page(at: 1)?.string)
        #expect(text.contains("MUSIC · GUITARS"))
        #expect(text.contains("Squier Classic Vibe 50s"))
        #expect(text.contains("PAID"))
        #expect(text.contains("$1,000"))
        #expect(text.contains("WORTH NOW"))
        #expect(text.contains("$1,500"))
        #expect(text.contains("BOUGHT"))
        // The entry's date renders through the same local-day serializer the
        // expectation uses, so this holds in any timezone.
        #expect(text.contains(ExportSchema.day(from: Date(timeIntervalSince1970: 1_700_000_000))))
        #expect(text.contains("DESIRE TO KEEP"))
        #expect(text.contains("4 / 5"))
        #expect(text.contains("CONDITION"))
        #expect(text.contains("Good"))
        #expect(text.contains("SERIAL NUMBER"))
        #expect(text.contains("SN-XYZ-001"))
        // Empty optionals are skipped, exactly as the detail screen filters
        // its empty rows.
        #expect(!text.contains("BOUGHT FROM"))
        #expect(!text.contains("CONDITION NOTES"))
    }

    @Test func pageCountGrowsWithEntriesAndNoEntryIsLost() throws {
        let names = (1...30).map { "Gear item \($0)" }
        let pdf = try render(entries: names.map { entry(name: $0) })
        #expect(pdf.pageCount > 3)

        let everything = fullText(pdf)
        for name in names {
            #expect(everything.contains(name), "\(name) missing from the document")
        }
    }

    /// The keep-together rule: the page that carries an entry's name also
    /// carries its first field row — an entry never opens as an orphaned
    /// title at the bottom of a page. Unique paid values identify each
    /// entry's first row; graduated notes lengths push successive entries
    /// across page boundaries so breaks land mid-list.
    @Test func anEntrysNameAndFirstFieldRowShareAPage() throws {
        let entries = (1...12).map { index in
            entry(
                name: "Gear item \(index)",
                paidCents: index * 111_100,
                notes: String(repeating: "Care and feeding notes, sentence \(index). ", count: index * 6)
            )
        }
        let pdf = try render(entries: entries)
        #expect(pdf.pageCount > 2)

        for (index, name) in (1...12).map({ ($0, "Gear item \($0)") }) {
            let pageWithName = try #require(
                (0..<pdf.pageCount).first { pdf.page(at: $0)?.string?.contains(name) == true },
                "\(name) missing from the document"
            )
            let pageText = try #require(pdf.page(at: pageWithName)?.string)
            let paid = (index * 111_100).formattedAsWholeCurrency(currencyCode: "USD")
            #expect(pageText.contains(paid), "\(name)'s first field row split onto another page")
        }
    }

    /// plan.md's mid-notes split: an entry taller than a page flows its
    /// notes across continuation pages and loses nothing off the end.
    @Test func pageLengthNotesFlowToContinuationPages() throws {
        // The marker must be one unbreakable token: CoreText line-breaks at
        // hyphens, and PDFKit renders the wrap as a newline — a hyphenated
        // marker straddling a line boundary fails contains() while sitting
        // exactly where it should (found the diagnostic way, 2026-08-30).
        let notes = String(repeating: "The quick brown fox appraises the lazy amplifier. ", count: 400)
            + "ENDOFNOTESMARKER"
        let pdf = try render(entries: [entry(name: "Verbose amp", notes: notes)])
        #expect(pdf.pageCount >= 4)

        let lastPage = try #require(pdf.page(at: pdf.pageCount - 1)?.string)
        #expect(lastPage.contains("ENDOFNOTESMARKER"))
    }
}
