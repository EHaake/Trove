import Foundation
import SwiftData
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
                serialNumber: nil, notes: "body, cap", reverbProductID: nil, year: nil,
                soldDate: nil, salePriceCents: nil, saleLocation: nil, saleNote: nil,
                firstPhotoID: nil,
                firstPhotoAttribution: nil
            ),
        ], timeZone: zone)
        let url = try write(CSVWriter.write(table))
        defer { try? FileManager.default.removeItem(at: url) }

        let preview = try await service().parseItems(at: url, timeZone: zone, locale: .current).asAllNew()
        #expect(preview.validated.count == 1)
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        #expect(preview.validated.first?.record.name == "Leica M6")
    }

    /// 006: a file carrying the four sale columns parses through the live
    /// service the same way — the sold row arrives sold, the owned row
    /// beside it owned, and nothing is counted as a default.
    @Test func aSoldRowParsesThroughTheServiceAsASale() async throws {
        let zone = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let soldOn = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 4)))
        let table = ExportSchema.itemsTable([
            ItemExportRecord(
                name: "Blues Junior", categoryPath: "Music/Amps",
                purchasePriceCents: 69_000, currencyCode: "USD",
                purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                purchaseLocation: nil, currentValueCents: nil, desireToKeep: 3,
                conditionRawValue: "good", conditionNotes: nil,
                serialNumber: nil, notes: nil, reverbProductID: nil, year: nil,
                soldDate: soldOn, salePriceCents: 55_000, saleLocation: "Reverb",
                saleNote: "Shipped", firstPhotoID: nil, firstPhotoAttribution: nil
            ),
            ItemExportRecord(
                name: "Strat", categoryPath: "Music/Guitars",
                purchasePriceCents: 120_000, currencyCode: "USD",
                purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                purchaseLocation: nil, currentValueCents: nil, desireToKeep: 3,
                conditionRawValue: "good", conditionNotes: nil,
                serialNumber: nil, notes: nil, reverbProductID: nil, year: nil,
                soldDate: nil, salePriceCents: nil, saleLocation: nil,
                saleNote: nil, firstPhotoID: nil, firstPhotoAttribution: nil
            ),
        ], timeZone: zone)
        let url = try write(CSVWriter.write(table))
        defer { try? FileManager.default.removeItem(at: url) }

        let preview = try await service().parseItems(at: url, timeZone: zone, locale: .current).asAllNew()
        #expect(preview.validated.count == 2)
        #expect(preview.defaultedFieldCount == 0)
        #expect(preview.validated[0].record.soldDate == soldOn)
        #expect(preview.validated[0].record.salePriceCents == 55_000)
        #expect(preview.validated[0].record.saleLocation == "Reverb")
        #expect(preview.validated[0].record.saleNote == "Shipped")
        #expect(preview.validated[1].record.soldDate == nil)
        #expect(preview.validated[1].record.salePriceCents == nil)
    }

    @Test func aCanonicalWishlistFileParsesThroughTheWishlistMethod() async throws {
        let zone = TimeZone(identifier: "UTC")!
        let table = ExportSchema.wishlistTable([
            WishlistExportRecord(
                name: "OM-1", categoryPath: "Photography/Cameras",
                estimatedCostCents: 45_000, currencyCode: "USD", desireToOwn: 3,
                createdAt: Date(timeIntervalSince1970: 1_500_000_000),
                notes: nil, reverbProductID: nil, year: nil, firstPhotoID: nil,
                firstPhotoAttribution: nil
            ),
        ], timeZone: zone)
        let url = try write(CSVWriter.write(table))
        defer { try? FileManager.default.removeItem(at: url) }

        let preview = try await service().parseWishlist(at: url, timeZone: zone, locale: .current).asAllNew()
        #expect(preview.validated.count == 1)
        #expect(preview.validated.first?.record.name == "OM-1")
    }

    // MARK: - Error mapping

    @Test func garbageBytesMapToUndecodable() async throws {
        // 0xFF is never valid in UTF-8.
        let url = try write(Data([0xFF, 0xFE, 0xFD, 0x00]))
        defer { try? FileManager.default.removeItem(at: url) }
        await expectImportError(.undecodable) {
            try await self.service().parseItems(at: url, timeZone: .current, locale: .current)
        }
    }

    @Test func anOversizedFileMapsToTooLargeBeforeAnyRead() async throws {
        let url = try write(Data(count: FileImportService.maximumFileSize + 1))
        defer { try? FileManager.default.removeItem(at: url) }
        await expectImportError(.tooLarge) {
            try await self.service().parseItems(at: url, timeZone: .current, locale: .current)
        }
    }

    @Test func aMissingFileMapsToUnreadable() async {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "does-not-exist-\(UUID().uuidString).csv")
        await expectImportError(.unreadable) {
            try await self.service().parseItems(at: url, timeZone: .current, locale: .current)
        }
    }

    @Test func anUnclosedQuoteMapsToMalformedQuoting() async throws {
        let header = ExportSchema.itemHeaders.joined(separator: ",")
        let url = try write(header + "\r\n\"runaway,quote\r\nmore,rows\r\n")
        defer { try? FileManager.default.removeItem(at: url) }
        await expectImportError(.malformedQuoting) {
            try await self.service().parseItems(at: url, timeZone: .current, locale: .current)
        }
    }

    /// Rewritten for 021 (plan §5, T007): the header errors map onto the
    /// three new cases — the other list's file is `.wrongList`, a stranger's
    /// header is missing every required column, and a repeated column is
    /// named.
    @Test func theOtherListsFileMapsToTheFlaggedMismatch() async throws {
        let wishlistURL = try write(ExportSchema.wishlistHeaders.joined(separator: ",") + "\r\n")
        let strangerURL = try write("What,Ever\r\n")
        let doubledURL = try write("Name,Purchase Price,Purchase Date,Purchase Price\r\n")
        defer {
            try? FileManager.default.removeItem(at: wishlistURL)
            try? FileManager.default.removeItem(at: strangerURL)
            try? FileManager.default.removeItem(at: doubledURL)
        }
        await expectImportError(.wrongList) {
            try await self.service().parseItems(at: wishlistURL, timeZone: .current, locale: .current)
        }
        await expectImportError(.missingColumns(["Name", "Purchase Price", "Purchase Date"])) {
            try await self.service().parseItems(at: strangerURL, timeZone: .current, locale: .current)
        }
        await expectImportError(.duplicateColumn("Purchase Price")) {
            try await self.service().parseItems(at: doubledURL, timeZone: .current, locale: .current)
        }
        await expectImportError(.missingColumns(["Name", "Estimated Cost"])) {
            try await self.service().parseWishlist(at: strangerURL, timeZone: .current, locale: .current)
        }
    }

    /// G10: `locale` reaches the schema. An ambiguous slash date, through
    /// the live service: under `en_GB` it reads day-first, under `en_US`
    /// month-first, and the sheet says the region decided. Both, so no
    /// fixed locale substituted for the parameter can pass.
    @Test func theLocaleReachesTheSchema() async throws {
        let url = try write("Name,Purchase Price,Purchase Date\r\nNikon F3,300.00,3/4/2024\r\n")
        defer { try? FileManager.default.removeItem(at: url) }
        let zone = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        let british = try await service()
            .parseItems(at: url, timeZone: zone, locale: Locale(identifier: "en_GB"))
        #expect(british.regionDateOrder == .dayFirst)
        #expect(british.rows.map(\.purchaseDate) == [
            .value(try #require(calendar.date(from: DateComponents(year: 2024, month: 4, day: 3)))),
        ])

        let american = try await service()
            .parseItems(at: url, timeZone: zone, locale: Locale(identifier: "en_US"))
        #expect(american.regionDateOrder == .monthFirst)
        #expect(american.rows.map(\.purchaseDate) == [
            .value(try #require(calendar.date(from: DateComponents(year: 2024, month: 3, day: 4)))),
        ])
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
        _ = try await service.parseItems(at: itemsURL, timeZone: .current, locale: .current)
        _ = try await service.parseWishlist(at: wishlistURL, timeZone: .current, locale: .current)

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
    /// Rewritten for 021 (plan §5, T007): the cap moved to
    /// `confirmationLines`, pinned at its boundary — five skips list fully
    /// with no "more" line; six trigger "…and 1 more row."
    @Test func theSkipListingCapsAtFive() {
        let five = lines(summary(skipped: (1...5).map { SkippedRow(rowNumber: $0 + 1, reason: "no name") }))
        #expect(five.filter { $0.hasPrefix("Row ") }.count == 5)
        #expect(!five.contains { $0.contains("more") })

        let six = lines(summary(skipped: (1...6).map { SkippedRow(rowNumber: $0 + 1, reason: "no name") }))
        #expect(six.filter { $0.hasPrefix("Row ") }.count == 5)
        #expect(six.contains("\u{2026}and 1 more row."))
        #expect(six.first == "Skipping 6 rows:")
    }

    @Test func failureMessagesAreActionableAndAllEndWithTheGuarantee() {
        let undecodable = ImportCopy.failureMessage(for: .undecodable, target: .items)
        #expect(undecodable.contains("CSV UTF-8"))

        let unreadable = ImportCopy.failureMessage(for: .unreadable, target: .items)
        #expect(unreadable.contains("iCloud"))

        let errors: [ImportError] = [
            .unreadable, .undecodable, .malformedQuoting, .tooLarge,
            .wrongList, .missingColumns(["Purchase Price"]), .duplicateColumn("Purchase Price"),
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
        let onItems = ImportCopy.failureMessage(for: .wrongList, target: .items)
        #expect(onItems.contains("Wishlist export"))
        let onWishlist = ImportCopy.failureMessage(
            for: .wrongList, target: .wishlist
        )
        #expect(onWishlist.contains("Items export"))
    }

    // MARK: - 021 (plan §5; G8, G21, G22's words)

    @Test func theTitleAsksWhenTheFileWritesAndSaysNothingWhenItDoesNot() {
        #expect(ImportCopy.confirmationTitle(summary: summary(added: 1)) == "Import this file?")
        #expect(ImportCopy.confirmationTitle(summary: summary(updated: 1)) == "Import this file?")
        #expect(ImportCopy.confirmationTitle(summary: summary(unchanged: 75)) == "Nothing to import")
        #expect(ImportCopy.confirmationTitle(summary: ImportSummary()) == "Nothing to import")
    }

    @Test func theCountsLineInItsThreeShapesAndItsSingulars() {
        #expect(lines(summary(added: 90)) == ["90 items will be added."])
        #expect(lines(summary(added: 1)) == ["1 item will be added."])
        #expect(lines(summary(updated: 12)) == ["12 items will be updated.", "Updates can't be undone."])
        #expect(lines(summary(updated: 1)) == ["1 item will be updated.", "Updates can't be undone."])
        #expect(
            lines(summary(added: 3, updated: 12))
                == ["12 items will be updated and 3 added.", "Updates can't be undone."]
        )
        #expect(
            lines(summary(added: 1, updated: 1))
                == ["1 item will be updated and 1 added.", "Updates can't be undone."]
        )
        #expect(lines(summary(added: 2), target: .wishlist) == ["2 wishlist items will be added."])
        #expect(lines(summary(added: 1), target: .wishlist) == ["1 wishlist item will be added."])
    }

    @Test func theUnchangedLineAndItsSingular() {
        #expect(lines(summary(unchanged: 75)) == ["75 rows are unchanged."])
        #expect(lines(summary(unchanged: 1)) == ["1 row is unchanged."])
    }

    @Test func theSkippedBlockListsFiveThenCounts() {
        let seven = (1...7).map { SkippedRow(rowNumber: $0 + 1, reason: "no name") }
        #expect(lines(summary(skipped: seven)) == [
            "Skipping 7 rows:",
            "Row 2 \u{2014} no name", "Row 3 \u{2014} no name", "Row 4 \u{2014} no name",
            "Row 5 \u{2014} no name", "Row 6 \u{2014} no name",
            "\u{2026}and 2 more rows.",
        ])
        let six = (1...6).map { SkippedRow(rowNumber: $0 + 1, reason: "no name") }
        #expect(lines(summary(skipped: six)).last == "\u{2026}and 1 more row.")
        #expect(
            lines(summary(skipped: [SkippedRow(rowNumber: 7, reason: "no name")]))
                == ["Skipping 1 row:", "Row 7 \u{2014} no name"]
        )
    }

    /// The hint follows a shared-code skip wherever it falls — past the five
    /// listed rows too — and never follows any other reason.
    @Test func theSharedCodeHintOnlyWhenASkipCarriesThatReason() {
        let hint = "Clear the Trove ID on the row that's a new item."
        let shared = SkippedRow(rowNumber: 15, reason: ImportSchema.SkipReason.sameTroveID(asRows: [14]))
        #expect(lines(summary(skipped: [shared])) == ["Skipping 1 row:", "Row 15 \u{2014} same Trove ID as row 14", hint])

        let others = (2...7).map { SkippedRow(rowNumber: $0, reason: ImportSchema.SkipReason.noName) }
        let pastTheFifth = lines(summary(skipped: others + [shared]))
        #expect(!pastTheFifth.contains("Row 15 \u{2014} same Trove ID as row 14"))
        #expect(pastTheFifth.last == hint)

        let reasons = [
            ImportSchema.SkipReason.noName, ImportSchema.SkipReason.extraHeaderColumns,
            ImportSchema.SkipReason.ambiguousTroveID, ImportSchema.SkipReason.otherListTroveID,
            ImportSchema.SkipReason.alreadyBought,
        ]
        let noShared = lines(summary(skipped: reasons.enumerated().map { SkippedRow(rowNumber: $0.offset + 2, reason: $0.element) }))
        #expect(!noShared.contains(hint))
    }

    @Test func theTwoUnreadableLinesAndTheirSingulars() {
        #expect(
            lines(summary(added: 1, defaultedOnNew: 4))
                == ["1 item will be added.", "4 missing or unreadable cells on new rows will use defaults."]
        )
        #expect(
            lines(summary(added: 1, defaultedOnNew: 1))
                == ["1 item will be added.", "1 missing or unreadable cell on new rows will use defaults."]
        )
        // An unchanged row's unreadable cell is reported by the same line.
        #expect(
            lines(summary(unchanged: 3, unreadableOnUpdates: 2)) == [
                "3 rows are unchanged.",
                "2 unreadable cells on rows for items you already have will be left as they are.",
            ]
        )
        #expect(
            lines(summary(unchanged: 3, unreadableOnUpdates: 1)) == [
                "3 rows are unchanged.",
                "1 unreadable cell on rows for items you already have will be left as it is.",
            ]
        )
    }

    /// G21's words: R7's four sentences, one per missing column, in the
    /// sheet's order — and only when something is being added.
    @Test func theMissingColumnLinesOnlyWhenRowsAreAdded() {
        let items = summary(added: 2, missingDefaultColumns: ["Desire to Keep", "Condition"])
        #expect(lines(items) == [
            "2 items will be added.",
            "No Desire to Keep column \u{2014} new items will be 3 of 5.",
            "No Condition column \u{2014} new items will be Excellent.",
        ])
        let wishes = summary(added: 2, missingDefaultColumns: ["Desire to Own", "Added"])
        #expect(lines(wishes, target: .wishlist) == [
            "2 wishlist items will be added.",
            "No Desire to Own column \u{2014} new items will be 2 of 3.",
            "No Added column \u{2014} new items will be dated today.",
        ])
        let onlyUpdates = summary(updated: 2, missingDefaultColumns: ["Desire to Keep", "Condition"])
        #expect(lines(onlyUpdates) == ["2 items will be updated.", "Updates can't be undone."])
        let nothing = summary(unchanged: 2, missingDefaultColumns: ["Desire to Own", "Added"])
        #expect(lines(nothing, target: .wishlist) == ["2 rows are unchanged."])
    }

    @Test func theFileLevelLinesAndTheirSingulars() {
        #expect(lines(summary(unusedColumns: ["Mount", "Insured"])) == ["Not used: Mount, Insured."])
        #expect(lines(summary(totalsRows: [108])) == ["Row 108 looks like a totals row and was left out."])
        #expect(lines(summary(totalsRows: [40, 41, 42])) == ["3 rows look like totals rows and were left out."])
        #expect(
            lines(summary(unusedSaleRows: 3))
                == ["3 rows have sale details for items you still own. Mark them sold in the app."]
        )
        #expect(
            lines(summary(unusedSaleRows: 1))
                == ["1 row has sale details for an item you still own. Mark it sold in the app."]
        )
        #expect(lines(summary(regionDateOrder: .monthFirst)) == ["Dates read as month/day/year, from this iPhone's region."])
        #expect(lines(summary(regionDateOrder: .dayFirst)) == ["Dates read as day/month/year, from this iPhone's region."])
    }

    /// G22's words (R10, Decision 19), by literal at 90 and at 1, and absent
    /// at 0.
    @Test func theUnknownCodesWarningCarriesItsCountAndIsAbsentAtZero() {
        #expect(lines(summary(added: 90, keptCodeAdds: 90)) == [
            "90 items will be added.",
            "90 rows have a Trove ID this iPhone doesn't have yet. If iCloud is still bringing your "
                + "collection down, wait \u{2014} importing now adds them a second time.",
        ])
        #expect(lines(summary(added: 1, keptCodeAdds: 1)) == [
            "1 item will be added.",
            "1 row has a Trove ID this iPhone doesn't have yet. If iCloud is still bringing your "
                + "collection down, wait \u{2014} importing now adds it a second time.",
        ])
        #expect(lines(summary(added: 90, keptCodeAdds: 0)) == ["90 items will be added."])
    }

    @Test func theUndoLineOnlyWhenSomethingIsUpdated() {
        let undo = "Updates can't be undone."
        #expect(lines(summary(updated: 1)).contains(undo))
        #expect(lines(summary(added: 5, updated: 1)).contains(undo))
        #expect(!lines(summary(added: 5)).contains(undo))
        #expect(!lines(summary(unchanged: 5)).contains(undo))
    }

    @Test func theRecountedLineOnlyWhenRecountedAndFirst() {
        let recount = "Your collection changed while this was open. Check the numbers again."
        #expect(lines(summary(added: 2), recounted: true) == [recount, "2 items will be added."])
        #expect(lines(ImportSummary(), recounted: true) == [recount])
        #expect(!lines(summary(added: 2)).contains(recount))
    }

    @Test func noProblemsOnlyWhenNothingElseIsSaid() {
        #expect(lines(ImportSummary()) == ["No problems found."])
        #expect(!lines(summary(added: 1)).contains("No problems found."))
        #expect(!lines(summary(unusedColumns: ["Mount"])).contains("No problems found."))
    }

    /// Plan §5's order for a summary with everything set: the recount first,
    /// the two warnings last.
    @Test func everyLineInOrder() {
        var full = ImportSummary()
        full.added = 3
        full.updated = 12
        full.unchanged = 75
        full.skipped = [
            SkippedRow(rowNumber: 7, reason: ImportSchema.SkipReason.noName),
            SkippedRow(rowNumber: 15, reason: ImportSchema.SkipReason.sameTroveID(asRows: [14])),
        ]
        full.defaultedOnNew = 4
        full.unreadableOnUpdates = 2
        full.unusedColumns = ["Mount", "Insured"]
        full.totalsRows = [108]
        full.unusedSaleRows = 3
        full.regionDateOrder = .monthFirst
        full.missingDefaultColumns = ["Desire to Keep", "Condition"]
        full.keptCodeAdds = 2

        #expect(lines(full, recounted: true) == [
            "Your collection changed while this was open. Check the numbers again.",
            "12 items will be updated and 3 added.",
            "75 rows are unchanged.",
            "Skipping 2 rows:",
            "Row 7 \u{2014} no name",
            "Row 15 \u{2014} same Trove ID as row 14",
            "Clear the Trove ID on the row that's a new item.",
            "4 missing or unreadable cells on new rows will use defaults.",
            "2 unreadable cells on rows for items you already have will be left as they are.",
            "No Desire to Keep column \u{2014} new items will be 3 of 5.",
            "No Condition column \u{2014} new items will be Excellent.",
            "Not used: Mount, Insured.",
            "Row 108 looks like a totals row and was left out.",
            "3 rows have sale details for items you still own. Mark them sold in the app.",
            "Dates read as month/day/year, from this iPhone's region.",
            "2 rows have a Trove ID this iPhone doesn't have yet. If iCloud is still bringing your "
                + "collection down, wait \u{2014} importing now adds them a second time.",
            "Updates can't be undone.",
        ])
    }

    @Test func theThreeFailureSentences() {
        #expect(
            ImportCopy.failureMessage(for: .missingColumns(["Name"]), target: .items)
                == "This file is missing Name. Trove needs the columns marked * in the template. Nothing was imported."
        )
        #expect(
            ImportCopy.failureMessage(for: .missingColumns(["Purchase Price", "Purchase Date"]), target: .items)
                == "This file is missing Purchase Price and Purchase Date. Trove needs the columns marked * "
                + "in the template. Nothing was imported."
        )
        #expect(
            ImportCopy.failureMessage(for: .missingColumns(["Name", "Purchase Price", "Purchase Date"]), target: .items)
                == "This file is missing Name, Purchase Price and Purchase Date. Trove needs the columns "
                + "marked * in the template. Nothing was imported."
        )
        #expect(
            ImportCopy.failureMessage(for: .duplicateColumn("Purchase Price"), target: .items)
                == "This file has more than one Purchase Price column. Remove one and try again. Nothing was imported."
        )
        #expect(
            ImportCopy.failureMessage(for: .wrongList, target: .items)
                == "This looks like a Wishlist export. Import it from the Wishlist screen instead. Nothing was imported."
        )
        #expect(
            ImportCopy.failureMessage(for: .wrongList, target: .wishlist)
                == "This looks like a Items export. Import it from the Items screen instead. Nothing was imported."
        )
    }

    @Test func everySkipReasonsString() {
        #expect(ImportSchema.SkipReason.noName == "no name")
        #expect(ImportSchema.SkipReason.extraHeaderColumns == "more columns than the header")
        #expect(ImportSchema.SkipReason.sameTroveID(asRows: [15]) == "same Trove ID as row 15")
        #expect(ImportSchema.SkipReason.sameTroveID(asRows: [15, 16]) == "same Trove ID as rows 15 and 16")
        #expect(ImportSchema.SkipReason.sameTroveID(asRows: [15, 16, 17]) == "same Trove ID as rows 15, 16 and 17")
        #expect(ImportSchema.SkipReason.ambiguousTroveID == "its Trove ID matches more than one item")
        #expect(ImportSchema.SkipReason.otherListTroveID == "its Trove ID belongs to the other list")
        #expect(ImportSchema.SkipReason.alreadyBought == "already bought")
    }

    private func lines(
        _ summary: ImportSummary, target: ImportTarget = .items, recounted: Bool = false
    ) -> [String] {
        ImportCopy.confirmationLines(summary: summary, target: target, recounted: recounted)
    }

    private func summary(
        added: Int = 0, updated: Int = 0, unchanged: Int = 0,
        skipped: [SkippedRow] = [], defaultedOnNew: Int = 0, unreadableOnUpdates: Int = 0,
        unusedColumns: [String] = [], totalsRows: [Int] = [], unusedSaleRows: Int = 0,
        regionDateOrder: SlashDateOrder? = nil, missingDefaultColumns: [String] = [],
        keptCodeAdds: Int = 0
    ) -> ImportSummary {
        var summary = ImportSummary()
        summary.added = added
        summary.updated = updated
        summary.unchanged = unchanged
        summary.skipped = skipped
        summary.defaultedOnNew = defaultedOnNew
        summary.unreadableOnUpdates = unreadableOnUpdates
        summary.unusedColumns = unusedColumns
        summary.totalsRows = totalsRows
        summary.unusedSaleRows = unusedSaleRows
        summary.regionDateOrder = regionDateOrder
        summary.missingDefaultColumns = missingDefaultColumns
        summary.keptCodeAdds = keptCodeAdds
        return summary
    }
}

/// 021 T007, G10 (criterion 9): every layout an earlier Trove exported
/// imports through the live `FileImportService` with nothing skipped and
/// nothing defaulted — items at 12, 14, 18 and 19 columns, the wishlist at
/// 7, 9 and 10. The 020 layouts are byte copies under
/// `TroveTests/Fixtures/Import/`, never edited; the older widths are the
/// same rows cut at the width that release ended at (the layouts were
/// append-only), except 12, which is `items-partial.csv`'s own header, and
/// 14, which is `items-resaved.csv` as committed.
struct ImportLayoutTests {
    @Test func everyShippedItemsLayoutImportsWithNothingSkippedOrDefaulted() async throws {
        let layout = try CSVParser.parse(try text(fixture("items-020-layout.csv")))
        let header = try #require(layout.first)
        #expect(header.cells == Array(ExportSchema.itemHeaders.prefix(19)))
        let rows = layout.dropFirst().map(\.cells)
        try #require(rows.count == 12)

        let partialHeader = try #require(CSVParser.parse(try text(sample("items-partial.csv"))).first)
        try #require(partialHeader.cells.count == 12)
        let twelve = try write(CSVTable(headers: partialHeader.cells, rows: rows.map { Array($0.prefix(12)) }))
        let eighteen = try write(CSVTable(
            headers: Array(header.cells.prefix(18)), rows: rows.map { Array($0.prefix(18)) }
        ))
        defer {
            try? FileManager.default.removeItem(at: twelve)
            try? FileManager.default.removeItem(at: eighteen)
        }

        for (width, url, count) in [
            (12, twelve, 12), (14, sample("items-resaved.csv"), 5), (18, eighteen, 12),
            (19, fixture("items-020-layout.csv"), 12),
        ] {
            let sheet = try await FileImportService().parseItems(at: url, timeZone: .current, locale: .current)
            let new = sheet.asAllNew()
            #expect(new.validated.count == count, "items at \(width)")
            #expect(new.skipped.isEmpty, "items at \(width)")
            #expect(new.defaultedFieldCount == 0, "items at \(width)")
            #expect(sheet.unusedColumns.isEmpty, "items at \(width)")
            #expect(sheet.missingDefaultColumns.isEmpty, "items at \(width)")
        }
    }

    @Test func everyShippedWishlistLayoutImportsWithNothingSkippedOrDefaulted() async throws {
        let layout = try CSVParser.parse(try text(fixture("wishlist-020-layout.csv")))
        let header = try #require(layout.first)
        #expect(header.cells == Array(ExportSchema.wishlistHeaders.prefix(10)))
        let rows = layout.dropFirst().map(\.cells)
        try #require(rows.count == 4)

        let seven = try write(CSVTable(headers: Array(header.cells.prefix(7)), rows: rows.map { Array($0.prefix(7)) }))
        let nine = try write(CSVTable(headers: Array(header.cells.prefix(9)), rows: rows.map { Array($0.prefix(9)) }))
        defer {
            try? FileManager.default.removeItem(at: seven)
            try? FileManager.default.removeItem(at: nine)
        }

        for (width, url) in [(7, seven), (9, nine), (10, fixture("wishlist-020-layout.csv"))] {
            let sheet = try await FileImportService().parseWishlist(at: url, timeZone: .current, locale: .current)
            let new = sheet.asAllNew()
            #expect(new.validated.count == 4, "wishlist at \(width)")
            #expect(new.skipped.isEmpty, "wishlist at \(width)")
            #expect(new.defaultedFieldCount == 0, "wishlist at \(width)")
            #expect(sheet.unusedColumns.isEmpty, "wishlist at \(width)")
            #expect(sheet.missingDefaultColumns.isEmpty, "wishlist at \(width)")
        }
    }

    private func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func write(_ table: CSVTable) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ImportLayoutTests-\(UUID().uuidString).csv")
        try Data(CSVWriter.write(table).utf8).write(to: url)
        return url
    }

    private func fixture(_ name: String, file: StaticString = #filePath) -> URL {
        URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .appending(path: "Fixtures/Import")
            .appending(path: name)
    }

    private func sample(_ name: String, file: StaticString = #filePath) -> URL {
        URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/samples")
            .appending(path: name)
    }
}

/// 021 T007, G10 (criterion 37): every whole-file failure — unreadable, not
/// UTF-8, an unclosed quote, too large, a missing required column, a
/// duplicated column — imports nothing, never a partial batch. Driven
/// through each view model over the live service and real temp files (the
/// disk-I/O exception `ImportServiceTests` records), and checked on a
/// SECOND context over the same store, so an unsaved write can't hide.
struct ImportWholeFileFailureTests {
    @Test func everyWholeFileFailureLeavesTheItemsStoreEmpty() async throws {
        let files: [(String, URL)] = [
            ("unreadable", missingFile()),
            ("undecodable", try write(Data([0xFF, 0xFE, 0xFD, 0x00]))),
            ("unclosed quote", try write("Name,Purchase Price,Purchase Date\r\n\"Strat,100.00,2024-01-01\r\n")),
            ("too large", try write(Data(count: FileImportService.maximumFileSize + 1))),
            ("missing column", try write("Name,Purchase Price\r\nStrat,100.00\r\n")),
            ("duplicate column", try write(
                "Name,Purchase Price,Purchase Date,Name\r\nStrat,100.00,2024-01-01,Tele\r\n"
            )),
        ]
        defer { for (_, url) in files { try? FileManager.default.removeItem(at: url) } }

        for (label, url) in files {
            let container = try makeInMemoryContainer()
            let viewModel = ItemListViewModel(modelContext: ModelContext(container), importService: FileImportService())
            await viewModel.importCSV(from: url)
            guard case .failure = viewModel.importPresentation else {
                Issue.record("\(label): expected a failure presentation")
                continue
            }
            #expect(viewModel.confirmImport() == nil, "\(label)")
            #expect(try ModelContext(container).fetch(FetchDescriptor<Item>()).isEmpty, "\(label)")
        }
    }

    @Test func everyWholeFileFailureLeavesTheWishlistStoreEmpty() async throws {
        let files: [(String, URL)] = [
            ("unreadable", missingFile()),
            ("undecodable", try write(Data([0xFF, 0xFE, 0xFD, 0x00]))),
            ("unclosed quote", try write("Name,Estimated Cost\r\n\"OM-1,450.00\r\n")),
            ("too large", try write(Data(count: FileImportService.maximumFileSize + 1))),
            ("missing column", try write("Name,Notes\r\nOM-1,meter working\r\n")),
            ("duplicate column", try write("Name,Estimated Cost,Estimated Cost\r\nOM-1,450.00,500.00\r\n")),
        ]
        defer { for (_, url) in files { try? FileManager.default.removeItem(at: url) } }

        for (label, url) in files {
            let container = try makeInMemoryContainer()
            let viewModel = WishlistViewModel(modelContext: ModelContext(container), importService: FileImportService())
            await viewModel.importCSV(from: url)
            guard case .failure = viewModel.importPresentation else {
                Issue.record("\(label): expected a failure presentation")
                continue
            }
            #expect(viewModel.confirmImport() == nil, "\(label)")
            #expect(try ModelContext(container).fetch(FetchDescriptor<WishlistItem>()).isEmpty, "\(label)")
        }
    }

    private func missingFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "does-not-exist-\(UUID().uuidString).csv")
    }

    private func write(_ text: String) throws -> URL {
        try write(Data(text.utf8))
    }

    private func write(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ImportWholeFileFailureTests-\(UUID().uuidString).csv")
        try data.write(to: url)
        return url
    }
}
