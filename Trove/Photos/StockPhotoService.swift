import Foundation

/// The credit shown beside a fetched stock photo (spec P4): who made it, under
/// what licence, and the Commons file page the credit links to.
///
/// A plain `Sendable` value — it crosses from the fetch service (a background
/// `@concurrent` actor-free service, per the networking constitution) into the
/// stored `Photo` and back out through `Photo.attribution`. The full
/// `StockPhotoService` protocol and its live implementation arrive in a later
/// task; this file holds only the value type they exchange.
nonisolated struct StockPhotoAttribution: Sendable, Equatable {
    /// Who made the photo, for the credit line. Falls back to "Wikimedia
    /// Commons" when the file names no author (spec P4).
    let author: String
    /// The Wikimedia licence's short name, e.g. "CC BY-SA 4.0".
    let licenseName: String
    /// The Commons file page — the link the credit opens.
    let sourceURL: URL
}

/// The stock-photo source behind spec 005 — Wikimedia Commons — as the view
/// models see it: two calls, one candidate value, one licence, one error.
/// `nonisolated` with `@concurrent` requirements for the reason
/// `ExportService`/`MarketService` record: under the project's MainActor
/// default and approachable concurrency, a plain `nonisolated async`
/// requirement would run the network call on the caller's actor.
/// `WikimediaPhotoService` is the live implementation.
nonisolated protocol StockPhotoService: Sendable {
    /// Sends the item's name and nothing else (spec P1). Returns only files
    /// whose licence permits reuse with attribution (spec P3, §3).
    @concurrent func searchPhotos(named query: String) async throws -> [StockPhotoCandidate]
    /// Downloads the chosen candidate's storage-size image (Q2).
    @concurrent func imageData(from url: URL) async throws -> Data
}

/// One Commons file as the picker shows it. The URLs are for `AsyncImage` to
/// draw / for the app to download; only the chosen file's bytes are ever
/// stored (spec §3).
nonisolated struct StockPhotoCandidate: Sendable, Equatable, Identifiable {
    let id: Int              // the file's pageid
    let title: String        // the Commons file title, for the a11y label
    let thumbnailURL: URL     // the picker grid image (AsyncImage; transport only)
    let storageURL: URL       // the thumb the app downloads and stores
    let attribution: StockPhotoAttribution   // author, licence, file page
}

/// The result of downloading a chosen candidate: the stored bytes and the
/// attribution the host records beside them (spec P4). The picker's view model
/// hands this back from `download(_:)`; the host (T009/T010) decides what to do
/// with it — this is only the fetched pair.
nonisolated struct StockPhotoDownload: Sendable, Equatable {
    let imageData: Data
    let attribution: StockPhotoAttribution
}

nonisolated enum StockPhotoError: Error, Equatable, Sendable {
    /// No response at all — offline, DNS, a timeout (spec P8 sibling).
    case unreachable
    case serverError(status: Int)
    /// Not HTTP, a body the decoder couldn't read, or an image URL that
    /// isn't on a Wikimedia host.
    case malformedResponse
    /// The downloaded image was larger than the client's byte ceiling.
    case imageTooLarge
}

/// The reusable licences the app offers, each carrying the display name to
/// show beside the photo (spec §3). Reusability is read from Wikimedia's
/// `License` code; the display name from `LicenseShortName`.
nonisolated enum StockPhotoLicence: Sendable, Equatable {
    case cc0(displayName: String)
    case publicDomain(displayName: String)
    case ccBY(displayName: String)

    var displayName: String {
        switch self {
        case let .cc0(name), let .publicDomain(name), let .ccBY(name): name
        }
    }

    /// Decide reusability from the `License` code (lowercased), take the
    /// display name from `LicenseShortName`. Returns `nil` for a
    /// non-reusable or unknown file (spec §3):
    /// - CC0: code == "cc0" or begins "cc0".
    /// - public domain: code begins "pd" (covers `pd`, `PD-*`).
    /// - CC-BY / CC-BY-SA (any version): code begins "cc-by" and contains
    ///   neither "-nc" nor "-nd".
    /// - Everything else (`gfdl`, missing/empty) → nil.
    static func classify(shortName: String?, license: String?) -> StockPhotoLicence? {
        guard let license, !license.isEmpty else { return nil }
        let code = license.lowercased()
        // A reusable file's shortName is present in every real case; the
        // upper-cased code is the derived fallback when it isn't.
        let display = shortName?.isEmpty == false ? shortName! : license.uppercased()
        if code.hasPrefix("cc0") {
            return .cc0(displayName: display)
        }
        if code.hasPrefix("pd") {
            return .publicDomain(displayName: display)
        }
        if code.hasPrefix("cc-by"), !code.contains("-nc"), !code.contains("-nd") {
            return .ccBY(displayName: display)
        }
        return nil
    }
}
