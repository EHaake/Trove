import Foundation
import Testing
@testable import Trove

/// Every recorded fixture through the real decoder, and the shape guard
/// spec P14 rests on (plan §9, G10).
@Suite("Reverb decoding")
struct ReverbDecodingTests {
    @Test func theSearchYieldsThreeCandidatesWithTheTelecasterFirst() throws {
        let candidates = try ReverbDecoding.candidates(from: try reverbFixture("csps-search-telecaster.json"))

        try #require(candidates.count == 3)
        let first = try #require(candidates.first)
        #expect(first.id == 126_161)
        #expect(first.slug == "fender-american-professional-ii-telecaster")
        #expect(first.title == "Fender American Professional II Telecaster")
        #expect(first.brand == "Fender")
        #expect(first.imageURL?.host == "rvb-img.reverb.com")
        #expect((first.usedLowCents ?? 0) > 0)
        #expect(first.usedTotal > 0)
    }

    @Test func theProductCarriesItsListingsLinkOnReverbsHost() throws {
        let product = try ReverbDecoding.product(from: try reverbFixture("csp-126161.json"))

        #expect(product.id == 126_161)
        #expect(product.slug == "fender-american-professional-ii-telecaster")
        #expect(product.listingsURL.host == ReverbAPI.host)
        #expect(product.listingsURL.query?.contains("cp_ids") == true)
        #expect(product.usedTotal == 108)
        #expect(product.usedLowCents == 100_000)
    }

    @Test func aProductWithoutAListingsLinkIsMalformed() {
        let body = Data(#"{"id": 1, "slug": "x", "title": "X", "_links": {"web": {"href": "https://reverb.com/p/x"}}}"#.utf8)
        #expect(throws: MarketError.malformedResponse) {
            _ = try ReverbDecoding.product(from: body)
        }
    }

    @Test func theSevenPagesLinkForwardUntilTheLast() throws {
        var counts: [Int] = []
        for page in 1...7 {
            let decoded = try ReverbDecoding.page(from: try reverbFixture("listings-126161-p\(page).json"))
            counts.append(decoded.listings.count)
            #expect(decoded.total == 337)
            if page < 7 {
                #expect(decoded.next?.host == ReverbAPI.host, "page \(page) has no next")
            } else {
                #expect(decoded.next == nil, "the last page still points on")
            }
        }
        #expect(counts == [50, 50, 50, 50, 50, 50, 37])
    }

    @Test func theMixedPageDropsWhatCannotCountAndMarksADisagreeingCurrency() throws {
        let page = try ReverbDecoding.page(from: try reverbFixture("listings-mixed.json"))

        // Seven raw: the no-price and the no-condition listings are dropped.
        #expect(page.listings.count == 5)
        let currencies = page.listings.map(\.currency)
        #expect(currencies.contains("USD"))
        #expect(currencies.contains("EUR"))
        #expect(currencies.contains("GBP≠USD"), "a converted price counts for no currency: \(currencies)")
        #expect(currencies.contains("?≠USD"), "a missing listing_currency is unknown, never USD: \(currencies)")
        #expect(page.listings.map(\.conditionSlug).contains("player-grade"), "an unknown slug is the computation's to judge, not the decoder's")
    }

    @Test func aYearIsTrimmedAndBlankBecomesNil() throws {
        let body = Data(#"{"listings": [{"price": {"amount_cents": 1, "currency": "USD"}, "listing_currency": "USD", "condition": {"slug": "good"}, "year": "1979 "}, {"price": {"amount_cents": 1, "currency": "USD"}, "listing_currency": "USD", "condition": {"slug": "good"}, "year": ""}], "total": 2}"#.utf8)
        let page = try ReverbDecoding.page(from: body)
        #expect(page.listings.map(\.year) == ["1979", nil])
    }

    /// G10 — spec P14 by construction: the listing type has exactly these
    /// four members, and a page decoded from a fixture that *does* carry
    /// titles keeps no string other than a currency, a slug or a year.
    @Test func aListingIsFourMembersAndKeepsNoListingText() throws {
        let sample = MarketListing(priceCents: 1, currency: "USD", conditionSlug: "good", year: nil)
        let members = Mirror(reflecting: sample).children.compactMap(\.label)
        #expect(members == ["priceCents", "currency", "conditionSlug", "year"])

        let page = try ReverbDecoding.page(from: try reverbFixture("listings-126161-p1.json"))
        let allowedStrings: Set<String> = ["currency", "conditionSlug", "year"]
        for listing in page.listings {
            for child in Mirror(reflecting: listing).children {
                let isString = child.value is String || child.value is String?
                if isString, let label = child.label {
                    #expect(allowedStrings.contains(label), "a string member the app never asked for: \(label)")
                }
            }
        }
    }
}

/// A recorded Reverb fixture, read from the repo by path — the
/// `DocsSampleTests` idiom, no bundle resource lookup.
func reverbFixture(_ name: String, file: StaticString = #filePath) throws -> Data {
    let url = URL(filePath: "\(file)")
        .deletingLastPathComponent()
        .appending(path: "Fixtures/Reverb")
        .appending(path: name)
    return try Data(contentsOf: url)
}
