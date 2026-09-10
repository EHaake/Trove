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

@Suite("PhotoSelection — replace / keep prompt")
struct PhotoSelectionReplaceKeepTests {
    private func device() -> Photo { Photo(imageData: data(9), source: .device) }

    // MARK: - shouldPromptReplaceOrKeep (Decision 4a)

    @Test func promptsWhenAddingToASetWithAStockPhoto() {
        #expect(PhotoSelection.shouldPromptReplaceOrKeep(addingCount: 1, to: [fetched(1)]))
    }

    @Test func doesNotPromptWithNoStockPhotoPresent() {
        #expect(!PhotoSelection.shouldPromptReplaceOrKeep(addingCount: 1, to: [device()]))
        #expect(!PhotoSelection.shouldPromptReplaceOrKeep(addingCount: 1, to: []))
    }

    @Test func doesNotPromptWhenThereIsNothingToAdd() {
        #expect(!PhotoSelection.shouldPromptReplaceOrKeep(addingCount: 0, to: [fetched(1)]))
    }

    // MARK: - Replace (addingReplacingStock)

    /// Replace drops the existing `.fetched` photo and keeps the new device
    /// one. **Mutation:** make `addingReplacingStock` not filter out the
    /// fetched photo → this goes red (two photos, one still `.fetched`).
    @Test func replaceLeavesExactlyOneDevicePhotoAndNoStock() {
        let result = PhotoSelection.addingReplacingStock([data(1)], to: [fetched(1)])

        #expect(result.count == 1)
        #expect(result.filter { $0.source == .device }.count == 1)
        #expect(!result.contains { $0.source == .fetched })
    }

    /// The dropped fetched photo flows through `orphaned(...)` for deletion, so
    /// no stored blob is left behind.
    @Test func theReplacedStockPhotoIsOrphaned() {
        let stock = fetched(1)
        let result = PhotoSelection.addingReplacingStock([data(1)], to: [stock])

        let orphans = PhotoSelection.orphaned(previous: [stock], current: result)
        #expect(orphans.contains { $0.id == stock.id })
    }

    // MARK: - Keep both (addingKeepingStock)

    /// Keep both keeps the stock photo and puts the owned photo first
    /// (Decision 4a). **Mutation:** reverse the ordering in `addingKeepingStock`
    /// (stock before device) → the device-leads assertion goes red.
    @Test func keepBothLeadsWithTheDevicePhotoAndTrailsWithTheStock() {
        let result = PhotoSelection.addingKeepingStock([data(1)], to: [fetched(1)])
        let ordered = PhotoSelection.inDisplayOrder(result)

        #expect(result.count == 2)
        #expect(ordered.first?.source == .device)
        #expect(ordered.last?.source == .fetched)
    }

    @Test func keepBothNumbersTheResultFromZero() {
        let result = PhotoSelection.addingKeepingStock([data(1)], to: [fetched(1)])
        #expect(PhotoSelection.inDisplayOrder(result).map(\.sortOrder) == Array(0..<result.count))
    }
}

@Suite("PhotoSelection — leadsWithStock")
struct PhotoSelectionLeadsWithStockTests {
    private func device(sortOrder: Int = 0) -> Photo {
        Photo(imageData: data(9), source: .device, sortOrder: sortOrder)
    }

    /// A stock-only set leads with stock — the row shows the stock thumbnail.
    @Test func trueForAStockOnlySet() {
        #expect(PhotoSelection.leadsWithStock([fetched(1)]))
    }

    /// An empty set leads with nothing.
    @Test func falseForAnEmptySet() {
        #expect(!PhotoSelection.leadsWithStock([]))
    }

    /// An owned photo leading turns the mark off even with a stock photo present
    /// (Decision 4a). Passed out of array order — device `sortOrder` 0 sits
    /// *second* in the array, fetched `sortOrder` 1 sits first — to prove the
    /// predicate sorts by `sortOrder`, not array position.
    /// **Mutation:** change `leadsWithStock` to `photos.contains { $0.source ==
    /// .fetched }` → this goes true → red.
    @Test func falseWhenAnOwnedPhotoLeadsEvenWithAStockPhotoPresent() {
        let owned = device(sortOrder: 0)
        let stock = fetched(2, sortOrder: 1)

        #expect(!PhotoSelection.leadsWithStock([stock, owned]))
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
