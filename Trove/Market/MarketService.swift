import Foundation

/// The market source behind spec 002 — Reverb's public catalog and its
/// active listings — as the view models see it: three calls, four value
/// types, one error. `nonisolated` with `@concurrent` requirements for the
/// reason `ExportService` records: under the project's MainActor default
/// and approachable concurrency, a plain `nonisolated async` requirement
/// would run the network call on the caller's actor. `ReverbMarketService`
/// is the live implementation; `MarketServiceSpy` the test double.
nonisolated protocol MarketService: Sendable {
    /// Sends the name — and nothing else about the item (spec criterion 3).
    @concurrent func searchProducts(named query: String) async throws -> [MarketCandidate]

    /// The product a match points at. `MarketError.productNotFound` when
    /// Reverb no longer has it.
    @concurrent func product(id: Int) async throws -> MarketProduct

    /// Every page of the product's listings, up to the client's page cap.
    @concurrent func listings(for product: MarketProduct) async throws -> MarketListings
}

/// One catalog product as the picker shows it (spec criterion 3). The image
/// is a URL for `AsyncImage` to draw and is never stored (P14, Q17).
nonisolated struct MarketCandidate: Sendable, Equatable, Identifiable {
    let id: Int
    let slug: String
    let title: String
    let brand: String?
    let imageURL: URL?
    let usedLowCents: Int?
    let usedTotal: Int
}

/// The product a refresh works from: the withheld fallback's price, and
/// the listings link Reverb builds for it (product-scoped, unlike its
/// keyword search).
nonisolated struct MarketProduct: Sendable, Equatable {
    let id: Int
    let slug: String
    let title: String
    let usedLowCents: Int?
    let usedTotal: Int
    let listingsURL: URL
}

/// The whole of what the app learns about one listing — a price, the
/// currency it is priced in, a condition, and a year. No identifier, title,
/// seller or image: spec P14 holds by construction, and `ReverbDecodingTests`
/// pins the member count so nothing can be added quietly.
///
/// `currency` is the listing's own currency when Reverb's `listing_currency`
/// and `price.currency` agree. When they disagree — Reverb converts prices
/// for display — it is a two-currency marker that never equals a real
/// currency code, so the listing counts for no currency (P3).
nonisolated struct MarketListing: Sendable, Equatable {
    let priceCents: Int
    let currency: String
    let conditionSlug: String
    /// Reverb's free-text year — "2021", "1970 - 1984", "2020 - Present",
    /// "2020s", or nothing. Read by `MarketYearCoverage` (Decision 29).
    let year: String?
}

nonisolated struct MarketListings: Sendable, Equatable {
    let listings: [MarketListing]
    /// Reverb's `total` for the product, every currency and condition.
    let reportedTotal: Int
    /// A further page existed that the client didn't fetch — the page cap,
    /// or a `next` link that left Reverb's host.
    let isTruncated: Bool
}

nonisolated enum MarketError: Error, Equatable, Sendable {
    /// Reverb answered 429 (spec P7): stop, and say so.
    case rateLimited
    /// The product endpoint answered 404: the match points at nothing.
    case productNotFound
    /// No response at all — offline, DNS, a timeout (spec P8).
    case unreachable
    case serverError(status: Int)
    /// Not HTTP, or a body the decoder couldn't read.
    case malformedResponse
}
