import Foundation

/// The boundary the list view models import through — a protocol so tests
/// inject a fake and assert on what the view model staged, the same
/// injection rule `ExportService` follows (plan §Service and concurrency).
///
/// The requirements are `@concurrent` — load-bearing, not decoration, for
/// exactly `ExportService`'s reason: under Approachable Concurrency
/// (SE-0461) a plain nonisolated async function runs on the *caller's*
/// actor, and calls through the existential follow the requirement's
/// convention — without the attribute, parsing would silently run on the
/// main actor (criterion 15). `ImportConcurrencyTests`' probe keeps this
/// true.
nonisolated protocol ImportService: Sendable {
    @concurrent func parseItems(at url: URL, timeZone: TimeZone) async throws -> ItemsImportPreview
    @concurrent func parseWishlist(at url: URL, timeZone: TimeZone) async throws -> WishlistImportPreview
}

/// Whole-file failures — the only errors import produces; everything
/// row-level is a skip or a counted default inside the preview (the
/// amended skip-and-report decision, criterion 14's list).
nonisolated enum ImportError: Error, Equatable {
    /// The bytes couldn't be read at all (missing, permission, an iCloud
    /// file that hasn't downloaded).
    case unreadable
    /// Not UTF-8. Windows Excel's plain "CSV" save writes the system code
    /// page — only "CSV UTF-8" is UTF-8 — and a Latin-1 fallback would
    /// mean never detecting an encoding problem again, so this fails hard
    /// with actionable copy instead.
    case undecodable
    /// An unclosed quote swallowed the remainder of the file into one
    /// field; per-row recovery would import garbage (amended criterion 14).
    case malformedQuoting
    /// Beyond the defensive size cap.
    case tooLarge
    /// The header row isn't this list's template. `wrongList` means it is
    /// exactly the *other* list's — the most likely wrong-file mistake,
    /// and criterion 4 wants the alert to say so.
    case headerMismatch(wrongList: Bool)
}

/// Which list an import ran against — picks the copy's nouns, and which
/// list the wrong-file message points at.
nonisolated enum ImportTarget {
    case items
    case wishlist
}

/// What a list screen's import flow is presenting, or nothing. One optional
/// drives the one import alert per screen — the list views already carry
/// three presentations, and independent booleans that can go true together
/// are how SwiftUI silently drops one (plan §View-model surface). Dumb
/// data: the view models compose its strings through `ImportCopy`.
nonisolated enum ImportPresentation<Record: Sendable>: Sendable {
    /// The pre-commit gate (criterion 5). A preview with nothing validated
    /// still presents — informationally, with no import action.
    case confirmation(ImportPreview<Record>)
    case failure(title: String, message: String)
}

/// Every user-facing import string, pinned in one place so the two screens
/// and their view models can't drift — the `ExportCopy`/`ItemDeleteCopy`
/// pattern. Pure functions; `ImportCopyTests` pin the exact strings.
nonisolated enum ImportCopy {
    static let failureTitle = "Couldn't import"

    /// The live service only throws `ImportError`, but the protocol can't
    /// promise that — anything else gets honesty over specifics.
    static let unexpectedFailureMessage = "Something went wrong. Nothing was imported."

    /// The commit's save failing after a rollback (plan §The commit path) —
    /// the store is untouched, and the copy says so.
    static let saveFailureMessage = "Saving failed. Nothing was imported."

    /// Every failure message ends with the same state sentence — the
    /// criterion-14 guarantee, stated to the user every time.
    static func failureMessage(for error: ImportError, target: ImportTarget) -> String {
        let body: String
        switch error {
        case .unreadable:
            body = "The file couldn't be read. If it's stored in iCloud, "
                + "make sure it has finished downloading, then try again."
        case .undecodable:
            body = "The file isn't UTF-8 text. In Excel, save it as "
                + "\u{201C}CSV UTF-8\u{201D} and try again."
        case .malformedQuoting:
            body = "The file has an unclosed quote, so its rows can't be "
                + "told apart. Fix the file and try again."
        case .tooLarge:
            body = "The file is too large to be a \(target.noun) export."
        case .headerMismatch(wrongList: true):
            body = "This looks like a \(target.other.noun) export. "
                + "Import it from the \(target.other.screenName) screen instead."
        case .headerMismatch(wrongList: false):
            body = "The columns don't match the \(target.noun) template. "
                + "Get Blank Template\u{2026} in the \u{2026} menu shows the expected layout."
        }
        return body + " Nothing was imported."
    }

    /// The confirmation alert's title carries the import count
    /// (criterion 5); zero importable rows is informational only.
    static func confirmationTitle(importCount: Int, target: ImportTarget) -> String {
        switch importCount {
        case 0: "Nothing to import"
        case 1: "Import 1 \(target.singular)?"
        default: "Import \(importCount) \(target.plural)?"
        }
    }

    /// How many skipped rows the confirmation lists before "and N more" —
    /// the amended criterion-5 cap, decided 2026-08-31.
    static let maxListedSkips = 5

    /// The confirmation body: skipped rows by spreadsheet number with
    /// reasons (capped), then the defaulted-field count. Pure over the
    /// preview so it's testable without any UI.
    static func confirmationMessage<Record>(preview: ImportPreview<Record>) -> String {
        var lines: [String] = []
        if !preview.skipped.isEmpty {
            let count = preview.skipped.count
            lines.append("Skipping \(count) \(count == 1 ? "row" : "rows"):")
            for skip in preview.skipped.prefix(maxListedSkips) {
                lines.append("Row \(skip.rowNumber) \u{2014} \(skip.reason)")
            }
            if count > maxListedSkips {
                let more = count - maxListedSkips
                lines.append("\u{2026}and \(more) more \(more == 1 ? "row" : "rows").")
            }
        }
        if preview.defaultedFieldCount > 0 {
            let count = preview.defaultedFieldCount
            lines.append(
                "\(count) missing or unreadable \(count == 1 ? "field" : "fields") will use defaults."
            )
        }
        if lines.isEmpty {
            lines.append("No problems found.")
        }
        return lines.joined(separator: "\n")
    }
}

// `nonisolated` again on the extension: a type's isolation doesn't carry
// into its extensions under the project-wide MainActor default.
nonisolated extension ImportTarget {
    var noun: String {
        switch self {
        case .items: "Items"
        case .wishlist: "Wishlist"
        }
    }

    var screenName: String { noun }

    var singular: String {
        switch self {
        case .items: "item"
        case .wishlist: "wishlist item"
        }
    }

    var plural: String {
        switch self {
        case .items: "items"
        case .wishlist: "wishlist items"
        }
    }

    var other: ImportTarget {
        switch self {
        case .items: .wishlist
        case .wishlist: .items
        }
    }
}

/// The live implementation: reads the picked file inside the one
/// `@concurrent` call — security scope opened, read, and closed within a
/// single function, so no scope crosses an actor hop (plan §Service and
/// concurrency) — then decodes, parses, and validates, mapping the
/// pipeline's errors onto `ImportError`. Holds no `ModelContainer`:
/// parsing touches no store; committing is the view model's job, on the
/// main actor.
nonisolated final class FileImportService: ImportService {
    /// The defensive cap (amended criterion 14): ~10 MB is orders of
    /// magnitude beyond a personal inventory's CSV; this exists so a
    /// mis-picked video can't balloon memory, not to police real files.
    static let maximumFileSize = 10 * 1024 * 1024

    /// The instrumented probe behind criterion 15's off-main claim —
    /// same seam as `FileExportService.generationProbe`, same T056 lesson:
    /// the test asserts on the thread the work actually ran on. Nil (free)
    /// outside tests.
    private let generationProbe: (@Sendable (_ isMainThread: Bool) -> Void)?

    init(generationProbe: (@Sendable (_ isMainThread: Bool) -> Void)? = nil) {
        self.generationProbe = generationProbe
    }

    @concurrent func parseItems(at url: URL, timeZone: TimeZone) async throws -> ItemsImportPreview {
        generationProbe?(Self.onMainThread())
        let text = try readText(at: url)
        return try Self.mapped { try ImportSchema.itemsPreview(from: CSVParser.parse(text), timeZone: timeZone) }
    }

    @concurrent func parseWishlist(at url: URL, timeZone: TimeZone) async throws -> WishlistImportPreview {
        generationProbe?(Self.onMainThread())
        let text = try readText(at: url)
        return try Self.mapped { try ImportSchema.wishlistPreview(from: CSVParser.parse(text), timeZone: timeZone) }
    }

    /// `Thread.isMainThread` is `noasync`; sampling through a synchronous
    /// helper is the supported way to read the actual thread.
    private static func onMainThread() -> Bool { Thread.isMainThread }

    private func readText(at url: URL) throws -> String {
        // `false` is tolerated deliberately: a URL that isn't
        // security-scoped (a test's temp file) reports false and reads
        // fine. The stop is conditional for the same reason — an
        // unbalanced stop corrupts the access count.
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > Self.maximumFileSize {
            throw ImportError.tooLarge
        }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        guard let text = String(data: data, encoding: .utf8) else { throw ImportError.undecodable }
        return text
    }

    /// One place where the pipeline's own errors become `ImportError`, so
    /// the two parse methods can't map them differently.
    private static func mapped<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch CSVParseError.unclosedQuote {
            throw ImportError.malformedQuoting
        } catch ImportSchema.HeaderError.wrongList {
            throw ImportError.headerMismatch(wrongList: true)
        } catch ImportSchema.HeaderError.mismatch {
            throw ImportError.headerMismatch(wrongList: false)
        }
    }
}
