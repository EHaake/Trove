import Foundation
import Testing
@testable import Trove

private func data(_ byte: UInt8) -> Data { Data([byte]) }

private func attribution(_ author: String = "A") -> StockPhotoAttribution {
    StockPhotoAttribution(
        author: author,
        licenseName: "CC BY-SA 4.0",
        sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:\(author).jpg")!
    )
}

private func fetched(_ byte: UInt8, sortOrder: Int = 0) -> Photo {
    Photo.fetched(imageData: data(byte), attribution: attribution("A\(byte)"), sortOrder: sortOrder)
}

@Suite("PhotoSelection — canFindPhoto")
struct PhotoSelectionCanFindPhotoTests {
    /// An owned photo turns the offer off — the item already has its own photo.
    @Test func falseWhenADevicePhotoIsPresent() {
        let photos = PhotoSelection.appending([data(1)], to: [])

        #expect(PhotoSelection.canFindPhoto(photos) == false)
    }

    @Test func trueForAnEmptySet() {
        #expect(PhotoSelection.canFindPhoto([]) == true)
    }

    /// A stock photo alone still offers Find a photo… — to replace it
    /// (spec Decision 6).
    @Test func trueForAStockOnlySet() {
        #expect(PhotoSelection.canFindPhoto([fetched(1)]) == true)
    }
}

@Suite("PhotoSelection — addingFetched")
struct PhotoSelectionAddingFetchedTests {
    /// At most one `.fetched` photo (P5): a second fetch replaces the first.
    /// Mutation — skipping the `.fetched` removal in `addingFetched` — leaves
    /// two fetched photos and turns this red.
    @Test func keepsAtMostOneFetchedPhoto() {
        let first = fetched(1)
        let withFirst = PhotoSelection.addingFetched(first, to: [])

        let second = fetched(2)
        let result = PhotoSelection.addingFetched(second, to: withFirst)

        #expect(result.filter { $0.source == .fetched }.count == 1)
        #expect(result.contains { $0.imageData == data(2) })
        #expect(!result.contains { $0.imageData == data(1) })
    }

    /// Owned photos lead (Decision 4a): the fetched photo lands after every
    /// `.device` photo. Mutation — appending the fetched before the device
    /// photos — turns this red.
    @Test func ownedPhotosLeadTheFetchedOne() {
        let devicePhoto = PhotoSelection.appending([data(1)], to: [])[0]

        let result = PhotoSelection.addingFetched(fetched(2), to: [devicePhoto])
        let ordered = PhotoSelection.inDisplayOrder(result)

        #expect(ordered.first?.source == .device)
        #expect(ordered.last?.source == .fetched)
    }

    /// The replaced fetched photo flows through `orphaned(...)` for deletion,
    /// so no stored blob is left behind (P5).
    @Test func theReplacedFetchedPhotoIsOrphaned() {
        let f1 = fetched(1)
        let existing = PhotoSelection.addingFetched(f1, to: [])

        let f2 = fetched(2)
        let result = PhotoSelection.addingFetched(f2, to: existing)

        let orphans = PhotoSelection.orphaned(previous: existing, current: result)
        #expect(orphans.contains { $0.id == f1.id })
    }

    @Test func numbersTheResultFromZero() {
        let devicePhotos = PhotoSelection.appending([data(1), data(2)], to: [])

        let result = PhotoSelection.addingFetched(fetched(3), to: devicePhotos)

        #expect(result.map(\.sortOrder) == Array(0..<result.count))
    }
}

@Suite("StockPhotoServiceSpy")
struct StockPhotoServiceSpyTests {
    @Test func anExhaustedScriptThrowsScriptExhausted() async {
        let spy = StockPhotoServiceSpy()

        await #expect(throws: StockPhotoServiceSpy.ScriptExhausted.self) {
            _ = try await spy.searchPhotos(named: "canon")
        }
        #expect(spy.calls == [.search("canon")])
    }
}
