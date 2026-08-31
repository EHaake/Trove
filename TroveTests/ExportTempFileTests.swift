import Foundation
import Testing
@testable import Trove

/// T004's guards over the staging lifecycle (criterion 10) and the pinned
/// filenames.
///
/// Real disk I/O by necessity — the subject *is* the file lifecycle, which
/// can't be checked without a filesystem. The same narrow, deliberate
/// exception shape as `CloudKitSchemaTests`: infrastructure claims get the
/// test that would catch them false. Each test gets its own scratch
/// directory so parallel runs can't collide.
struct ExportTempFileTests {
    private func makeService() throws -> (FileExportService, URL) {
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "ExportTempFileTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return (FileExportService(container: try makeInMemoryContainer(), directory: scratch), scratch)
    }

    private let table = CSVTable(headers: ["A"], rows: [["1"]])

    @Test func exportWritesTheExactCSVBytesAndReturnsTheirURL() async throws {
        let (service, scratch) = try makeService()
        defer { try? FileManager.default.removeItem(at: scratch) }

        let url = try await service.exportCSV(table, filename: "Trove-Items-2026-08-30.csv")
        #expect(url.lastPathComponent == "Trove-Items-2026-08-30.csv")
        #expect(url.deletingLastPathComponent().path == scratch.path)

        let written = try Data(contentsOf: url)
        // Byte-for-byte, BOM included — the file is the wire format.
        #expect(written == Data(CSVWriter.write(table).utf8))
    }

    /// Criterion 10's actual claim: nothing accumulates. A second export
    /// leaves exactly one file set, whatever the first was named.
    @Test func aSecondExportLeavesExactlyOneFileSet() async throws {
        let (service, scratch) = try makeService()
        defer { try? FileManager.default.removeItem(at: scratch) }

        _ = try await service.exportCSV(table, filename: "Trove-Items-2026-08-30.csv")
        let second = try await service.exportCSV(table, filename: "Trove-Wishlist-2026-08-30.csv")

        let remaining = try FileManager.default.contentsOfDirectory(atPath: scratch.path)
        #expect(remaining == [second.lastPathComponent])
    }

    @Test func purgeRemovesEverythingAndToleratesAMissingDirectory() async throws {
        let (service, scratch) = try makeService()
        defer { try? FileManager.default.removeItem(at: scratch) }

        // Nothing staged yet: purge must be a quiet no-op, not a throw —
        // it runs unconditionally at launch.
        try service.purge()

        _ = try await service.exportCSV(table, filename: "Trove-Items-2026-08-30.csv")
        try service.purge()
        #expect(!FileManager.default.fileExists(atPath: scratch.path))
    }

    @Test func filenamesCarryTheLocalDay() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let date = try #require(newYork.date(from: DateComponents(year: 2026, month: 1, day: 5)))

        #expect(ExportFilename.items(fileExtension: "csv", on: date, calendar: newYork)
            == "Trove-Items-2026-01-05.csv")
        #expect(ExportFilename.wishlist(fileExtension: "pdf", on: date, calendar: newYork)
            == "Trove-Wishlist-2026-01-05.pdf")
    }
}
