import Foundation
import SwiftData

/// The boundary the list view models export through — a protocol so tests
/// inject a fake and assert on what the view model handed over, per the
/// constitution's injection rule (plan.md's Architecture section).
///
/// The requirements are `@concurrent` — load-bearing, not decoration. This
/// project builds with Approachable Concurrency, whose
/// `NonisolatedNonsendingByDefault` (SE-0461) runs nonisolated async
/// functions on the *caller's* actor — so without the attribute these would
/// execute on the main actor and silently block the UI (criterion 11).
/// T005's walking skeleton caught exactly that: the probe recorded
/// `[true, true]` until `@concurrent` forced the cooperative pool. On the
/// protocol, not just the class, because calls through the existential
/// follow the requirement's convention.
nonisolated protocol ExportService: Sendable {
    @concurrent func exportCSV(_ table: CSVTable, filename: String) async throws -> URL
    @concurrent func exportPDF(_ document: PDFDocumentModel, filename: String) async throws -> URL
}

/// A generated file waiting for the share sheet — what a view model stages
/// and a view presents. Foundation-only on purpose: it lives in view-model
/// state, and view models import no SwiftUI.
nonisolated struct StagedExport: Identifiable, Sendable, Equatable {
    let id = UUID()
    let url: URL
    let filename: String

    init(url: URL, filename: String) {
        self.url = url
        self.filename = filename
    }
}

/// The failure surface's copy (spec criterion 2a), shared so both list
/// screens and their view models can't drift — the `ItemDeleteCopy` pattern.
nonisolated enum ExportCopy {
    static let failureTitle = "Couldn't export"
    static let failureMessage = "Nothing was saved. Try again."
}

/// The share-sheet filenames the spec pins: `Trove-Items-YYYY-MM-DD.csv`
/// and friends, dated with the same local-day serialization the schema uses.
nonisolated enum ExportFilename {
    static func items(
        fileExtension: String,
        on date: Date = .now,
        timeZone: TimeZone = .current
    ) -> String {
        "Trove-Items-\(ExportSchema.day(from: date, timeZone: timeZone)).\(fileExtension)"
    }

    static func wishlist(
        fileExtension: String,
        on date: Date = .now,
        timeZone: TimeZone = .current
    ) -> String {
        "Trove-Wishlist-\(ExportSchema.day(from: date, timeZone: timeZone)).\(fileExtension)"
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

    /// The instrumented probe behind criterion 11's off-main claim
    /// (`ExportConcurrencyTests`): called at the top of each generation body
    /// with `Thread.isMainThread`, so the test asserts on the thread the work
    /// *actually* ran on — the T056 lesson, instrument the mechanism rather
    /// than a proxy. Nil (free) outside tests.
    private let generationProbe: (@Sendable (_ isMainThread: Bool) -> Void)?

    /// Where every real export stages — one location, so the launch sweep
    /// and the per-export purge can't disagree about what they clean.
    static let defaultDirectory: URL = FileManager.default.temporaryDirectory
        .appending(path: "Exports", directoryHint: .isDirectory)

    /// - Parameter directory: injectable so tests get an isolated directory;
    ///   the default is the one real location every export shares.
    init(
        container: ModelContainer,
        directory: URL = FileExportService.defaultDirectory,
        generationProbe: (@Sendable (_ isMainThread: Bool) -> Void)? = nil
    ) {
        self.container = container
        self.directory = directory
        self.generationProbe = generationProbe
    }

    // `@concurrent` on both entry points — see the protocol's doc comment:
    // under Approachable Concurrency a plain nonisolated async function runs
    // on the caller's actor, and these must not. Bodies stay synchronous
    // end-to-end; the probe test is what keeps all of this true.

    @concurrent func exportCSV(_ table: CSVTable, filename: String) async throws -> URL {
        generationProbe?(Self.onMainThread())
        return try stage(Data(CSVWriter.write(table).utf8), filename: filename)
    }

    @concurrent func exportPDF(_ document: PDFDocumentModel, filename: String) async throws -> URL {
        generationProbe?(Self.onMainThread())
        let fetcher = PhotoFetcher(container: container)
        return try stage(
            PDFComposer.render(document) { fetcher.imageData(for: $0) },
            filename: filename
        )
    }

    /// `Thread.isMainThread` is `noasync`; sampling it through a synchronous
    /// helper is the supported way to read the actual thread from an async
    /// body — and the actual thread is exactly what the probe is for.
    private static func onMainThread() -> Bool { Thread.isMainThread }

    /// Empties the staging directory. Called by `stage` before every write,
    /// and — via `purgeAtLaunch` — once at app startup.
    func purge() throws {
        try Self.purge(directory: directory)
    }

    /// The launch-time sweep (criterion 10's other half): clears whatever
    /// the previous session's share sheet left staged. Static, because at
    /// launch there's no service — or container — yet, and purging needs
    /// neither. Failures are swallowed: a sweep that can't run leaves at
    /// most one stale file set for the next export's own purge.
    static func purgeAtLaunch() {
        try? purge(directory: defaultDirectory)
    }

    private static func purge(directory: URL) throws {
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

/// Serves photo blobs to the composer from background contexts.
///
/// A fresh `ModelContext` every 25 fetches, deliberately: a context retains
/// every `imageData` it materializes, so one long-lived context would
/// quietly hold the whole collection's photos in memory and defeat the
/// per-entry streaming (plan.md's Concurrency section). An identifier that
/// doesn't resolve — a CloudKit delete landing between snapshot and fetch —
/// returns nil, and the composer lays that entry out photo-free.
private nonisolated final class PhotoFetcher {
    private let container: ModelContainer
    private var context: ModelContext?
    private var served = 0
    private static let batchSize = 25

    init(container: ModelContainer) {
        self.container = container
    }

    func imageData(for id: PersistentIdentifier) -> Data? {
        if context == nil || served >= Self.batchSize {
            context = ModelContext(container)
            served = 0
        }
        served += 1

        var descriptor = FetchDescriptor<Photo>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? context?.fetch(descriptor).first?.imageData
    }
}
