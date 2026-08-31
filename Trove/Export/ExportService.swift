import Foundation
import SwiftData

/// The boundary the list view models export through — a protocol so tests
/// inject a fake and assert on what the view model handed over, per the
/// constitution's injection rule (plan.md's Architecture section).
///
/// Explicitly `nonisolated`, like everything in the export module: the
/// requirements are `async` precisely so conforming implementations run off
/// the caller's actor (SE-0338), which is what criterion 11 needs.
nonisolated protocol ExportService: Sendable {
    func exportCSV(_ table: CSVTable, filename: String) async throws -> URL
}

/// The share-sheet filenames the spec pins: `Trove-Items-YYYY-MM-DD.csv`
/// and friends, dated with the same local-day serialization the schema uses.
nonisolated enum ExportFilename {
    static func items(
        fileExtension: String,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        "Trove-Items-\(ExportSchema.day(from: date, calendar: calendar)).\(fileExtension)"
    }

    static func wishlist(
        fileExtension: String,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        "Trove-Wishlist-\(ExportSchema.day(from: date, calendar: calendar)).\(fileExtension)"
    }
}

/// The live implementation: stages files under one dedicated temp directory,
/// purged before every export and once at launch — so at most the latest
/// file set ever exists and canceling the share sheet needs no cleanup hook
/// (criterion 10; plan.md's "Delivery and temp-file lifecycle").
nonisolated final class FileExportService: ExportService {
    /// Held for the PDF path's background photo fetches (T008) — the
    /// container is `Sendable`; contexts are made fresh where they're used.
    private let container: ModelContainer

    private let directory: URL

    /// - Parameter directory: injectable so tests get an isolated directory;
    ///   the default is the one real location every export shares.
    init(
        container: ModelContainer,
        directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "Exports", directoryHint: .isDirectory)
    ) {
        self.container = container
        self.directory = directory
    }

    func exportCSV(_ table: CSVTable, filename: String) async throws -> URL {
        try stage(Data(CSVWriter.write(table).utf8), filename: filename)
    }

    /// Empties the staging directory. Called by `stage` before every write,
    /// and once at app launch (T014) to sweep whatever the last session's
    /// share sheet left behind.
    func purge() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func stage(_ data: Data, filename: String) throws -> URL {
        try purge()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: filename)
        try data.write(to: url)
        return url
    }
}
