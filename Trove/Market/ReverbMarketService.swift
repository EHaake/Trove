import Foundation

/// Everything about Reverb's API that is a constant: the host the client
/// may talk to, the headers its docs ask for, the page size it allows, and
/// the caps this app chooses (plan §3, Q2, P22).
nonisolated enum ReverbAPI {
    static let host = "api.reverb.com"
    static let baseURL = URL(string: "https://api.reverb.com/api")!
    static let accept = "application/hal+json"
    static let acceptVersion = "3.0"
    /// Reverb's maximum per page.
    static let perPage = 50
    /// Ten pages of fifty: at most 500 listings and 11 requests per refresh.
    static let pageCap = 10
    /// Enough candidates that the exact variant is on the list (P22).
    static let searchCount = 15
    static let requestTimeout: TimeInterval = 15
    static let resourceTimeout: TimeInterval = 60

    /// Identifies the app to Reverb, with the contact address its terms ask
    /// for — read from `MarketCopy`, its one home.
    static func userAgent(version: AppVersion) -> String {
        "Trove/\(version.version) (iOS; \(MarketCopy.contactAddress))"
    }

    /// The link-back (spec P9): Reverb's product pages are addressed by
    /// slug, which is why the slug is what the device keeps (Decision 20).
    static func productURL(slug: String) -> URL {
        URL(string: "https://reverb.com/p/")!.appending(path: slug)
    }

    /// The one place a request is assembled, so the stub can assert on it.
    static func request(for url: URL, userAgent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(acceptVersion, forHTTPHeaderField: "Accept-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}

/// The live `MarketService` over `URLSession` (plan §3).
///
/// - One shared session for every view model, `.ephemeral`: nothing Reverb
///   returns is cached to disk or kept as a cookie. `waitsForConnectivity`
///   is off so an offline refresh fails fast into `.unreachable` instead of
///   holding a spinner.
/// - URLs are built with `URLComponents`, never interpolated — gear names
///   carry `&`, `+`, `#` and quotes.
/// - `_links.next` is followed only while it stays on Reverb's host; a page
///   that points elsewhere ends the walk and marks the result truncated.
/// - Errors map once, in `fetch`: `URLError` → `.unreachable`, 429 →
///   `.rateLimited`, 404 → what the caller says it means, anything else
///   non-2xx → `.serverError`.
///
/// `@concurrent` on every implementation, matching the requirements, for
/// the reason `ExportService` records; `requestProbe` is the seam
/// `ReverbMarketServiceTests` uses to prove the hop happened.
nonisolated final class ReverbMarketService: MarketService {
    private let session: URLSession
    private let userAgent: String
    private let pageCap: Int
    private let requestProbe: (@Sendable (_ isMainThread: Bool) -> Void)?

    init(
        session: URLSession = ReverbMarketService.sharedSession,
        userAgent: String = ReverbAPI.userAgent(version: .current),
        pageCap: Int = ReverbAPI.pageCap,
        requestProbe: (@Sendable (_ isMainThread: Bool) -> Void)? = nil
    ) {
        self.session = session
        self.userAgent = userAgent
        self.pageCap = pageCap
        self.requestProbe = requestProbe
    }

    static let sharedSession: URLSession = makeSession()

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = ReverbAPI.requestTimeout
        configuration.timeoutIntervalForResource = ReverbAPI.resourceTimeout
        configuration.waitsForConnectivity = false
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return URLSession(configuration: configuration)
    }

    @concurrent func searchProducts(named query: String) async throws -> [MarketCandidate] {
        requestProbe?(Self.onMainThread())
        var components = URLComponents(url: ReverbAPI.baseURL.appending(path: "csps"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: "\(ReverbAPI.searchCount)"),
        ]
        guard let url = components.url else { throw MarketError.malformedResponse }
        let data = try await fetch(url, notFound: .serverError(status: 404))
        return try ReverbDecoding.candidates(from: data)
    }

    @concurrent func product(id: Int) async throws -> MarketProduct {
        requestProbe?(Self.onMainThread())
        let url = ReverbAPI.baseURL.appending(path: "comparison_shopping_pages").appending(path: "\(id)")
        let data = try await fetch(url, notFound: .productNotFound)
        return try ReverbDecoding.product(from: data)
    }

    @concurrent func listings(for product: MarketProduct) async throws -> MarketListings {
        requestProbe?(Self.onMainThread())
        var next: URL? = Self.withPerPage(product.listingsURL)
        var listings: [MarketListing] = []
        var reportedTotal = 0
        var pages = 0
        var isTruncated = false

        while let url = next {
            guard pages < pageCap else {
                isTruncated = true
                break
            }
            let data = try await fetch(url, notFound: .serverError(status: 404))
            let page = try ReverbDecoding.page(from: data)
            pages += 1
            listings += page.listings
            reportedTotal = page.total
            if let following = page.next {
                if following.host == ReverbAPI.host {
                    next = following
                } else {
                    next = nil
                    isTruncated = true
                }
            } else {
                next = nil
            }
        }

        return MarketListings(listings: listings, reportedTotal: reportedTotal, isTruncated: isTruncated)
    }

    /// Reverb's listings link carries the product's ids; the page size is
    /// the client's to set.
    static func withPerPage(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = (components.queryItems ?? []).filter { $0.name != "per_page" }
        items.append(URLQueryItem(name: "per_page", value: "\(ReverbAPI.perPage)"))
        components.queryItems = items
        return components.url ?? url
    }

    private func fetch(_ url: URL, notFound: MarketError) async throws -> Data {
        let request = ReverbAPI.request(for: url, userAgent: userAgent)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MarketError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw MarketError.malformedResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 429: throw MarketError.rateLimited
        case 404: throw notFound
        default: throw MarketError.serverError(status: http.statusCode)
        }
    }

    private static func onMainThread() -> Bool { Thread.isMainThread }
}

// MARK: - Decoding

/// Reverb's HAL shapes, read into the app's own types. Explicit keys — the
/// `_links` names defeat any key strategy — and a per-listing lossy read:
/// one listing the decoder can't make sense of is dropped, not the page.
/// Separate from the service so `ReverbDecodingTests` can run every fixture
/// through it without a session.
nonisolated enum ReverbDecoding {
    struct Page: Equatable {
        let listings: [MarketListing]
        let total: Int
        let next: URL?
    }

    static func candidates(from data: Data) throws -> [MarketCandidate] {
        let wire = try decode(SearchWire.self, from: data)
        return wire.pages.map { csp in
            MarketCandidate(
                id: csp.id,
                slug: csp.slug,
                title: csp.title,
                brand: csp.brand?.name,
                imageURL: csp.photos?.lazy.compactMap { $0.links?.smallCrop?.url }.first,
                usedLowCents: csp.usedLowPrice?.amountCents,
                usedTotal: csp.usedTotal ?? 0
            )
        }
    }

    static func product(from data: Data) throws -> MarketProduct {
        let csp = try decode(CSPWire.self, from: data)
        guard let listingsURL = csp.links?.listings?.url else { throw MarketError.malformedResponse }
        return MarketProduct(
            id: csp.id,
            slug: csp.slug,
            title: csp.title,
            usedLowCents: csp.usedLowPrice?.amountCents,
            usedTotal: csp.usedTotal ?? 0,
            listingsURL: listingsURL
        )
    }

    static func page(from data: Data) throws -> Page {
        let wire = try decode(PageWire.self, from: data)
        let listings = wire.listings.compactMap(\.value).compactMap { listing -> MarketListing? in
            guard let price = listing.price, let slug = listing.condition?.slug, !slug.isEmpty else { return nil }
            // Both fields must agree for the listing to be priced in a
            // currency at all (plan §3): a missing `listing_currency` is
            // unknown, not the display currency, so it counts for none.
            let currency = listing.listingCurrency == price.currency ? price.currency : "\(listing.listingCurrency ?? "?")≠\(price.currency)"
            let year = listing.year?.trimmingCharacters(in: .whitespacesAndNewlines)
            return MarketListing(
                priceCents: price.amountCents,
                currency: currency,
                conditionSlug: slug,
                year: (year?.isEmpty ?? true) ? nil : year
            )
        }
        return Page(listings: listings, total: wire.total ?? listings.count, next: wire.links?.next?.url)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw MarketError.malformedResponse
        }
    }

    // The wire.

    private struct Lossy<Wrapped: Decodable>: Decodable {
        let value: Wrapped?
        init(from decoder: Decoder) {
            value = try? Wrapped(from: decoder)
        }
    }

    private struct Href: Decodable {
        let href: String
        var url: URL? { URL(string: href) }
    }

    private struct Money: Decodable {
        let amountCents: Int
        let currency: String
        enum CodingKeys: String, CodingKey {
            case amountCents = "amount_cents"
            case currency
        }
    }

    private struct SearchWire: Decodable {
        let pages: [CSPWire]
        enum CodingKeys: String, CodingKey {
            case pages = "comparison_shopping_pages"
        }
    }

    private struct CSPWire: Decodable {
        struct Brand: Decodable { let name: String? }
        struct Photo: Decodable {
            struct Links: Decodable {
                let smallCrop: Href?
                enum CodingKeys: String, CodingKey { case smallCrop = "small_crop" }
            }
            let links: Links?
            enum CodingKeys: String, CodingKey { case links = "_links" }
        }
        struct Links: Decodable {
            let web: Href?
            let listings: Href?
        }
        let id: Int
        let slug: String
        let title: String
        let brand: Brand?
        let photos: [Photo]?
        let usedLowPrice: Money?
        let usedTotal: Int?
        let links: Links?
        enum CodingKeys: String, CodingKey {
            case id, slug, title, brand, photos
            case usedLowPrice = "used_low_price"
            case usedTotal = "used_total"
            case links = "_links"
        }
    }

    private struct PageWire: Decodable {
        struct Links: Decodable { let next: Href? }
        let listings: [Lossy<ListingWire>]
        let total: Int?
        let links: Links?
        enum CodingKeys: String, CodingKey {
            case listings, total
            case links = "_links"
        }
    }

    private struct ListingWire: Decodable {
        struct Condition: Decodable { let slug: String? }
        let price: Money?
        let listingCurrency: String?
        let condition: Condition?
        let year: String?
        enum CodingKeys: String, CodingKey {
            case price, condition, year
            case listingCurrency = "listing_currency"
        }
    }
}
