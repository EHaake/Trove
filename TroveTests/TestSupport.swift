import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
import Synchronization
@testable import Trove

/// Records what the view models hand to `ExportService`, so intent tests
/// assert on the actual payload (plan.md's Architecture section). Capture
/// goes through a `Mutex` because the requirements are `@concurrent` — the
/// calls land off-main even when the test drives them from the main actor.
nonisolated final class ExportServiceSpy: ExportService {
    struct PlannedFailure: Error {}

    private struct Captured {
        var tables: [CSVTable] = []
        var documents: [PDFDocumentModel] = []
        var filenames: [String] = []
        var fileSets: [[ExportFile]] = []
    }

    private let captured = Mutex(Captured())
    private let failsEveryCall: Bool

    init(failsEveryCall: Bool = false) {
        self.failsEveryCall = failsEveryCall
    }

    var tables: [CSVTable] { captured.withLock { $0.tables } }
    var documents: [PDFDocumentModel] { captured.withLock { $0.documents } }
    var filenames: [String] { captured.withLock { $0.filenames } }
    /// Every `exportFiles` call, as handed over — so a test can assert a
    /// pair arrived in *one* call, not as two single-file exports that would
    /// purge each other on the live service.
    var fileSets: [[ExportFile]] { captured.withLock { $0.fileSets } }

    @concurrent func exportFiles(_ files: [ExportFile]) async throws -> [URL] {
        guard !failsEveryCall else { throw PlannedFailure() }
        captured.withLock {
            $0.fileSets.append(files)
            for file in files {
                switch file {
                case .csv(let table, let filename):
                    $0.tables.append(table)
                    $0.filenames.append(filename)
                case .pdf(let document, let filename):
                    $0.documents.append(document)
                    $0.filenames.append(filename)
                }
            }
        }
        return files.map { URL(filePath: "/dev/null/\($0.filename)") }
    }

    @concurrent func exportCSV(_ table: CSVTable, filename: String) async throws -> URL {
        guard !failsEveryCall else { throw PlannedFailure() }
        captured.withLock {
            $0.tables.append(table)
            $0.filenames.append(filename)
        }
        return URL(filePath: "/dev/null/\(filename)")
    }

    @concurrent func exportPDF(_ document: PDFDocumentModel, filename: String) async throws -> URL {
        guard !failsEveryCall else { throw PlannedFailure() }
        captured.withLock {
            $0.documents.append(document)
            $0.filenames.append(filename)
        }
        return URL(filePath: "/dev/null/\(filename)")
    }
}

/// A spy whose CSV export blocks until released — for observing *mid-flight*
/// view-model state (`isExporting`) and the reentrancy guard, which is
/// load-bearing: `stage()` purges the staging directory before writing, so a
/// genuinely concurrent second export would delete the file the first just
/// handed to `stagedExport`. Added at T019/S1, where review found nothing
/// could fail if `isExporting = true` were deleted.
nonisolated final class GatedExportServiceSpy: ExportService {
    private struct State {
        var csvCalls = 0
        var pdfCalls = 0
        var fileSetCalls = 0
        var released = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let state = Mutex(State())

    var csvCalls: Int { state.withLock { $0.csvCalls } }
    var pdfCalls: Int { state.withLock { $0.pdfCalls } }
    var fileSetCalls: Int { state.withLock { $0.fileSetCalls } }

    /// 013's set path gates on the same first-call-only rule as `exportCSV`
    /// below, for the same reason: a reentrant `exportFiles` that reaches the
    /// spy must fail a count, not hang the test.
    @concurrent func exportFiles(_ files: [ExportFile]) async throws -> [URL] {
        let isFirstCall = state.withLock { state -> Bool in
            state.fileSetCalls += 1
            return state.fileSetCalls == 1
        }
        let urls = files.map { URL(filePath: "/dev/null/\($0.filename)") }
        guard isFirstCall else { return urls }
        await waitUntilReleased()
        return urls
    }

    private func waitUntilReleased() async {
        await withCheckedContinuation { continuation in
            let resumeNow = state.withLock { state -> Bool in
                guard !state.released else { return true }
                state.waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func release() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
            state.released = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume()
    }

    @concurrent func exportCSV(_ table: CSVTable, filename: String) async throws -> URL {
        // Only the FIRST call gates. A reentrant call that wrongly reaches
        // the spy must fail the call-count assertion *fast* — gating it too
        // would deadlock the test instead of failing it, which is how the
        // T019/S1 mutation was first "caught" (by a hang, not a red).
        let isFirstCall = state.withLock { state -> Bool in
            state.csvCalls += 1
            return state.csvCalls == 1
        }
        guard isFirstCall else { return URL(filePath: "/dev/null/\(filename)") }

        await waitUntilReleased()
        return URL(filePath: "/dev/null/\(filename)")
    }

    @concurrent func exportPDF(_ document: PDFDocumentModel, filename: String) async throws -> URL {
        state.withLock { $0.pdfCalls += 1 }
        return URL(filePath: "/dev/null/\(filename)")
    }
}

/// Records the URLs the view models hand to `ImportService` and answers
/// with a configured preview — or throws a configured `ImportError` — so
/// intent tests assert staging and failure mapping without file I/O.
nonisolated final class ImportServiceSpy: ImportService {
    private struct Captured {
        var itemURLs: [URL] = []
        var wishlistURLs: [URL] = []
    }

    private let captured = Mutex(Captured())
    private let itemsResult: Result<ItemsImportPreview, ImportError>
    private let wishlistResult: Result<WishlistImportPreview, ImportError>

    init(
        items: Result<ItemsImportPreview, ImportError> =
            .success(ImportPreview(validated: [], skipped: [], defaultedFieldCount: 0)),
        wishlist: Result<WishlistImportPreview, ImportError> =
            .success(ImportPreview(validated: [], skipped: [], defaultedFieldCount: 0))
    ) {
        itemsResult = items
        wishlistResult = wishlist
    }

    var itemURLs: [URL] { captured.withLock { $0.itemURLs } }
    var wishlistURLs: [URL] { captured.withLock { $0.wishlistURLs } }

    @concurrent func parseItems(at url: URL, timeZone: TimeZone) async throws -> ItemsImportPreview {
        captured.withLock { $0.itemURLs.append(url) }
        return try itemsResult.get()
    }

    @concurrent func parseWishlist(at url: URL, timeZone: TimeZone) async throws -> WishlistImportPreview {
        captured.withLock { $0.wishlistURLs.append(url) }
        return try wishlistResult.get()
    }
}

/// A spy whose parse blocks until released — the `GatedExportServiceSpy`
/// discipline for `isImportingFile`: only the FIRST call gates, so a
/// reentrant call that wrongly reaches the spy fails the call-count
/// assertion *fast* instead of deadlocking the test (the T019/S1 lesson).
/// Each method gates its own first call; a test drives one list at a time.
nonisolated final class GatedImportServiceSpy: ImportService {
    private struct State {
        var itemCalls = 0
        var wishlistCalls = 0
        var released = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let state = Mutex(State())

    var itemCalls: Int { state.withLock { $0.itemCalls } }
    var wishlistCalls: Int { state.withLock { $0.wishlistCalls } }

    func release() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
            state.released = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume()
    }

    @concurrent func parseItems(at url: URL, timeZone: TimeZone) async throws -> ItemsImportPreview {
        let isFirstCall = state.withLock { state -> Bool in
            state.itemCalls += 1
            return state.itemCalls == 1
        }
        if isFirstCall { await gate() }
        return ImportPreview(validated: [], skipped: [], defaultedFieldCount: 0)
    }

    @concurrent func parseWishlist(at url: URL, timeZone: TimeZone) async throws -> WishlistImportPreview {
        let isFirstCall = state.withLock { state -> Bool in
            state.wishlistCalls += 1
            return state.wishlistCalls == 1
        }
        if isFirstCall { await gate() }
        return ImportPreview(validated: [], skipped: [], defaultedFieldCount: 0)
    }

    private func gate() async {
        await withCheckedContinuation { continuation in
            let resumeNow = state.withLock { state -> Bool in
                guard !state.released else { return true }
                state.waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }
}

/// A fresh in-memory store holding the real schema — real persistence
/// semantics, no disk, no CloudKit. Each call is an isolated store, so tests
/// can't leak state into one another.
func makeInMemoryContext() throws -> ModelContext {
    ModelContext(try makeInMemoryContainer())
}

/// The container behind `makeInMemoryContext()`, for tests that need a *second*
/// context over the same store.
///
/// Worth having because a same-context refetch is not a persistence check:
/// `ModelContext.fetch` returns objects carrying unsaved changes, so a test
/// that toggles something and refetches passes whether or not `save()` was
/// called. Mutation testing caught exactly that in the Sell Plan's
/// "persists on every change" tests — they read as persistence checks and
/// weren't. A second context sees only what actually reached the store.
func makeInMemoryContainer() throws -> ModelContainer {
    // Exactly the app's `-uiTesting` shape (002/T006a): the synced and the
    // local configuration as a pair, in memory. A single in-memory
    // configuration over the union cannot hold a local model once the test
    // host's own two-store container exists in the process — see
    // `TroveStore.configurations(for:)`.
    try TroveStore.buildContainer(TroveStore.configurations(for: .ephemeral))
}

/// The perceptual colour model the design-correctness tests measure against.
///
/// Oklab: a space built so equal steps look like equal steps, which HSV hue
/// degrees emphatically are not — the reason "the hues are evenly spaced" was a
/// misleading way to check the dial's ramp in the first place. ΔE here is plain
/// Euclidean distance in (L, a, b).
///
/// Shared rather than duplicated per suite: the dial checks palette tokens and
/// the gauge checks pixels sampled off a rendered view, and two copies of this
/// matrix drifting apart would make the two sets of thresholds incomparable.
enum Perceptual {
    /// ΔE between two palette colours.
    static func distance(_ first: Color, _ second: Color) -> Double {
        distance(oklab(first), oklab(second))
    }

    /// ΔE between two sampled pixels.
    static func distance(_ first: RGB8, _ second: RGB8) -> Double {
        distance(oklab(first), oklab(second))
    }

    /// ΔE between a sampled pixel and the palette colour it should have come
    /// from — how a render is checked against its own tokens.
    static func distance(_ pixel: RGB8, _ color: Color) -> Double {
        distance(oklab(pixel), oklab(color))
    }

    static func oklab(_ color: Color) -> (Double, Double, Double) {
        // `Color.Resolved` exposes the linearised channels directly, which is
        // exactly what the matrix below wants — no gamma maths to get wrong.
        let resolved = color.resolve(in: EnvironmentValues())
        return oklab(
            linearRed: Double(resolved.linearRed),
            linearGreen: Double(resolved.linearGreen),
            linearBlue: Double(resolved.linearBlue)
        )
    }

    /// Sampled pixels arrive as sRGB bytes, so they need linearising by hand
    /// before the same matrix applies.
    static func oklab(_ pixel: RGB8) -> (Double, Double, Double) {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return oklab(
            linearRed: linear(pixel.red),
            linearGreen: linear(pixel.green),
            linearBlue: linear(pixel.blue)
        )
    }

    private static func oklab(
        linearRed r: Double,
        linearGreen g: Double,
        linearBlue b: Double
    ) -> (Double, Double, Double) {
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

        return (
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    private static func distance(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        sqrt(pow(a.0 - b.0, 2) + pow(a.1 - b.1, 2) + pow(a.2 - b.2, 2))
    }
}

/// One sampled pixel, as 8-bit sRGB.
struct RGB8: Equatable, CustomStringConvertible {
    let red: Int
    let green: Int
    let blue: Int

    var description: String { String(format: "#%02X%02X%02X", red, green, blue) }
}

/// Renders a view at 1× and returns its bitmap.
///
/// `ImageRenderer` sizes content to its ideal size, which is what the layout
/// and colour tests are both asking about. The theme has to be supplied by hand
/// — there's no host app to inherit it from.
@MainActor
func renderBitmap(_ view: some View) -> CGImage? {
    let renderer = ImageRenderer(content: view.environment(\.theme, .dark))
    renderer.scale = 1
    return renderer.cgImage
}

/// Every pixel of a rendered image, in a known sRGB byte layout so individual
/// samples can be indexed by point coordinate.
struct Bitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        width = image.width
        height = image.height

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let raw = context.data else { return nil }

        let buffer = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)
        bytes = Array(UnsafeBufferPointer(start: buffer, count: width * height * 4))
    }

    /// The pixel at a point, or nil if it falls outside the image — a sample
    /// that silently clamped to an edge would measure the wrong thing.
    func pixel(at point: CGPoint) -> RGB8? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }

        let offset = (y * width + x) * 4
        return RGB8(
            red: Int(bytes[offset]),
            green: Int(bytes[offset + 1]),
            blue: Int(bytes[offset + 2])
        )
    }
}

/// Reading Swift sources as text, for the handful of guards whose subject is
/// "is this wired up" rather than "does this compute the right answer".
///
/// Source scans are fragile by nature and this project has already shipped two
/// that couldn't fail: one asked whether a file contained a string *anywhere*,
/// which one wired tab out of three satisfied, and a second was satisfied by a
/// private helper that had stopped being called. Both were found by mutation
/// testing, not by reading them. Centralised here so the next scan starts from
/// the hardened version rather than re-deriving it.
enum SourceScan {
    /// A source file's production code: comments stripped, and everything from
    /// the first `#Preview` dropped.
    ///
    /// Comments matter because a scan for `.onChange(of: viewModel.x)` is
    /// otherwise satisfied by a comment mentioning it — which is exactly how a
    /// guard survives the code it guards being deleted. Previews matter because
    /// they legitimately use defaults no shipping call site should.
    static func production(_ path: String, file: StaticString = #filePath) throws -> String {
        let url = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        let source = try String(contentsOf: url, encoding: .utf8)
        let code = source.range(of: "#Preview").map { String(source[..<$0.lowerBound]) } ?? source
        return stripComments(code)
    }

    /// Drops `//` line comments and `/* */` blocks. Deliberately naive about
    /// `//` inside string literals — no source in this project has one, and a
    /// scan that quietly over-matched would be worse than one that over-strips.
    static func stripComments(_ source: String) -> String {
        var output = ""
        var index = source.startIndex
        var inLine = false
        var inBlock = false

        while index < source.endIndex {
            let rest = source[index...]
            if !inLine, !inBlock, rest.hasPrefix("//") {
                inLine = true
            } else if !inLine, !inBlock, rest.hasPrefix("/*") {
                inBlock = true
                index = source.index(index, offsetBy: 2)
                continue
            } else if inLine, source[index] == "\n" {
                inLine = false
            } else if inBlock, rest.hasPrefix("*/") {
                inBlock = false
                index = source.index(index, offsetBy: 2)
                continue
            }

            if !inLine, !inBlock { output.append(source[index]) }
            index = source.index(after: index)
        }

        return output
    }

    /// The contents of every `"…"` literal, which for a view is close enough
    /// to "the text a person can read on screen".
    ///
    /// Scanning whole source for a forbidden *word* catches identifiers that
    /// merely contain it — `sectionGap` and `listRowGap` both contain "gap",
    /// which is why the Sell Plan's framing guard originally scanned only the
    /// view model and left the copy unguarded. Literals are the right unit.
    static func stringLiterals(in source: String) -> [String] {
        var results: [String] = []
        var current = ""
        var inString = false
        var escaped = false

        for character in source {
            if escaped { escaped = false; if inString { current.append(character) }; continue }
            if character == "\\" { escaped = true; continue }
            if character == "\"" {
                if inString { results.append(current); current = "" }
                inString.toggle()
                continue
            }
            if inString { current.append(character) }
        }

        return results
    }

    /// The text between the parentheses of each `callee(…)`, paren-depth aware
    /// so a nested call doesn't end the match early.
    static func argumentLists(of callee: String, in source: String) -> [String] {
        spans(opening: "(", closing: ")", after: "\(callee)(", in: source)
    }

    /// The text between the braces of each `label { … }`, brace-depth aware.
    static func closureBodies(after label: String, in source: String) -> [String] {
        spans(opening: "{", closing: "}", after: label, in: source, findsOpener: true)
    }

    private static func spans(
        opening: Character,
        closing: Character,
        after marker: String,
        in source: String,
        findsOpener: Bool = false
    ) -> [String] {
        var results: [String] = []
        var rest = Substring(source)

        while let match = rest.range(of: marker) {
            var start = match.upperBound
            if findsOpener {
                guard let open = rest[match.upperBound...].firstIndex(of: opening) else { break }
                start = rest.index(after: open)
            }

            var depth = 1
            var index = start
            while index < rest.endIndex, depth > 0 {
                if rest[index] == opening { depth += 1 }
                if rest[index] == closing { depth -= 1 }
                if depth > 0 { index = rest.index(after: index) }
            }
            guard depth == 0 else { break }

            results.append(String(rest[start..<index]))
            rest = rest[index...]
        }

        return results
    }
}

// MARK: - Market service doubles (002)

/// Answers `MarketService` from scripts — one result per expected call, in
/// order — and records every call. An **exhausted script throws**, so a view
/// model that calls once more than the test expected fails on that call
/// rather than passing on a repeated answer. Capture behind a `Mutex`
/// because the requirements are `@concurrent`.
nonisolated final class MarketServiceSpy: MarketService {
    enum Call: Equatable, Sendable {
        case search(String)
        case product(Int)
        case listings(productID: Int)
    }

    struct ScriptExhausted: Error, Equatable {
        let call: Call
    }

    private struct State {
        var calls: [Call] = []
        var search: [Result<[MarketCandidate], MarketError>]
        var products: [Result<MarketProduct, MarketError>]
        var listings: [Result<MarketListings, MarketError>]
    }

    private let state: Mutex<State>

    init(
        search: [Result<[MarketCandidate], MarketError>] = [],
        products: [Result<MarketProduct, MarketError>] = [],
        listings: [Result<MarketListings, MarketError>] = []
    ) {
        state = Mutex(State(search: search, products: products, listings: listings))
    }

    var calls: [Call] { state.withLock { $0.calls } }

    @concurrent func searchProducts(named query: String) async throws -> [MarketCandidate] {
        try next(.search(query)) { $0.search.isEmpty ? nil : $0.search.removeFirst() }
    }

    @concurrent func product(id: Int) async throws -> MarketProduct {
        try next(.product(id)) { $0.products.isEmpty ? nil : $0.products.removeFirst() }
    }

    @concurrent func listings(for product: MarketProduct) async throws -> MarketListings {
        try next(.listings(productID: product.id)) { $0.listings.isEmpty ? nil : $0.listings.removeFirst() }
    }

    private func next<T>(_ call: Call, _ pop: @Sendable (inout State) -> Result<T, MarketError>?) throws -> T {
        let scripted = state.withLock { state -> Result<T, MarketError>? in
            state.calls.append(call)
            return pop(&state)
        }
        guard let scripted else { throw ScriptExhausted(call: call) }
        return try scripted.get()
    }
}

/// The `GatedExportServiceSpy` shape for the market: only the **first**
/// `listings` call gates, so a reentrant refresh that wrongly reaches the
/// spy fails a call count fast instead of deadlocking the test. Search and
/// product answer at once from one scripted value each.
///
/// `gatesSearch` moves the gate to the **first** `searchProducts` call
/// instead (002/T011), for the picker's reentry guard — the same question
/// one call further out, so it belongs on this double rather than in a
/// second one. Only one gate is ever open at a time, and `release()`
/// releases whichever it is.
nonisolated final class GatedMarketServiceSpy: MarketService {
    private struct State {
        var listingsCalls = 0
        var searchCalls = 0
        var queries: [String] = []
        var released = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let state = Mutex(State())
    private let candidates: [MarketCandidate]
    private let productAnswer: Result<MarketProduct, MarketError>
    private let listingsAnswer: Result<MarketListings, MarketError>
    private let gatesSearch: Bool

    init(
        candidates: [MarketCandidate] = [],
        product: Result<MarketProduct, MarketError>,
        listings: Result<MarketListings, MarketError>,
        gatesSearch: Bool = false
    ) {
        self.candidates = candidates
        self.productAnswer = product
        self.listingsAnswer = listings
        self.gatesSearch = gatesSearch
    }

    var listingsCalls: Int { state.withLock { $0.listingsCalls } }
    var searchCalls: Int { state.withLock { $0.searchCalls } }
    var queries: [String] { state.withLock { $0.queries } }

    @concurrent func searchProducts(named query: String) async throws -> [MarketCandidate] {
        let isFirstCall = state.withLock { state -> Bool in
            state.searchCalls += 1
            state.queries.append(query)
            return state.searchCalls == 1
        }
        if gatesSearch, isFirstCall { await waitUntilReleased() }
        return candidates
    }

    @concurrent func product(id: Int) async throws -> MarketProduct { try productAnswer.get() }

    @concurrent func listings(for product: MarketProduct) async throws -> MarketListings {
        let isFirstCall = state.withLock { state -> Bool in
            state.listingsCalls += 1
            return state.listingsCalls == 1
        }
        guard isFirstCall else { return try listingsAnswer.get() }
        await waitUntilReleased()
        return try listingsAnswer.get()
    }

    private func waitUntilReleased() async {
        await withCheckedContinuation { continuation in
            let resumeNow = state.withLock { state -> Bool in
                guard !state.released else { return true }
                state.waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func release() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
            state.released = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume()
    }
}

// MARK: - The figure, before Amendment B's trimmed bounds

extension MarketFigure {
    /// **Test-only**: the memberwise init as it read before the trimmed
    /// bounds (002 Amendment B, T021), with `p10Cents`/`p90Cents` defaulted
    /// to the ends — where the nearest rank puts them on a small count
    /// anyway. Every test that doesn't care about the bounds keeps its call
    /// site; a test that does passes them explicitly through the memberwise
    /// init. Deliberately *not* a default on the production initializer,
    /// which no caller may forget.
    /// Note the shape this defaulting produces: percentiles *equal* to the
    /// ends, which the production computation only reaches on a small count —
    /// and the two ends part company at different sizes. The nearest rank
    /// puts the 10th on the first element for n ≤ 10, and the 90th on the
    /// last for n ≤ 9 only: at ten the 90th's rank is `⌈0.9·10⌉ = 9`, the
    /// ninth of the ten. So both ends coincide up to nine listings, the low
    /// end alone at ten, and neither past that — meaning a figure built
    /// through this shim is not a realistic larger-count row, and any test asserting how the trimmed bounds
    /// behave must use the memberwise init with `p10Cents`/`p90Cents`
    /// distinct from the low and the high.
    /// `nonisolated`, like the type: the test target defaults to `MainActor`,
    /// and some call sites (a `@Test(arguments:)` table, a spy's closure) are
    /// not on it.
    nonisolated init(medianCents: Int, lowCents: Int, highCents: Int, count: Int, fetchedAt: Date, isTruncated: Bool, yearScope: YearScope) {
        self.init(
            medianCents: medianCents, lowCents: lowCents, highCents: highCents,
            p10Cents: lowCents, p90Cents: highCents,
            count: count, fetchedAt: fetchedAt, isTruncated: isTruncated, yearScope: yearScope
        )
    }
}
