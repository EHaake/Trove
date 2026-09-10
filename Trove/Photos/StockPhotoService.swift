import Foundation

/// The credit shown beside a fetched stock photo (spec P4): who made it, under
/// what licence, and the Commons file page the credit links to.
///
/// A plain `Sendable` value — it crosses from the fetch service (a background
/// `@concurrent` actor-free service, per the networking constitution) into the
/// stored `Photo` and back out through `Photo.attribution`. The full
/// `StockPhotoService` protocol and its live implementation arrive in a later
/// task; this file holds only the value type they exchange.
struct StockPhotoAttribution: Sendable, Equatable {
    /// Who made the photo, for the credit line. Falls back to "Wikimedia
    /// Commons" when the file names no author (spec P4).
    let author: String
    /// The Wikimedia licence's short name, e.g. "CC BY-SA 4.0".
    let licenseName: String
    /// The Commons file page — the link the credit opens.
    let sourceURL: URL
}
