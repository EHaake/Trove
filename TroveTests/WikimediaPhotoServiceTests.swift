import Foundation
import Synchronization
import Testing
@testable import Trove

/// The live client against a stubbed transport — no socket is ever opened
/// (CLAUDE.md, Networking). A dedicated `WikimediaStubURLProtocol` with its
/// own static tables, NOT `StubURLProtocol`: sharing static state across two
/// `.serialized` service suites that Swift Testing runs in parallel risks one
/// suite's `reset()` wiping the other mid-run.
@Suite("Wikimedia photo service", .serialized)
struct WikimediaPhotoServiceTests {
    private func service(
        maxImageBytes: Int = WikimediaAPI.maxImageBytes,
        probe: (@Sendable (Bool) -> Void)? = nil
    ) -> WikimediaPhotoService {
        WikimediaStubURLProtocol.reset()
        return WikimediaPhotoService(
            session: WikimediaPhotoService.makeSession(protocolClasses: [WikimediaStubURLProtocol.self]),
            userAgent: WikimediaAPI.userAgent(version: AppVersion(version: "9.9", build: "1")),
            maxImageBytes: maxImageBytes,
            requestProbe: probe
        )
    }

    /// The URL the client will ask for a given search name — built exactly as
    /// the service builds it, so registering by it matches.
    private func searchURL(for name: String) -> URL {
        var components = URLComponents(url: WikimediaAPI.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: name),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "20"),
            URLQueryItem(name: "prop", value: "imageinfo|categories"),
            URLQueryItem(name: "iiprop", value: "url|extmetadata|mime"),
            URLQueryItem(name: "iiurlwidth", value: "1024"),
            URLQueryItem(name: "cllimit", value: "500"),
        ]
        return components.url!
    }

    // MARK: - The request (G5)

    @Test func searchSendsOnlyTheNameBesideTheFixedParams() async throws {
        let service = service()
        let name = "Nikon D750"
        WikimediaStubURLProtocol.register(searchURL(for: name), status: 200, body: try wikimediaFixture("search-camera.json"))

        _ = try await service.searchPhotos(named: name)

        let asked = try #require(WikimediaStubURLProtocol.seen.first?.url)
        let items = URLComponents(url: asked, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.map(\.name).sorted() == [
            "action", "cllimit", "format", "formatversion", "generator", "gsrlimit",
            "gsrnamespace", "gsrsearch", "iiprop", "iiurlwidth", "prop",
        ])
        // The one param that carries the item is gsrsearch, and it carries only
        // the name — the new prop/cllimit params carry no item data.
        #expect(items.first { $0.name == "gsrsearch" }?.value == name)
    }

    @Test func punctuationInTheNameSurvivesTheRoundTrip() async throws {
        let service = service()
        let name = "'65 SM7B + shield & pop"
        WikimediaStubURLProtocol.register(searchURL(for: name), status: 200, body: try wikimediaFixture("search-camera.json"))

        _ = try await service.searchPhotos(named: name)

        let asked = try #require(WikimediaStubURLProtocol.seen.first?.url)
        let items = URLComponents(url: asked, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "gsrsearch" }?.value == name)
    }

    @Test func everyRequestCarriesTheUserAgentAndNeverAnAuthorization() async throws {
        let service = service()
        WikimediaStubURLProtocol.register(searchURL(for: "x"), status: 200, body: try wikimediaFixture("search-camera.json"))

        _ = try await service.searchPhotos(named: "x")

        let request = try #require(WikimediaStubURLProtocol.seen.first)
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("Trove/") == true)
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains(StockPhotoCopy.contactAddress) == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: - Error mapping

    @Test func offlineIsUnreachable() async throws {
        let service = service()
        WikimediaStubURLProtocol.register(searchURL(for: "x"), failing: URLError(.notConnectedToInternet))

        await #expect(throws: StockPhotoError.unreachable) {
            _ = try await service.searchPhotos(named: "x")
        }
    }

    @Test func aFiveHundredIsAServerError() async throws {
        let service = service()
        WikimediaStubURLProtocol.register(searchURL(for: "x"), status: 500, body: Data("oops".utf8))

        await #expect(throws: StockPhotoError.serverError(status: 500)) {
            _ = try await service.searchPhotos(named: "x")
        }
    }

    // MARK: - The byte ceiling

    @Test func anOversizeImageIsImageTooLarge() async throws {
        let service = service(maxImageBytes: 32)
        let url = URL(string: "https://upload.wikimedia.org/x.jpg")!
        WikimediaStubURLProtocol.register(url, status: 200, body: Data(count: 33))

        await #expect(throws: StockPhotoError.imageTooLarge) {
            _ = try await service.imageData(from: url)
        }
    }

    @Test func aSmallImageOnAWikimediaHostReturnsItsBytes() async throws {
        let service = service()
        let url = URL(string: "https://upload.wikimedia.org/small.jpg")!
        let bytes = try wikimediaFixture("image-small.bin")
        WikimediaStubURLProtocol.register(url, status: 200, body: bytes)

        let data = try await service.imageData(from: url)
        #expect(data == bytes)
    }

    // MARK: - The host check (G7)

    @Test func aForeignHostImageURLIsNotFetched() async throws {
        let service = service()
        let url = URL(string: "https://evil.com/x.jpg")!
        WikimediaStubURLProtocol.register(url, status: 200, body: Data(count: 4))

        await #expect(throws: StockPhotoError.malformedResponse) {
            _ = try await service.imageData(from: url)
        }
        #expect(WikimediaStubURLProtocol.seen.isEmpty, "the client fetched a foreign host: \(WikimediaStubURLProtocol.seen.compactMap(\.url))")
    }

    @Test func theRealThumbnailHostPasses() async throws {
        let service = service()
        let url = URL(string: "https://thumb.wikimedia.org/wikipedia/commons/thumb/5/5d/x/1024px-x.jpg")!
        let bytes = try wikimediaFixture("image-small.bin")
        WikimediaStubURLProtocol.register(url, status: 200, body: bytes)

        let data = try await service.imageData(from: url)
        #expect(data == bytes)
        #expect(WikimediaStubURLProtocol.seen.count == 1)
    }

    // MARK: - Concurrency (G6)

    /// Through the existential, from the main actor, both entry points' bodies
    /// run off it. Red only when `@concurrent` is off both the requirement and
    /// the implementation.
    @Test func bothEntryPointsRunOffTheMainThread() async throws {
        let probe = Probe()
        let client: any StockPhotoService = service(probe: { probe.record($0) })
        WikimediaStubURLProtocol.register(searchURL(for: "x"), status: 200, body: try wikimediaFixture("search-camera.json"))
        let imageURL = URL(string: "https://upload.wikimedia.org/small.jpg")!
        WikimediaStubURLProtocol.register(imageURL, status: 200, body: try wikimediaFixture("image-small.bin"))

        #expect(sampledOnMainThread())
        _ = try await client.searchPhotos(named: "x")
        _ = try await client.imageData(from: imageURL)

        #expect(probe.sawMainThread == [false, false])
    }

    private nonisolated final class Probe: Sendable {
        private let state = Mutex<[Bool]>([])
        func record(_ isMainThread: Bool) { state.withLock { $0.append(isMainThread) } }
        var sawMainThread: [Bool] { state.withLock { $0 } }
    }

    private nonisolated func sampledOnMainThread() -> Bool { Thread.isMainThread }
}

// MARK: - The stubbed transport

/// A dedicated copy of the Reverb suite's stub, with its own static tables so
/// the two `.serialized` service suites can't wipe each other's answers when
/// Swift Testing runs them in parallel. Answers by host + path + sorted query,
/// records every request, and fails an unregistered URL with `.unsupportedURL`
/// so a socket is never opened.
nonisolated final class WikimediaStubURLProtocol: URLProtocol {
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
        let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
