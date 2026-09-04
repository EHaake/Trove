import Foundation
import Synchronization
import Testing
@testable import Trove

/// The live client against a stubbed transport — no socket is ever opened
/// (CLAUDE.md, Networking). `StubURLProtocol` answers by URL, so each test
/// registers the exact pages it expects to be asked for; a request it has
/// no answer for fails loudly rather than reaching the network.
///
/// `.serialized` because the stub's tables are static — the only way a
/// `URLProtocol` subclass can carry state — and Swift Testing runs suites
/// in parallel by default.
@Suite("Reverb market service", .serialized)
struct ReverbMarketServiceTests {
    private func service(pageCap: Int = ReverbAPI.pageCap, probe: (@Sendable (Bool) -> Void)? = nil) -> ReverbMarketService {
        StubURLProtocol.reset()
        return ReverbMarketService(
            session: ReverbMarketService.makeSession(protocolClasses: [StubURLProtocol.self]),
            userAgent: ReverbAPI.userAgent(version: AppVersion(version: "9.9", build: "1")),
            pageCap: pageCap,
            requestProbe: probe
        )
    }

    private var telecaster: MarketProduct {
        get throws { try ReverbDecoding.product(from: try reverbFixture("csp-126161.json")) }
    }

    /// The seven recorded pages, each under the URL the client will ask for:
    /// the first under the product's link with the page size applied, the
    /// rest under the previous page's `next`.
    private func registerTelecasterPages(upTo last: Int = 7) throws {
        var url = ReverbMarketService.withPerPage(try telecaster.listingsURL)
        for page in 1...last {
            let data = try reverbFixture("listings-126161-p\(page).json")
            StubURLProtocol.register(url, status: 200, body: data)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let next = ((json?["_links"] as? [String: Any])?["next"] as? [String: Any])?["href"] as? String
            guard let next, let nextURL = URL(string: next) else { break }
            url = nextURL
        }
    }

    // MARK: - Requests

    @Test func everyRequestCarriesTheHeadersAndNeverAnAuthorization() async throws {
        let service = service()
        let url = try #require(URLComponents(string: "https://api.reverb.com/api/csps?query=x&per_page=15")?.url)
        StubURLProtocol.register(url, status: 200, body: try reverbFixture("csps-search-telecaster.json"))

        _ = try await service.searchProducts(named: "x")

        let request = try #require(StubURLProtocol.seen.first)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/hal+json")
        #expect(request.value(forHTTPHeaderField: "Accept-Version") == "3.0")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Trove/9.9") == true)
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains(MarketCopy.contactAddress) == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    /// Criterion 3: the name, and only the name, beside the page size — with
    /// the punctuation gear names actually carry surviving the trip.
    @Test func searchSendsTheNameAndOnlyThePageSize() async throws {
        let service = service()
        let name = "'65 Twin Reverb + case & cover #2"
        var components = URLComponents(string: "https://api.reverb.com/api/csps")!
        components.queryItems = [URLQueryItem(name: "query", value: name), URLQueryItem(name: "per_page", value: "15")]
        StubURLProtocol.register(try #require(components.url), status: 200, body: try reverbFixture("csps-search-telecaster.json"))

        let candidates = try await service.searchProducts(named: name)

        #expect(candidates.count == 3)
        let asked = try #require(StubURLProtocol.seen.first?.url)
        let items = URLComponents(url: asked, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.map(\.name).sorted() == ["per_page", "query"])
        #expect(items.first { $0.name == "query" }?.value == name)
        #expect(items.first { $0.name == "per_page" }?.value == "15")
    }

    // MARK: - Error mapping

    @Test func aMissingProductIsProductNotFound() async throws {
        let service = service()
        let url = URL(string: "https://api.reverb.com/api/comparison_shopping_pages/999999999")!
        StubURLProtocol.register(url, status: 404, body: try reverbFixture("csp-404.json"))

        await #expect(throws: MarketError.productNotFound) {
            _ = try await service.product(id: 999_999_999)
        }
    }

    @Test func aRateLimitAnswerIsRateLimitedOnAnyCall() async throws {
        let service = service()
        let url = URL(string: "https://api.reverb.com/api/comparison_shopping_pages/126161")!
        StubURLProtocol.register(url, status: 429, body: try reverbFixture("rate-limited-429.json"))

        await #expect(throws: MarketError.rateLimited) {
            _ = try await service.product(id: 126_161)
        }
    }

    @Test func anotherStatusIsAServerError() async throws {
        let service = service()
        let url = URL(string: "https://api.reverb.com/api/comparison_shopping_pages/126161")!
        StubURLProtocol.register(url, status: 500, body: Data("oops".utf8))

        await #expect(throws: MarketError.serverError(status: 500)) {
            _ = try await service.product(id: 126_161)
        }
    }

    @Test func offlineIsUnreachable() async throws {
        let service = service()
        let url = URL(string: "https://api.reverb.com/api/comparison_shopping_pages/126161")!
        StubURLProtocol.register(url, failing: URLError(.notConnectedToInternet))

        await #expect(throws: MarketError.unreachable) {
            _ = try await service.product(id: 126_161)
        }
    }

    // MARK: - Listings

    @Test func sevenPagesAreFollowedInOrderAtFiftyEach() async throws {
        let service = service()
        try registerTelecasterPages()

        let listings = try await service.listings(for: try telecaster)

        #expect(listings.listings.count == 337)
        #expect(listings.reportedTotal == 337)
        #expect(!listings.isTruncated)
        let asked = StubURLProtocol.seen.compactMap(\.url)
        #expect(asked.count == 7)
        for url in asked {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.first { $0.name == "per_page" }?.value == "50", "\(url)")
            #expect(url.host == ReverbAPI.host)
        }
    }

    @Test func thePageCapStopsTheWalkAndSaysSo() async throws {
        let service = service(pageCap: 2)
        try registerTelecasterPages()

        let listings = try await service.listings(for: try telecaster)

        #expect(listings.listings.count == 100)
        #expect(listings.isTruncated)
        #expect(StubURLProtocol.seen.count == 2)
    }

    @Test func aNextLinkOnAnotherHostIsNotFollowed() async throws {
        let service = service()
        let product = MarketProduct(
            id: 900_100, slug: "fixture", title: "Fixture", usedLowCents: nil, usedTotal: 2,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=900100")!
        )
        StubURLProtocol.register(ReverbMarketService.withPerPage(product.listingsURL), status: 200, body: try reverbFixture("listings-next-elsewhere.json"))

        let listings = try await service.listings(for: product)

        #expect(listings.listings.count == 1)
        #expect(listings.isTruncated, "a page we didn't fetch existed")
        #expect(StubURLProtocol.seen.count == 1, "the client left Reverb's host: \(StubURLProtocol.seen.compactMap(\.url))")
    }

    @Test func theMixedPageReachesTheCallerWithFourListings() async throws {
        let service = service()
        let product = MarketProduct(
            id: 900_000, slug: "fixture", title: "Fixture", usedLowCents: nil, usedTotal: 6,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=900000")!
        )
        StubURLProtocol.register(ReverbMarketService.withPerPage(product.listingsURL), status: 200, body: try reverbFixture("listings-mixed.json"))

        let listings = try await service.listings(for: product)

        #expect(listings.listings.count == 4)
        #expect(!listings.isTruncated)
    }

    // MARK: - Concurrency

    /// The `ExportConcurrencyTests` shape: through the existential, from the
    /// main actor, every entry point's body runs off it. Red only when
    /// `@concurrent` is off both the requirement and the implementation.
    @Test func theThreeEntryPointsRunOffTheMainThread() async throws {
        let probe = Probe()
        let client: any MarketService = service(probe: { probe.record($0) })
        let searchURL = try #require(URLComponents(string: "https://api.reverb.com/api/csps?query=x&per_page=15")?.url)
        StubURLProtocol.register(searchURL, status: 200, body: try reverbFixture("csps-search-telecaster.json"))
        StubURLProtocol.register(URL(string: "https://api.reverb.com/api/comparison_shopping_pages/126161")!, status: 200, body: try reverbFixture("csp-126161.json"))
        try registerTelecasterPages(upTo: 1)

        #expect(sampledOnMainThread())
        _ = try await client.searchProducts(named: "x")
        let product = try await client.product(id: 126_161)
        _ = try? await client.listings(for: product)

        #expect(probe.sawMainThread == [false, false, false])
    }

    private nonisolated final class Probe: Sendable {
        private let state = Mutex<[Bool]>([])
        func record(_ isMainThread: Bool) { state.withLock { $0.append(isMainThread) } }
        var sawMainThread: [Bool] { state.withLock { $0 } }
    }

    private nonisolated func sampledOnMainThread() -> Bool { Thread.isMainThread }
}

// MARK: - The stubbed transport

/// Answers `URLSession` by URL — path plus sorted query, so the order the
/// client writes query items in doesn't matter — and records every request.
/// A URL with no registered answer fails with `.unsupportedURL`, so a test
/// that forgot a page fails on that page instead of reaching the network.
nonisolated final class StubURLProtocol: URLProtocol {
    private struct Answer {
        let status: Int
        let body: Data
        let error: URLError?
    }

    private static let answers = Mutex<[String: Answer]>([:])
    private static let requests = Mutex<[URLRequest]>([])

    static func register(_ url: URL, status: Int, body: Data) {
        answers.withLock { $0[key(url)] = Answer(status: status, body: body, error: nil) }
    }

    static func register(_ url: URL, failing error: URLError) {
        answers.withLock { $0[key(url)] = Answer(status: 0, body: Data(), error: error) }
    }

    static func reset() {
        answers.withLock { $0 = [:] }
        requests.withLock { $0 = [] }
    }

    static var seen: [URLRequest] { requests.withLock { $0 } }

    static func key(_ url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        let items = (components.queryItems ?? []).map { "\($0.name)=\($0.value ?? "")" }.sorted()
        return "\(components.host ?? "")\(components.path)?\(items.joined(separator: "&"))"
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        guard let url = request.url, let answer = Self.answers.withLock({ $0[Self.key(url)] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        if let error = answer.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/hal+json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
