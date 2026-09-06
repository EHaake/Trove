import Foundation
import SwiftData
import Testing
@testable import Trove

/// Spec criterion 18, made falsifiable (plan §9, G5′): after a real refresh
/// against the recorded fixtures, the bytes of the two store files hold
/// none of the listings' text — the fixtures keep every listing's title
/// precisely so this scan has something to look for — while the product's
/// catalog title sits in the local file and nowhere in the collection.
///
/// Real disk I/O on purpose, the narrow exception `CloudKitSchemaTests`
/// records: a byte scan needs bytes.
@Suite("Market persisted content")
struct MarketPersistedContentTests {
    @Test func aRefreshLeavesNoListingTextInEitherStoreFile() async throws {
        let directory = URL.temporaryDirectory.appending(path: "persisted-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // What the listings say, straight from the raw fixture: every title.
        var titles: [String] = []
        for page in 1...7 {
            let json = try JSONSerialization.jsonObject(with: try reverbFixture("listings-126161-p\(page).json")) as? [String: Any]
            for listing in json?["listings"] as? [[String: Any]] ?? [] {
                if let title = listing["title"] as? String, title.count >= 12 { titles.append(title) }
            }
        }
        var all: [MarketListing] = []
        for page in 1...7 { all += try ReverbDecoding.page(from: try reverbFixture("listings-126161-p\(page).json")).listings }
        let product = try ReverbDecoding.product(from: try reverbFixture("csp-126161.json"))
        // A listing titled with the catalog's own name would be found in the
        // local store *because the catalog title is there* (Decision 20) —
        // not evidence of a listing leaking. Scan for the rest.
        titles.removeAll { product.title.contains($0) }
        try #require(titles.count > 250, "the fixture lost its titles — the scan would look for nothing")
        let spy = MarketServiceSpy(products: [.success(product)], listings: [.success(MarketListings(listings: all, reportedTotal: 337, isTruncated: false))])

        do {
            let container = try TroveStore.buildContainer(TroveStore.configurations(for: .localOnly, directory: directory))
            let context = ModelContext(container)
            let item = Item(name: "Telecaster", condition: .excellent, reverbProductID: 126_161)
            context.insert(item)
            try context.save()

            let refresher = MarketRefresher(modelContext: context, service: spy, now: Date.init)
            let outcome = await refresher.refresh(MarketRefreshTarget(key: MarketSubjectKey(subjectID: item.id, kind: .owned), productID: 126_161, subject: .owned(condition: .excellent), year: nil))
            guard case .refreshed(.figure) = outcome else { throw TestFailure("\(outcome)") }
        }

        // SQLite may still hold the rows in the write-ahead log, so the scan
        // covers the store and its sidecars together.
        func bytes(of name: String) throws -> Data {
            var data = Data()
            for suffix in ["", "-wal", "-shm"] {
                let url = directory.appending(path: name + suffix)
                if FileManager.default.fileExists(atPath: url.path) { data += try Data(contentsOf: url) }
            }
            return data
        }
        let collection = try bytes(of: "default.store")
        let local = try bytes(of: "MarketLocal.store")
        try #require(!collection.isEmpty && !local.isEmpty)

        let productTitle = Data(product.title.utf8)
        #expect(local.range(of: productTitle) != nil, "the catalog title should be in the local store (Decision 20)")
        #expect(collection.range(of: productTitle) == nil, "the catalog title reached the synced collection")
        #expect(collection.range(of: Data("Telecaster".utf8)) != nil, "the item's own name should be in the collection — else this scan reads nothing")

        var leaked: [String] = []
        for title in titles {
            let needle = Data(title.utf8)
            if local.range(of: needle) != nil || collection.range(of: needle) != nil { leaked.append(title) }
        }
        #expect(leaked.isEmpty, "listing text reached a store file: \(leaked.prefix(3))")
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
