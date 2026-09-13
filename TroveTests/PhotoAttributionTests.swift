import Foundation
import SwiftData
import Testing
@testable import Trove

/// Guards the two-way attribution mapping added for stock photos (spec 005,
/// T001): a `.device` photo has no credit, and a `.fetched` photo's author,
/// licence, and source URL survive a real persistence round-trip and rebuild
/// into the same `StockPhotoAttribution`.
///
/// The round-trip fetches through a *second* `ModelContext` on the same
/// container so the assertion proves the values reached the store, not that
/// they're still held on the object that wrote them (`CLAUDE.md`: a
/// same-context refetch hands back unsaved changes).
@Suite("Photo attribution — stock-photo credit mapping")
struct PhotoAttributionTests {
    @Test func aDevicePhotoHasNoAttribution() throws {
        let photo = Photo(imageData: Data([0x01]), source: .device)
        #expect(photo.attribution == nil)
    }

    @Test func theFetchedBuilderSetsSourceToFetched() throws {
        let photo = Photo.fetched(
            imageData: Data([0x01]),
            attribution: StockPhotoAttribution(
                author: "Ansel Adams",
                licenseName: "CC BY-SA 4.0",
                sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!),
            sortOrder: 0)
        #expect(photo.source == .fetched)
    }

    /// The defensive read path in `attribution` (T001): a `.fetched` row whose
    /// stored author is nil — which `fetched(...)` never writes, but a row
    /// arriving from CloudKit with a field missing could be — still yields a
    /// credit, with the "Wikimedia Commons" fallback (spec P4, plan §1).
    ///
    /// Mutation: change the fallback string in `Photo.attribution` → red.
    @Test func aFetchedPhotoWithNoStoredAuthorIsCreditedToWikimediaCommons() throws {
        let photo = Photo(imageData: Data([0x01]), source: .fetched)
        photo.attributionLicense = "CC BY-SA 4.0"
        photo.attributionSourceURL = "https://commons.wikimedia.org/wiki/File:Example.jpg"

        let attribution = try #require(photo.attribution)
        #expect(attribution.author == "Wikimedia Commons")
        #expect(attribution.licenseName == "CC BY-SA 4.0")
    }

    /// The other defensive branch: a stored source URL that is nil, or a
    /// string `URL(string:)` refuses, still links somewhere real — Commons'
    /// main page — rather than dropping the credit's link.
    ///
    /// Mutation: change the fallback URL in `Photo.attribution` → red.
    @Test func aFetchedPhotoWithNoUsableStoredSourceURLLinksToCommons() throws {
        let missing = Photo(imageData: Data([0x01]), source: .fetched)
        missing.attributionAuthor = "Ansel Adams"
        missing.attributionLicense = "CC BY-SA 4.0"
        missing.attributionSourceURL = nil

        let unparseable = Photo(imageData: Data([0x02]), source: .fetched)
        unparseable.attributionAuthor = "Ansel Adams"
        unparseable.attributionLicense = "CC BY-SA 4.0"
        unparseable.attributionSourceURL = ""    // `URL(string: "")` is nil

        for photo in [missing, unparseable] {
            let attribution = try #require(photo.attribution)
            #expect(attribution.sourceURL.absoluteString == "https://commons.wikimedia.org")
            #expect(attribution.author == "Ansel Adams")
        }
    }

    @Test func aFetchedPhotoRoundTripsItsAttributionThroughASecondContext() throws {
        let container = try makeInMemoryContainer()
        let writeContext = ModelContext(container)

        let attribution = StockPhotoAttribution(
            author: "Ansel Adams",
            licenseName: "CC BY-SA 4.0",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!)
        let photo = Photo.fetched(
            imageData: Data([0x01]), attribution: attribution, sortOrder: 0)
        writeContext.insert(photo)
        try writeContext.save()

        let readContext = ModelContext(container)
        let fetched = try #require(try readContext.fetch(FetchDescriptor<Photo>()).first)

        #expect(fetched.source == .fetched)
        #expect(fetched.attributionAuthor == "Ansel Adams")
        #expect(fetched.attributionLicense == "CC BY-SA 4.0")
        #expect(fetched.attributionSourceURL
            == "https://commons.wikimedia.org/wiki/File:Example.jpg")

        let rebuilt = try #require(fetched.attribution)
        #expect(rebuilt == attribution)
    }
}
