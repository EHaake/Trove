import Foundation
import Synchronization
import Testing
@testable import Trove

/// T007's guards: the live service over real temp files — the same narrow
/// disk-I/O exception `ExportTempFileTests` records, for the same reason:
/// the claims under test (reading a URL, the size cap, decode failure) are
/// about file I/O and can't be checked without it.
struct ImportServiceTests {
    @Test func aCanonicalItemsFileParsesThroughTheService() async throws {
        let zone = TimeZone(identifier: "UTC")!
        let table = ExportSchema.itemsTable([
            ItemExportRecord(
                name: "Leica M6", categoryPath: "Photography/Cameras",
                purchasePriceCents: 290_000, currencyCode: "USD",
                purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                purchaseLocation: "KEH", currentValueCents: 345_000, desireToKeep: 5,
                conditionRawValue: "excellent", conditionNotes: nil,
                serialNumber: nil, notes: "body, cap", firstPhotoID: nil
            ),
        ], timeZone: zone)
        let url = try write(CSVWriter.write(table))
        defer { try? FileManager.default.removeItem(at: url) }

        let preview = try await service().parseItems(at: url, timeZone: zone)
        #expect(preview.validated.count == 1)
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        #expect(preview.validated.first?.record.name == "Leica M6")
    }

    @Test func aCanonicalWishlistFileParsesThroughTheWishlistMethod() async throws {
        let zone = TimeZone(identifier: "UTC")!
        let table = ExportSchema.wishlistTable([
            WishlistExportRecord(
                name: "OM-1", categoryPath: "Photography/Cameras",
                estimatedCostCents: 45_000, currencyCode: "USD", desireToOwn: 3,
                createdAt: Date(timeIntervalSince1970: 1_500_000_000),
                notes: nil, firstPhotoID: nil
            ),
        ], timeZone: zone)
        let url = try write(CSVWriter.write(table))
        defer { try? FileManager.default.removeItem(at: url) }

        let preview = try await service().parseWishlist(at: url, timeZone: zone)
        #expect(preview.validated.count == 1)
        #expect(preview.validated.first?.record.name == "OM-1")
    }

    // MARK: - Error mapping

    @Test func garbageBytesMapToUndecodable() async throws {
        // 0xFF is never valid in UTF-8.
        let url = try write(Data([0xFF, 0xFE, 0xFD, 0x00]))
        defer { try? FileManager.default.removeItem(at: url) }
        await expectImportError(.undecodable) {
            try await self.service().parseItems(at: url, timeZone: .current)
        }
    }

    @Test func anOversizedFileMapsToTooLargeBeforeAnyRead() async throws {
        let url = try write(Data(count: FileImportService.maximumFileSize + 1))
        defer { try? FileManager.default.removeItem(at: url) }
        await expectImportError(.tooLarge) {
            try await self.service().parseItems(at: url, timeZone: .current)
        }
    }

    @Test func aMissingFileMapsToUnreadable() async {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "does-not-exist-\(UUID().uuidString).csv")
        await expectImportError(.unreadable) {
            try await self.service().parseItems(at: url, timeZone: .current)
        }
    }

    @Test func anUnclosedQuoteMapsToMalformedQuoting() async throws {
        let header = ExportSchema.itemHeaders.joined(separator: ",")
        let url = try write(header + "\r\n\"runaway,quote\r\nmore,rows\r\n")
        defer { try? FileManager.default.removeItem(at: url) }
        await expectImportError(.malformedQuoting) {
            try await self.service().parseItems(at: url, timeZone: .current)
        }
    }

    @Test func theOtherListsFileMapsToTheFlaggedMismatch() async throws {
        let wishlistURL = try write(ExportSchema.wishlistHeaders.joined(separator: ",") + "\r\n")
        let strangerURL = try write("What,Ever\r\n")
        defer {
            try? FileManager.default.removeItem(at: wishlistURL)
            try? FileManager.default.removeItem(at: strangerURL)
        }
        await expectImportError(.headerMismatch(wrongList: true)) {
            try await self.service().parseItems(at: wishlistURL, timeZone: .current)
        }
        await expectImportError(.headerMismatch(wrongList: false)) {
            try await self.service().parseItems(at: strangerURL, timeZone: .current)
        }
    }

    // MARK: - Helpers

    private func service() -> FileImportService { FileImportService() }

    private func write(_ text: String) throws -> URL {
        try write(Data(text.utf8))
    }

    private func write(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ImportServiceTests-\(UUID().uuidString).csv")
        try data.write(to: url)
        return url
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

/// T008's instrumented off-main claim (criterion 15) —
/// `ExportConcurrencyTests`' shape verbatim: the probe lives inside the
/// parse bodies and records the thread the work actually ran on (the T056
/// lesson: instrument the mechanism, never a proxy). Mutation-verified by
/// dropping `@concurrent` from the protocol requirements.
struct ImportConcurrencyTests {
    /// Thread-safe capture the nonisolated parse body can write into —
    /// `nonisolated` explicitly, since the suite keeps the test target's
    /// MainActor default and a MainActor-isolated box couldn't be written
    /// off-main.
    private nonisolated final class Probe: Sendable {
        private let state = Mutex<[Bool]>([])
        func record(_ isMainThread: Bool) { state.withLock { $0.append(isMainThread) } }
        var sawMainThread: [Bool] { state.withLock { $0 } }
    }

    @Test func parsingRunsOffTheMainThreadForBothLists() async throws {
        let probe = Probe()
        let itemsURL = try writeItemsFile()
        let wishlistURL = try writeWishlistFile()
        defer {
            try? FileManager.default.removeItem(at: itemsURL)
            try? FileManager.default.removeItem(at: wishlistURL)
        }
        // Typed through the existential deliberately — the view models'
        // real call path. What T008's mutation matrix established
        // empirically (2026-08-31): through this path, `@concurrent` on
        // *either* the requirement or the implementation alone keeps the
        // body off-main (each protects against the other being forgotten —
        // a plain witness of a @concurrent requirement hops at the call,
        // a @concurrent witness of a plain requirement hops at the body);
        // the probe goes red only when both are absent. So this test
        // guards the pair as a pair, not each annotation individually.
        let service: any ImportService = FileImportService(
            generationProbe: { probe.record($0) }
        )

        // Called from the main actor — exactly how the view models will
        // call it — so a pass means the nonisolated-async hop genuinely
        // happened, not that the test started somewhere convenient.
        #expect(sampledOnMainThread())
        _ = try await service.parseItems(at: itemsURL, timeZone: .current)
        _ = try await service.parseWishlist(at: wishlistURL, timeZone: .current)

        #expect(probe.sawMainThread == [false, false])
    }

    private nonisolated func sampledOnMainThread() -> Bool { Thread.isMainThread }

    private func writeItemsFile() throws -> URL {
        try write(ExportSchema.itemHeaders.joined(separator: ",") + "\r\n")
    }

    private func writeWishlistFile() throws -> URL {
        try write(ExportSchema.wishlistHeaders.joined(separator: ",") + "\r\n")
    }

    private func write(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ImportConcurrencyTests-\(UUID().uuidString).csv")
        try Data(text.utf8).write(to: url)
        return url
    }
}

/// T007's copy guards: the strings the alerts will pin, tested pure —
/// the `ItemDeleteCopy`/`ExportCopy` precedent.
struct ImportCopyTests {
    @Test func confirmationTitleCarriesTheCount() {
        #expect(ImportCopy.confirmationTitle(importCount: 0, target: .items) == "Nothing to import")
        #expect(ImportCopy.confirmationTitle(importCount: 1, target: .items) == "Import 1 item?")
        #expect(ImportCopy.confirmationTitle(importCount: 42, target: .items) == "Import 42 items?")
        #expect(
            ImportCopy.confirmationTitle(importCount: 2, target: .wishlist)
                == "Import 2 wishlist items?"
        )
    }

    @Test func aCleanPreviewSaysNoProblems() {
        #expect(ImportCopy.confirmationMessage(preview: preview()) == "No problems found.")
    }

    /// The amended criterion-5 cap, pinned at its boundary: five skips
    /// list fully with no "more" line; six trigger "…and 1 more row."
    @Test func theSkipListingCapsAtFive() {
        let five = ImportCopy.confirmationMessage(
            preview: preview(skipped: (1...5).map { SkippedRow(rowNumber: $0 + 1, reason: "no name") })
        )
        #expect(five.ranges(of: "Row ").count == 5)
        #expect(!five.contains("more"))

        let six = ImportCopy.confirmationMessage(
            preview: preview(skipped: (1...6).map { SkippedRow(rowNumber: $0 + 1, reason: "no name") })
        )
        #expect(six.ranges(of: "Row ").count == 5)
        #expect(six.contains("\u{2026}and 1 more row."))
        #expect(six.hasPrefix("Skipping 6 rows:"))
    }

    @Test func skippedRowsListNumberAndReason() {
        let message = ImportCopy.confirmationMessage(
            preview: preview(skipped: [SkippedRow(rowNumber: 7, reason: "no name")])
        )
        #expect(message.contains("Row 7 \u{2014} no name"))
    }

    @Test func theDefaultedCountGetsItsOwnLine() {
        let message = ImportCopy.confirmationMessage(preview: preview(defaulted: 3))
        #expect(message == "3 missing or unreadable fields will use defaults.")
        let one = ImportCopy.confirmationMessage(preview: preview(defaulted: 1))
        #expect(one == "1 missing or unreadable field will use defaults.")
    }

    @Test func failureMessagesAreActionableAndAllEndWithTheGuarantee() {
        let undecodable = ImportCopy.failureMessage(for: .undecodable, target: .items)
        #expect(undecodable.contains("CSV UTF-8"))

        let unreadable = ImportCopy.failureMessage(for: .unreadable, target: .items)
        #expect(unreadable.contains("iCloud"))

        let errors: [ImportError] = [
            .unreadable, .undecodable, .malformedQuoting, .tooLarge,
            .headerMismatch(wrongList: true), .headerMismatch(wrongList: false),
        ]
        for error in errors {
            for target in [ImportTarget.items, .wishlist] {
                #expect(
                    ImportCopy.failureMessage(for: error, target: target)
                        .hasSuffix("Nothing was imported."),
                    "\(error) on \(target) lacks the criterion-14 state sentence"
                )
            }
        }
    }

    @Test func theWrongListMessageNamesTheOtherList() {
        let onItems = ImportCopy.failureMessage(for: .headerMismatch(wrongList: true), target: .items)
        #expect(onItems.contains("Wishlist export"))
        let onWishlist = ImportCopy.failureMessage(
            for: .headerMismatch(wrongList: true), target: .wishlist
        )
        #expect(onWishlist.contains("Items export"))
    }

    private func preview(
        skipped: [SkippedRow] = [],
        defaulted: Int = 0
    ) -> ImportPreview<ItemExportRecord> {
        ImportPreview(validated: [], skipped: skipped, defaultedFieldCount: defaulted)
    }
}
