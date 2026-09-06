import Foundation
import Testing
@testable import Trove

/// `docs/samples/README.md` promises specific import behavior for each
/// committed sample CSV. Documentation that claims behavior gets the test
/// that would catch it lying (the constitution's rule, applied to docs):
/// every sample here runs through the *production* pipeline — the real
/// `FileImportService` over the real files — and the promised outcome is
/// pinned. Reads repo files by `#filePath` the way `SourceScan` does, and
/// touches disk for the same narrow reason `ExportTempFileTests` records.
struct DocsSampleTests {
    @Test func itemsFullImportsCleanly() async throws {
        let preview = try await FileImportService()
            .parseItems(at: sample("items-full.csv"), timeZone: .current)
        #expect(preview.validated.count == 12)
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        // "Every field filled" is the file's whole point — hold it to that.
        // The two 002 columns are deliberately *not* in this loop: only the
        // four music rows carry a Reverb match, so the file's claim weakens
        // to "every field filled; the music rows matched" (Q16).
        for row in preview.validated {
            #expect(row.record.purchaseLocation != nil)
            #expect(row.record.currentValueCents != nil)
            #expect(row.record.conditionNotes != nil)
            #expect(row.record.serialNumber != nil)
            #expect(row.record.notes != nil)
        }
        // Exactly four rows carry an id — the guitars, the amp and the
        // pedal, matched against the real Reverb catalog (the ids recorded
        // in TroveTests/Fixtures/Reverb/README.md). Blanking them in the
        // sample turns this red.
        let matched = preview.validated.filter { $0.record.reverbProductID != nil }
        #expect(matched.count == 4)
        #expect(matched.map(\.record.reverbProductID) == [160_322, 182_769, 80_684, 17])
        #expect(matched.map(\.record.name) == [
            "Fender AV II '61 Stratocaster", "Martin D-18",
            "Fender Blues Junior IV", "Strymon Timeline",
        ])
        // And each matched row states the year it was made — the narrowing
        // the CSV carries alongside the match, pinned to the values the file
        // holds. The other eight rows state no year at all, so the README's
        // "each with the year it was made" is a claim about those four.
        #expect(matched.map(\.record.year) == [2023, 2018, 2021, 2015])
        let unmatched = preview.validated.filter { $0.record.reverbProductID == nil }
        #expect(unmatched.count == 8)
        #expect(unmatched.allSatisfy { $0.record.year == nil })
    }

    @Test func itemsPartialSkipsAndDefaultsExactlyAsDocumented() async throws {
        let preview = try await FileImportService()
            .parseItems(at: sample("items-partial.csv"), timeZone: .current)
        #expect(preview.validated.count == 5)
        #expect(preview.skipped == [
            SkippedRow(rowNumber: 5, reason: "no name"),
            SkippedRow(rowNumber: 7, reason: "more columns than the template"),
        ])
        #expect(preview.defaultedFieldCount == 6)
        // The backward-compatibility fixture: written at the 12-column
        // width Trove shipped before 002, and kept there forever. Every
        // imported row therefore has no match and no year — arriving blank,
        // not defaulted (the count above is unchanged by the two columns).
        for row in preview.validated {
            #expect(row.record.reverbProductID == nil)
            #expect(row.record.year == nil)
        }
        // The width itself, read off the file — this is what would fail if
        // the sample were ever "helpfully" regenerated at the new width.
        let header = try #require(CSVParser.parse(try text("items-partial.csv")).first)
        #expect(header.cells.count == 12)
        #expect(header.cells == Array(ExportSchema.itemHeaders.prefix(12)))
    }

    @Test func itemsResavedToleratesTransportDamage() async throws {
        let preview = try await FileImportService()
            .parseItems(at: sample("items-resaved.csv"), timeZone: .current)
        #expect(preview.validated.count == 5)
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        #expect(preview.validated.first?.record.name == "Leica M6 TTL 0.72")
    }

    @Test func wishlistImportsThereAndIsCaughtOnTheItemsScreen() async throws {
        let url = sample("wishlist.csv")
        let preview = try await FileImportService().parseWishlist(at: url, timeZone: .current)
        #expect(preview.validated.count == 4)
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        // Exactly one want is matched to a Reverb product, the other three
        // are unmatched — the same "carries the match, never the figures"
        // contract — and the matched one is the row carrying the year.
        #expect(preview.validated.compactMap { $0.record.reverbProductID } == [232])
        #expect(preview.validated.compactMap { $0.record.year } == [2019])
        let matched = try #require(preview.validated.first { $0.record.reverbProductID != nil })
        #expect(matched.record.name == "Fender Deluxe Reverb '65 RI")
        #expect(matched.record.reverbProductID == 232)
        #expect(matched.record.year == 2019)
        // The Added dates are the point of the wishlist schema's round trip.
        #expect(
            preview.validated.first?.record.createdAt
                == ImportSchema.day(from: "2024-05-10")
        )

        await expectImportError(.headerMismatch(wrongList: true)) {
            try await FileImportService().parseItems(at: url, timeZone: .current)
        }
    }

    @Test func theBadFilesFailWholeFileForTheirDocumentedReasons() async {
        await expectImportError(.headerMismatch(wrongList: false)) {
            try await FileImportService().parseItems(at: self.sample("bad-headers.csv"), timeZone: .current)
        }
        await expectImportError(.malformedQuoting) {
            try await FileImportService().parseItems(at: self.sample("bad-unclosed-quote.csv"), timeZone: .current)
        }
        await expectImportError(.undecodable) {
            try await FileImportService().parseItems(at: self.sample("bad-encoding.csv"), timeZone: .current)
        }
    }

    // MARK: - Helpers

    /// The sample's own bytes, decoded the way the importer decodes them —
    /// used where the assertion is about the *file's* shape rather than what
    /// the pipeline made of it.
    private func text(_ name: String) throws -> String {
        try String(contentsOf: sample(name), encoding: .utf8)
    }

    private func sample(_ name: String, file: StaticString = #filePath) -> URL {
        URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/samples")
            .appending(path: name)
    }

    private func expectImportError(
        _ expected: ImportError,
        _ body: () async throws -> some Sendable
    ) async {
        do {
            _ = try await body()
            Issue.record("expected \(expected), got success")
        } catch let error as ImportError {
            #expect(error == expected)
        } catch {
            Issue.record("expected ImportError.\(expected), got \(error)")
        }
    }
}
