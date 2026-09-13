import Foundation

/// Everything about Wikimedia Commons' API that is a constant: the host the
/// client may talk to, the endpoint, the search params it fixes, and the caps
/// this app chooses (plan §2, Q2). Mirrors `ReverbAPI`.
nonisolated enum WikimediaAPI {
    static let host = "commons.wikimedia.org"
    static let endpoint = URL(string: "https://commons.wikimedia.org/w/api.php")!
    /// The generator's page count — Wikimedia returns up to this many files.
    static let searchLimit = 20
    /// The width the app asks Wikimedia to render the stored thumbnail at.
    static let storageWidth = 1024
    /// At most this many candidates reach the picker (plan §2).
    static let candidateCap = 12
    /// The largest image the app will accept from Wikimedia — one home for
    /// the cap, beside the others (Phase 1 review note 1).
    static let maxImageBytes = 8 * 1024 * 1024
    static let requestTimeout: TimeInterval = 15
    static let resourceTimeout: TimeInterval = 60

    /// Identifies the app to Wikimedia, with the contact address its
    /// User-Agent policy asks for — read from `StockPhotoCopy`, its one home.
    static func userAgent(version: AppVersion) -> String {
        "Trove/\(version.version) (iOS; \(StockPhotoCopy.contactAddress))"
    }

    /// The one place the search request is assembled, so the stub can assert
    /// on it. Unauthenticated — Wikimedia needs no `Authorization`.
    static func request(for url: URL, userAgent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// An exact `wikimedia.org` or any `.wikimedia.org` subdomain — covers
    /// `upload`/`thumb`/`commons`, rejects `evil.com`,
    /// `wikimedia.org.evil.com`, `notwikimedia.org`.
    static func isWikimediaHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "wikimedia.org" || host.hasSuffix(".wikimedia.org")
    }
}

/// The live `StockPhotoService` over `URLSession` (plan §2).
///
/// - One shared session, `.ephemeral`: nothing Wikimedia returns is cached to
///   disk. `waitsForConnectivity` is off so an offline search fails fast into
///   `.unreachable` instead of holding a spinner.
/// - The search URL is built with `URLComponents`, never interpolated — gear
///   names carry `&`, `+`, `#` and quotes.
/// - Searching sends only the item's name (spec P1): the fixed generator/prop
///   params plus `gsrsearch`, and nothing about the item.
/// - Downloading fetches only from a Wikimedia host, checked before any
///   request leaves the app, and refuses an image past the byte ceiling.
/// - Errors map once, in `fetch`: `URLError` → `.unreachable`, non-HTTP →
///   `.malformedResponse`, anything non-2xx → `.serverError`.
///
/// `@concurrent` on every implementation, matching the requirements, for the
/// reason `ExportService`/`MarketService` record; `requestProbe` is the seam
/// `WikimediaPhotoServiceTests` uses to prove the hop happened.
nonisolated final class WikimediaPhotoService: StockPhotoService {
    private let session: URLSession
    private let userAgent: String
    private let searchLimit: Int
    private let storageWidth: Int
    private let maxImageBytes: Int
    private let candidateCap: Int
    private let requestProbe: (@Sendable (_ isMainThread: Bool) -> Void)?

    init(
        session: URLSession = WikimediaPhotoService.sharedSession,
        userAgent: String = WikimediaAPI.userAgent(version: .current),
        searchLimit: Int = WikimediaAPI.searchLimit,
        storageWidth: Int = WikimediaAPI.storageWidth,
        maxImageBytes: Int = WikimediaAPI.maxImageBytes,
        candidateCap: Int = WikimediaAPI.candidateCap,
        requestProbe: (@Sendable (_ isMainThread: Bool) -> Void)? = nil
    ) {
        self.session = session
        self.userAgent = userAgent
        self.searchLimit = searchLimit
        self.storageWidth = storageWidth
        self.maxImageBytes = maxImageBytes
        self.candidateCap = candidateCap
        self.requestProbe = requestProbe
    }

    static let sharedSession: URLSession = makeSession()

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = WikimediaAPI.requestTimeout
        configuration.timeoutIntervalForResource = WikimediaAPI.resourceTimeout
        configuration.waitsForConnectivity = false
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return URLSession(configuration: configuration)
    }

    @concurrent func searchPhotos(named query: String) async throws -> [StockPhotoCandidate] {
        requestProbe?(Self.onMainThread())
        var components = URLComponents(url: WikimediaAPI.endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "\(searchLimit)"),
            URLQueryItem(name: "prop", value: "imageinfo|categories"),
            URLQueryItem(name: "iiprop", value: "url|extmetadata|mime"),
            URLQueryItem(name: "iiurlwidth", value: "\(storageWidth)"),
            URLQueryItem(name: "cllimit", value: "500"),
        ]
        guard let url = components.url else { throw StockPhotoError.malformedResponse }
        let data = try await fetch(url)
        return try WikimediaDecoding.candidates(from: data, query: query, cap: candidateCap)
    }

    @concurrent func imageData(from url: URL) async throws -> Data {
        requestProbe?(Self.onMainThread())
        // Host check FIRST — a URL outside Wikimedia is never fetched.
        guard WikimediaAPI.isWikimediaHost(url.host) else { throw StockPhotoError.malformedResponse }
        let data = try await fetch(url)
        if data.count > maxImageBytes { throw StockPhotoError.imageTooLarge }
        return data
    }

    /// The one place a request is sent and its response mapped (plan §2).
    private func fetch(_ url: URL) async throws -> Data {
        let request = WikimediaAPI.request(for: url, userAgent: userAgent)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw StockPhotoError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw StockPhotoError.malformedResponse }
        switch http.statusCode {
        case 200..<300: return data
        default: throw StockPhotoError.serverError(status: http.statusCode)
        }
    }

    private static func onMainThread() -> Bool { Thread.isMainThread }
}

// MARK: - Decoding

/// Wikimedia's `formatversion=2` shapes, read into the app's own types. The
/// licence filter and the author strip live here (spec §3), session-free so
/// `WikimediaDecodingTests` can run every fixture through it without a socket.
/// Mirrors `ReverbDecoding`.
nonisolated enum WikimediaDecoding {
    /// Decode the wire, keep only reusable-licensed files whose URLs parse,
    /// drop any file taken with the same gear the person searched, and return
    /// the first `cap` survivors (plan §2). A response with no `query` key
    /// decodes to an empty page list → `[]`.
    static func candidates(from data: Data, query: String, cap: Int) throws -> [StockPhotoCandidate] {
        let wire = try decode(SearchWire.self, from: data)
        var survivors: [StockPhotoCandidate] = []
        for page in wire.query?.pages ?? [] {
            guard let info = page.imageinfo?.first else { continue }
            let meta = info.extmetadata
            guard let licence = StockPhotoLicence.classify(
                shortName: meta?.licenseShortName?.value,
                license: meta?.license?.value
            ) else { continue }
            guard let sourceURL = info.descriptionurl.flatMap(URL.init(string:)),
                  let thumbURL = info.thumburl.flatMap(URL.init(string:)) else { continue }
            // Drop a photo taken with the same gear the person searched — a
            // photo *of* the gear outranks a snapshot taken *on* it (spec
            // Decision 7).
            let categoryTitles = (page.categories ?? []).map { $0.title }
            if isTakenWithSearchedGear(categoryTitles: categoryTitles, query: query) { continue }
            let attribution = StockPhotoAttribution(
                author: author(fromArtist: meta?.artist?.value),
                licenseName: licence.displayName,
                sourceURL: sourceURL
            )
            survivors.append(StockPhotoCandidate(
                id: page.pageid,
                title: page.title,
                thumbnailURL: thumbURL,
                storageURL: thumbURL,
                attribution: attribution
            ))
        }
        return Array(survivors.prefix(cap))
    }

    /// True iff a category marks this file as *taken with* the same gear the
    /// person searched — a photo of the gear is never "taken with" itself, so it
    /// survives; a snapshot taken on that camera is dropped. Matches on a shared
    /// **alphanumeric-fused** token — one carrying both a letter and a digit, a
    /// model designator like x2d/r5/100c/50mm/f2 — so brand-only overlap (both
    /// "canon") never drops, a bare number (24, 8) from a lens name never
    /// collides with an unrelated capture camera's model number ("iPhone 8"),
    /// and a query with no fused token (e.g. "Leica Summicron") drops nothing.
    /// Absent/truncated categories → false (keep — the safe direction: a missed
    /// drop only leaves a taken-with photo on screen; a wrong drop loses a real
    /// product shot).
    static func isTakenWithSearchedGear(categoryTitles: [String], query: String) -> Bool {
        let queryFusedTokens = Set(tokens(query).filter { t in
            t.contains(where: \.isNumber) && t.contains(where: \.isLetter)
        })
        guard !queryFusedTokens.isEmpty else { return false }
        for title in categoryTitles {
            let name = title.lowercased()
                .replacingOccurrences(of: "category:", with: "")   // titles arrive "Category:Taken with …"
            guard name.hasPrefix("taken with ") else { continue }
            let cameraTokens = Set(tokens(String(name.dropFirst("taken with ".count))))
            if !queryFusedTokens.isDisjoint(with: cameraTokens) { return true }
        }
        return false
    }

    /// Lowercased maximal alphanumeric runs: "Canon EOS-1D X" → [canon, eos, 1d, x].
    private static func tokens(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// The credited author for a file's `Artist` field: the tags stripped and
    /// entities decoded, or the "Wikimedia Commons" fallback (Q5) when the
    /// field is absent, empty, or one of Commons' *placeholders* for a file
    /// that names no author.
    static func author(fromArtist artist: String?) -> String {
        let stripped = artist.map { plainText(fromHTML: $0) } ?? ""
        guard !stripped.isEmpty, !isPlaceholderAuthor(stripped) else { return authorFallback }
        return stripped
    }

    /// What a file with no author is credited to (plan §3, Q5).
    static let authorFallback = "Wikimedia Commons"

    /// True for Commons' own "no author" placeholder, which arrives in the
    /// `Artist` field of a file with no structured author and reads, once the
    /// tags are stripped, "No machine-readable author provided. Elya assumed
    /// (based on copyright claims)." — a sentence *about the absence* of an
    /// author, where the name is the uploader who asserted the licence, not
    /// the photographer. Matched on the leading phrase, case-insensitively,
    /// because everything after it varies with the username; anything else is
    /// taken at face value (the safe direction: a missed placeholder credits
    /// the wrong words, a wrong match only falls back to "Wikimedia Commons").
    static func isPlaceholderAuthor(_ author: String) -> Bool {
        author.lowercased().hasPrefix("no machine-readable author provided")
    }

    /// Strip HTML tags, decode the common entities, collapse whitespace, trim.
    /// Kept simple and total — no `NSAttributedString` HTML importer, which is
    /// main-actor and heavy.
    static func plainText(fromHTML html: String) -> String {
        var out = ""
        var insideTag = false
        for character in html {
            switch character {
            case "<": insideTag = true
            case ">": insideTag = false
            default: if !insideTag { out.append(character) }
            }
        }
        out = decodeEntities(out)
        let parts = out.split(whereSeparator: \.isWhitespace)
        return parts.joined(separator: " ")
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&", let semicolon = text[index...].firstIndex(of: ";") else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            let entity = String(text[text.index(after: index)..<semicolon])
            if let decoded = decodeEntity(entity) {
                result.append(decoded)
            } else {
                result.append("&")
                result.append(entity)
                result.append(";")
            }
            index = text.index(after: semicolon)
        }
        return result
    }

    private static func decodeEntity(_ entity: String) -> Character? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos", "#39": return "'"
        default:
            if entity.hasPrefix("#"), let code = UInt32(entity.dropFirst()), let scalar = Unicode.Scalar(code) {
                return Character(scalar)
            }
            return nil
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw StockPhotoError.malformedResponse
        }
    }

    // The wire.

    private struct SearchWire: Decodable {
        let query: Query?
    }

    private struct Query: Decodable {
        let pages: [Page]
    }

    private struct Page: Decodable {
        let pageid: Int
        let title: String
        let imageinfo: [ImageInfo]?
        let categories: [Category]?          // absent when a file has none / truncated
    }

    private struct Category: Decodable {
        let title: String                    // e.g. "Category:Taken with Hasselblad X2D 100C"
    }

    private struct ImageInfo: Decodable {
        let url: String?
        let descriptionurl: String?
        let thumburl: String?
        let mime: String?
        let extmetadata: ExtMetadata?
    }

    /// Every extmetadata value keeps a `{"value": ...}` wrapper; any key may
    /// be absent.
    private struct ExtMetadata: Decodable {
        let licenseShortName: Wrapped?
        let license: Wrapped?
        let artist: Wrapped?
        enum CodingKeys: String, CodingKey {
            case licenseShortName = "LicenseShortName"
            case license = "License"
            case artist = "Artist"
        }
    }

    private struct Wrapped: Decodable {
        let value: String
    }
}
