import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import SwiftData
import Testing
import UniformTypeIdentifiers
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

    // MARK: - Photos (T008)

    /// A deliberately incompressible JPEG: random noise defeats both JPEG
    /// and the PDF's lossless compression, so a full-resolution embed is
    /// enormous and the size-bound test below can genuinely fail.
    private func noiseJPEG(side: Int) throws -> Data {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for index in bytes.indices {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            bytes[index] = UInt8(truncatingIfNeeded: seed)
        }
        for index in stride(from: 3, to: bytes.count, by: 4) {
            bytes[index] = 255
        }

        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &bytes,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())

        let out = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))
        return out as Data
    }

    private func scratchDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "PDFComposerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    /// The downsampling guard (plan.md's Photos section): five items with
    /// large, incompressible photos must produce a bounded file — bypassing
    /// the ImageIO thumbnail decode balloons this by an order of magnitude.
    /// The bare-render comparison proves the photos genuinely embedded.
    @Test func photosEmbedDownsampledAndBoundTheFileSize() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let jpeg = try noiseJPEG(side: 2200)

        var records: [ItemExportRecord] = []
        for index in 1...5 {
            let item = Item(
                name: "Camera \(index)",
                categoryPath: "Photography",
                purchasePriceCents: 100_000,
                photos: [Photo(imageData: jpeg)]
            )
            context.insert(item)
            try context.save()
            records.append(ItemExportRecord(item: item))
        }
        let document = PDFDocumentModel(
            cover: itemsCover(),
            entries: records.map { PDFEntry(record: $0) }
        )

        let scratch = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let service = FileExportService(container: container, directory: scratch)
        let url = try await service.exportPDF(document, filename: "photos.pdf")

        let size = try #require(
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        )
        #expect(size < 3_000_000, "PDF is \(size) bytes — the downsampling regressed")

        let bare = try PDFComposer.render(document)
        #expect(size > bare.count + 100_000, "photos never embedded — the bound proves nothing")

        let pdf = try #require(PDFDocument(data: try Data(contentsOf: url)))
        #expect(pdf.pageCount >= 2)
    }

    /// The deleted-mid-export race, deterministically: an identifier minted
    /// in a store the service can't see resolves to nothing — the entry
    /// renders photo-free instead of crashing or vanishing.
    @Test func anUnresolvablePhotoIdentifierKeepsTheEntryPhotoFree() async throws {
        let foreign = try makeInMemoryContext()
        let ghost = Item(
            name: "Ghost camera",
            categoryPath: "Photography",
            purchasePriceCents: 50_000,
            photos: [Photo(imageData: Data([0x01]))]
        )
        foreign.insert(ghost)
        try foreign.save()

        let record = ItemExportRecord(item: ghost)
        #expect(record.firstPhotoID != nil)

        let scratch = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let service = FileExportService(container: try makeInMemoryContainer(), directory: scratch)
        let url = try await service.exportPDF(
            PDFDocumentModel(cover: itemsCover(), entries: [PDFEntry(record: record)]),
            filename: "ghost.pdf"
        )

        let pdf = try #require(PDFDocument(data: try Data(contentsOf: url)))
        let text = fullText(pdf)
        #expect(text.contains("Ghost camera"))
        #expect(text.contains("PAID"))
    }
}
