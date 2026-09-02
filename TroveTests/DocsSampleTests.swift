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
        for row in preview.validated {
            #expect(row.record.purchaseLocation != nil)
            #expect(row.record.currentValueCents != nil)
            #expect(row.record.conditionNotes != nil)
            #expect(row.record.serialNumber != nil)
            #expect(row.record.notes != nil)
        }
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
