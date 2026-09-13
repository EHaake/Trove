import Foundation
import Testing
@testable import Trove

/// The licence filter, the attribution strip, the cap, and the empty state —
/// run over the recorded fixtures with no session (the `ReverbDecodingTests`
/// idiom, spec §3).
@Suite("Wikimedia decoding")
struct WikimediaDecodingTests {

    // MARK: - The licence filter (G2)

    @Test func onlyReusableFilesSurviveTheMixedResponse() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-mixed-licences.json"), query: "", cap: 12
        )
        let titles = candidates.map(\.title)
        #expect(candidates.count == 4)
        #expect(titles.sorted() == [
            "File:Reusable-cc-by-sa.jpg",
            "File:Reusable-cc-by.jpg",
            "File:Reusable-cc0.jpg",
            "File:Reusable-pd.jpg",
        ])
        for title in titles {
            #expect(!title.contains("Nonfree"), "a non-reusable file was offered: \(title)")
        }
    }

    // MARK: - Attribution (G3)

    @Test func theAttributionIsStrippedOfHTMLAndCarriesTheLicenceAndSource() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-mixed-licences.json"), query: "", cap: 12
        )
        let ccBYSA = try #require(candidates.first { $0.title == "File:Reusable-cc-by-sa.jpg" })
        // The fixture's Artist is `<a href="…">Dave Example</a>` — the tag is
        // gone only if the strip ran.
        #expect(ccBYSA.attribution.author == "Dave Example")
        #expect(!ccBYSA.attribution.author.contains("<"))
        #expect(ccBYSA.attribution.licenseName == "CC BY-SA 4.0")
        #expect(ccBYSA.attribution.sourceURL.absoluteString == "https://commons.wikimedia.org/wiki/File:Reusable-cc-by-sa.jpg")
    }

    @Test func aFileWithNoArtistFallsBackToWikimediaCommons() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-no-author.json"), query: "", cap: 12
        )
        #expect(candidates.count == 1)
        #expect(candidates.first?.attribution.author == "Wikimedia Commons")
    }

    /// Commons' *placeholder* author — the `Artist` field of a file with no
    /// structured author, which reads "No machine-readable author provided.
    /// <user> assumed (based on copyright claims)." — is not an author, so it
    /// falls back to "Wikimedia Commons" like an absent field (T015 finding 2).
    /// Mutation: drop the `isPlaceholderAuthor` guard in `author(fromArtist:)`
    /// → the placeholder sentence is credited as the author → red.
    @Test func commonsPlaceholderAuthorFallsBackToWikimediaCommons() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-placeholder-author.json"), query: "", cap: 12
        )
        #expect(candidates.count == 1, "the file is still offered — only its author is unknown")
        let author = try #require(candidates.first?.attribution.author)
        #expect(author == "Wikimedia Commons")
        #expect(!author.lowercased().contains("machine-readable"), "Commons' placeholder is credited as the author")
    }

    /// The placeholder is recognised whatever the uploader's name and casing —
    /// only the leading phrase is fixed — and a real author is left alone.
    @Test func onlyTheLeadingPlaceholderPhraseIsTreatedAsNoAuthor() {
        #expect(WikimediaDecoding.isPlaceholderAuthor("No machine-readable author provided. Elya assumed (based on copyright claims)."))
        #expect(WikimediaDecoding.isPlaceholderAuthor("no MACHINE-READABLE author provided. Someone Else assumed."))
        #expect(!WikimediaDecoding.isPlaceholderAuthor("Henry S\u{00F6}derlund"))
        #expect(!WikimediaDecoding.isPlaceholderAuthor("Machine Readable Photography"))
    }

    // MARK: - The host filter (plan Q1)

    /// Image bytes only ever come from a Wikimedia host, and the picker's
    /// thumbnails fetch straight from the candidate's URL — so a candidate
    /// whose image URL is off-host never reaches the picker at all. The
    /// fixture holds one on-host file, one plainly foreign host, and one
    /// look-alike (`upload.wikimedia.org.evil.example`); only the first
    /// survives, and its licence and author are identical to the other two,
    /// so the host is the only thing that can be doing the dropping.
    ///
    /// Mutation: remove the `isWikimediaHost` guard in `candidates` → all
    /// three survive → red.
    @Test func onlyCandidatesServedFromAWikimediaHostSurvive() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-off-host.json"), query: "", cap: 12
        )
        #expect(candidates.count == 1)
        #expect(candidates.first?.title == "File:On-host-cc-by.jpg")
        for candidate in candidates {
            #expect(WikimediaAPI.isWikimediaHost(candidate.thumbnailURL.host))
            #expect(WikimediaAPI.isWikimediaHost(candidate.storageURL.host))
        }
    }

    // MARK: - The cap (G4)

    @Test func twentyReusableFilesAreCappedToTwelve() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-camera.json"), query: "", cap: 12
        )
        #expect(candidates.count == 12)
    }

    @Test func fewerReusableFilesThanTheCapAreAllReturned() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-mixed-licences.json"), query: "", cap: 12
        )
        #expect(candidates.count == 4)
    }

    // MARK: - Empty

    @Test func aResponseWithNoQueryIsAnEmptyList() throws {
        let candidates = try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-empty.json"), query: "", cap: 12
        )
        #expect(candidates.isEmpty)
    }

    // MARK: - The classifier table (G2)

    @Test func theClassifierAcceptsReusableAndRejectsTheRest() {
        // Reusable → non-nil, with the shortName as display.
        #expect(StockPhotoLicence.classify(shortName: "CC0", license: "cc0")?.displayName == "CC0")
        #expect(StockPhotoLicence.classify(shortName: "Public domain", license: "pd")?.displayName == "Public domain")
        #expect(StockPhotoLicence.classify(shortName: "CC BY 3.0", license: "cc-by-3.0")?.displayName == "CC BY 3.0")
        #expect(StockPhotoLicence.classify(shortName: "CC BY-SA 4.0", license: "cc-by-sa-4.0")?.displayName == "CC BY-SA 4.0")
        // Ported / jurisdiction versions stay reusable (two such files are in
        // the recorded search-camera fixture): code begins "cc-by" with no
        // "-nc"/"-nd", even with a country suffix.
        let ported = StockPhotoLicence.classify(shortName: "CC BY-SA 3.0 de", license: "cc-by-sa-3.0-de")
        #expect(ported != nil)
        #expect(ported == .ccBY(displayName: "CC BY-SA 3.0 de"))
        #expect(ported?.displayName == "CC BY-SA 3.0 de")
        // Rejected → nil.
        #expect(StockPhotoLicence.classify(shortName: "CC BY-NC 2.0", license: "cc-by-nc-2.0") == nil)
        #expect(StockPhotoLicence.classify(shortName: "CC BY-ND 2.0", license: "cc-by-nd-2.0") == nil)
        #expect(StockPhotoLicence.classify(shortName: "GFDL", license: "gfdl") == nil)
        #expect(StockPhotoLicence.classify(shortName: nil, license: nil) == nil)
        #expect(StockPhotoLicence.classify(shortName: "", license: "") == nil)
        // NC/ND anywhere in a compound code still fails.
        #expect(StockPhotoLicence.classify(shortName: "CC BY-NC-SA 3.0", license: "cc-by-nc-sa-3.0") == nil)
    }

    // MARK: - The HTML strip (G3)

    @Test func plainTextStripsTagsAndDecodesEntities() {
        #expect(WikimediaDecoding.plainText(fromHTML: "<a href=\"x\">Jane &amp; Co</a>") == "Jane & Co")
        #expect(WikimediaDecoding.plainText(fromHTML: "  <b>A</b>   &#39;B&#39;  ") == "A 'B'")
    }
}

/// A recorded Wikimedia fixture, read from the repo by path — mirrors
/// `reverbFixture`.
func wikimediaFixture(_ name: String, file: StaticString = #filePath) throws -> Data {
    let url = URL(filePath: "\(file)")
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Wikimedia")
        .appending(path: name)
    return try Data(contentsOf: url)
}
