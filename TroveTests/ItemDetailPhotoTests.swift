import Foundation
import SwiftData
import Testing
@testable import Trove

/// The owned detail view model's stock-photo state and intents (spec 005,
/// plan §6). Every persistence claim is read on a **second context**, since a
/// same-context refetch hands back unsaved changes and would pass whether or
/// not the intent saved. The photo service is a spy — nothing here opens a
/// connection — and the notice flag is an in-memory fake, never the device's.
@Suite("ItemDetailViewModel — stock photo")
struct ItemDetailPhotoTests {
    private let attribution = StockPhotoAttribution(
        author: "Ansel Adams",
        licenseName: "CC BY-SA 4.0",
        sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!
    )

    private func attribution2() -> StockPhotoAttribution {
        StockPhotoAttribution(
            author: "Dorothea Lange",
            licenseName: "Public domain",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Other.jpg")!
        )
    }

    private struct World {
        let container: ModelContainer
        let context: ModelContext
        let item: Item
    }

    private func world(photos: [Photo] = []) throws -> World {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(item)
        for photo in photos { context.insert(photo) }
        if !photos.isEmpty { item.photos = photos }
        try context.save()
        return World(container: container, context: context, item: item)
    }

    private func viewModel(
        _ world: World,
        service: any StockPhotoService = StockPhotoServiceSpy(),
        notice: PhotoNoticeStoreFake = PhotoNoticeStoreFake(),
        now: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> ItemDetailViewModel {
        let vm = ItemDetailViewModel(
            modelContext: world.context, itemID: world.item.id,
            photoService: service, noticeStore: notice, now: { now })
        vm.load()
        return vm
    }

    private func storedPhotos(in container: ModelContainer) throws -> [Photo] {
        let read = ModelContext(container)
        return try read.fetch(FetchDescriptor<Photo>())
    }

    // MARK: - The notice, then the picker (criterion 1)

    @Test func findPhotoShowsTheNoticeFirstAndContinueHandsToThePicker() throws {
        let world = try world()
        let notice = PhotoNoticeStoreFake(acknowledged: false)
        let vm = viewModel(world, notice: notice)

        vm.findPhoto()
        #expect(vm.photoSheetStep == .notice)
        #expect(vm.isFindingPhoto)

        vm.continuePhotoNotice()
        #expect(notice.hasAcknowledged, "Continue didn't acknowledge the notice")
        #expect(vm.photoSheetStep == .pick, "Continue didn't hand the sheet to the picker")
    }

    @Test func findPhotoGoesStraightToThePickerWhenAlreadyAcknowledged() throws {
        let world = try world()
        let vm = viewModel(world, notice: PhotoNoticeStoreFake(acknowledged: true))

        vm.findPhoto()
        #expect(vm.photoSheetStep == .pick, "an acknowledged device still saw the notice")
        #expect(vm.isFindingPhoto)
    }

    @Test func declineLeavesTheFlagFalseAndClosesTheSheet() throws {
        let world = try world()
        let notice = PhotoNoticeStoreFake(acknowledged: false)
        let vm = viewModel(world, notice: notice)

        vm.findPhoto()
        vm.declinePhotoNotice()
        #expect(!vm.isFindingPhoto, "Not now left the sheet open")
        #expect(!notice.hasAcknowledged, "Not now acknowledged the notice")
    }

    // MARK: - The pick's landing (criterion 3, 6)

    @Test func aStoredPickLandsOneFetchedPhotoOnASecondContext() throws {
        let world = try world()
        let bump = Date(timeIntervalSince1970: 1_900_000_000)
        let before = world.item.updatedAt
        let vm = viewModel(world, now: bump)

        #expect(vm.store(StockPhotoDownload(imageData: Data([0x01, 0x02]), attribution: attribution)))
        #expect(!world.context.hasChanges, "store left unsaved changes behind")

        let photos = try storedPhotos(in: world.container)
        #expect(photos.count == 1)
        let stored = try #require(photos.first)
        #expect(stored.source == .fetched)
        #expect(stored.attribution == attribution)

        // OWNED ONLY: storing a stock photo marks the item edited (spec P6).
        let read = ModelContext(world.container)
        let id = world.item.id
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let reloaded = try #require(try read.fetch(descriptor).first)
        #expect(reloaded.updatedAt == bump, "storing a photo didn't mark the owned item edited")
        #expect(reloaded.updatedAt != before)
    }

    /// Criterion 6: at most one fetched photo — a second pick replaces the
    /// first, and the replaced blob is deleted, not leaked, on a second
    /// context. **Mutation target:** skip the orphan delete in `store` → the
    /// second context shows two `Photo` rows → red.
    @Test func storingASecondStockPhotoReplacesTheFirstWithNoLeakedBlob() throws {
        let world = try world()
        let vm = viewModel(world)

        #expect(vm.store(StockPhotoDownload(imageData: Data([0x01]), attribution: attribution)))
        #expect(vm.store(StockPhotoDownload(imageData: Data([0x02]), attribution: attribution2())))

        let photos = try storedPhotos(in: world.container)
        #expect(photos.count == 1, "a replaced stock photo leaked a second row")
        #expect(photos.first?.attribution == attribution2(), "the newest stock photo isn't the one kept")
    }

    // MARK: - A failed download stores nothing (criterion 7)

    /// The sheet only calls `store` on a non-nil download, so a failed fetch
    /// stores nothing. **Mutation target:** make `PhotoFetchViewModel.download`
    /// return a `StockPhotoDownload` even on `.failure` → a photo gets stored
    /// → red.
    @Test func aFailedDownloadStoresNothing() async throws {
        let world = try world()
        let vm = viewModel(world)

        let candidate = StockPhotoCandidate(
            id: 1, title: "Leica M6",
            thumbnailURL: URL(string: "https://upload.wikimedia.org/thumb.jpg")!,
            storageURL: URL(string: "https://upload.wikimedia.org/storage.jpg")!,
            attribution: attribution)
        let spy = StockPhotoServiceSpy(imageData: [.failure(.unreachable)])
        let fetchVM = PhotoFetchViewModel(seed: "Leica M6", service: spy)

        // Exactly the sheet's cell path: download, and store only on success.
        let download = await fetchVM.download(candidate)
        #expect(download == nil, "a failed download handed back bytes")
        if let download { vm.store(download) }

        #expect(try storedPhotos(in: world.container).isEmpty, "a failed download stored a photo")
    }

    // MARK: - canFindPhoto follows the owned-photo rule (criterion 1)

    @Test func canFindPhotoFollowsTheOwnedPhotoRule() throws {
        let empty = viewModel(try world())
        #expect(empty.canFindPhoto, "an item with no photos should offer Find a photo…")

        let stockOnly = viewModel(try world(photos: [
            Photo.fetched(imageData: Data([0x01]), attribution: attribution, sortOrder: 0)
        ]))
        #expect(stockOnly.canFindPhoto, "a stock-only item should still offer Find a photo…")

        let owned = viewModel(try world(photos: [Photo(imageData: Data([0x01]), source: .device)]))
        #expect(!owned.canFindPhoto, "an item with an owned photo still offered Find a photo…")
    }
}
