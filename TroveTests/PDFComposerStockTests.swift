import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Trove

/// 005/T013's guards over the PDF export's stock-photo credit (spec
/// criterion 8, plan §7): the snapshot carries the leading photo's
/// attribution, the entry composes `StockPhotoCopy`'s one credit wording from
/// it, and the composer draws that line beneath the photo box — but only when
/// the leading photo is actually a fetched one (plan §9's guard G11).
///
/// Rendered text is read back through `PDFKit`, as `PDFComposerTests` does;
/// the production module stays CG/CT/ImageIO.
struct PDFComposerStockTests {
    /// One unbreakable token as the author: CoreText wraps the credit inside
    /// the narrow photo column and PDFKit renders each wrap as a newline, so
    /// an assertion on a multi-word phrase could fail while the text sits
    /// exactly where it belongs (the `ENDOFNOTESMARKER` lesson, 011).
    private let author = "PHOTOGRAPHERTOKEN"
    private let license = "CC BY-SA 4.0"

    private var attribution: StockPhotoAttribution {
        StockPhotoAttribution(
            author: author,
            licenseName: license,
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Leica.jpg")!
        )
    }

    private func cover() -> CoverSummary {
        CoverSummary(
            title: "Owned Items",
            coverageLabel: "All items",
            generatedAt: Date(timeIntervalSince1970: 1_787_000_000),
            itemCount: 1,
            totals: .items(currentValueCents: 100_000, paidCents: 90_000, unvaluedCount: 0)
        )
    }

    /// A real, decodable PNG — `RowThumbnailTests`' fixture shape, kept out of
    /// `UIImage` for the same reason it is there.
    private func pngData(side: Int = 24) throws -> Data {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let image = try #require(context.makeImage())

        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func scratchDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "PDFComposerStockTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    /// Stores the item, snapshots it, and renders through the live service so
    /// the photo blob resolves the way it does in a real export — the default
    /// `render(_:)` hands back no image at all, and a credit is only drawn
    /// beside a drawn photo.
    private func renderedText(
        photos: [Photo],
        in container: ModelContainer
    ) async throws -> (entry: PDFEntry, text: String) {
        let context = ModelContext(container)
        let item = Item(
            name: "Leica M6",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 90_000,
            photos: photos
        )
        context.insert(item)
        try context.save()

        let entry = PDFEntry(record: ItemExportRecord(item: item))
        return (entry, try await renderedText(of: entry, in: container))
    }

    /// The rendering half on its own, so a test can change the store between
    /// the snapshot and the export the way a real delete does.
    private func renderedText(
        of entry: PDFEntry,
        in container: ModelContainer,
        filename: String = "stock.pdf"
    ) async throws -> String {
        let scratch = scratchDirectory()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let service = FileExportService(container: container, directory: scratch)
        let url = try await service.exportPDF(
            PDFDocumentModel(cover: cover(), entries: [entry]),
            filename: filename
        )
        let pdf = try #require(PDFDocument(data: try Data(contentsOf: url)))
        return (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    }

    // MARK: - A fetched leading photo

    @Test func aFetchedLeadingPhotoCarriesItsCreditAndDrawsIt() async throws {
        let container = try makeInMemoryContainer()
        let photo = Photo.fetched(imageData: try pngData(), attribution: attribution, sortOrder: 0)
        let (entry, text) = try await renderedText(photos: [photo], in: container)

        // The copy is `StockPhotoCopy`'s, composed nowhere else.
        #expect(entry.photoCredit == StockPhotoCopy.credit(author: author, licenseName: license))
        #expect(entry.photoID != nil)

        #expect(text.contains("Leica M6"))
        #expect(text.contains(author), "the credit's author never reached the page")
        // Single unbreakable words from the other two segments, for the same
        // line-wrapping reason the author is one token.
        #expect(text.contains("Wikimedia"), "the credit's source never reached the page")
        #expect(text.contains("BY-SA"), "the credit's licence never reached the page")
    }

    /// The snapshot side of the same claim: the record carries the leading
    /// photo's author and licence beside its identifier, so nothing live
    /// crosses to generation (plan §7).
    @Test func theRecordSnapshotCarriesTheLeadingPhotosAttribution() throws {
        let context = try makeInMemoryContext()
        let item = Item(
            name: "Leica M6",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 90_000,
            photos: [Photo.fetched(imageData: Data([0x01]), attribution: attribution, sortOrder: 0)]
        )
        context.insert(item)
        try context.save()

        let record = ItemExportRecord(item: item)
        #expect(record.firstPhotoAttribution?.author == author)
        #expect(record.firstPhotoAttribution?.licenseName == license)
    }

    // MARK: - Guard G11: never on an owned photo

    @Test func aDevicePhotoEntryCarriesNoCreditAndDrawsNone() async throws {
        let container = try makeInMemoryContainer()
        let photo = Photo(imageData: try pngData(), source: .device)
        let (entry, text) = try await renderedText(photos: [photo], in: container)

        #expect(entry.photoCredit == nil)
        #expect(entry.photoID != nil, "the photo must be drawn, or this proves nothing")
        #expect(text.contains("Leica M6"))
        // No credit line at all beneath the person's own photo: not the
        // wording, not the fallback author, not the source.
        #expect(!text.contains("Photo:"))
        #expect(!text.contains("Wikimedia"))
    }

    /// Keep-both (Decision 4a), as plan §7 records it: the owned photo leads,
    /// so it is the one the export draws — and the kept stock photo, which
    /// doesn't appear, brings no credit with it.
    @Test func keepingBothDrawsTheOwnedPhotoWithNoCredit() async throws {
        let container = try makeInMemoryContainer()
        let owned = Photo(imageData: try pngData(), source: .device, sortOrder: 0)
        let stock = Photo.fetched(imageData: try pngData(), attribution: attribution, sortOrder: 1)
        let (entry, text) = try await renderedText(photos: [owned, stock], in: container)

        #expect(entry.photoID == owned.persistentModelID)
        #expect(entry.photoCredit == nil)
        #expect(!text.contains(author))
        #expect(!text.contains("Wikimedia"))
    }

    // MARK: - The photo deleted between snapshot and render (plan §7)

    /// Plan §7's "photo deleted mid-export → no photo, no credit" sentence,
    /// which had no test (Phase 4 review note 1): the entry is snapshotted
    /// while the fetched photo is there, so it carries both the identifier
    /// and the credit, and the photo is then deleted — the CloudKit-delete
    /// race `PhotoFetcher` documents. The composer lays the entry out
    /// photo-free, and a credit is never drawn without its image.
    ///
    /// Mutation: draw the credit whether or not the image resolved (hoist the
    /// credit out of the composer's `if let image`) → red.
    @Test func aCreditWhosePhotoVanishedMidExportDrawsNeitherCreditNorAuthor() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let photo = Photo.fetched(imageData: try pngData(), attribution: attribution, sortOrder: 0)
        let item = Item(
            name: "Leica M6",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 90_000,
            photos: [photo]
        )
        context.insert(item)
        try context.save()

        let entry = PDFEntry(record: ItemExportRecord(item: item))
        let vanishedID = try #require(entry.photoID)
        #expect(entry.photoCredit != nil, "the entry must carry a credit, or this proves nothing")

        // The photo goes after the snapshot, so the identifier resolves to
        // nothing when the composer asks for its bytes.
        context.delete(photo)
        try context.save()
        var gone = FetchDescriptor<Photo>(predicate: #Predicate { $0.persistentModelID == vanishedID })
        gone.fetchLimit = 1
        #expect(
            try ModelContext(container).fetch(gone).isEmpty,
            "the photo is still in the store, so the export would resolve it"
        )

        let text = try await renderedText(of: entry, in: container, filename: "vanished.pdf")

        #expect(text.contains("Leica M6"), "the entry itself still has to render")
        #expect(!text.contains("Photo:"), "a credit was drawn with no photo above it")
        #expect(!text.contains(author))
        #expect(!text.contains("Wikimedia"))
    }
}
