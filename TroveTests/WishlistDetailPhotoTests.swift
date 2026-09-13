import Foundation
import SwiftData
import Testing
@testable import Trove

/// The wanted detail view model's stock-photo state and intents (spec 005,
/// plan §6) — the mirror of `ItemDetailPhotoTests`, checked to behave the same
/// as the owned side except for the one divergence: `WishlistItem` has no
/// `updatedAt` to bump (002 Decision 24). Every persistence claim is read on a
/// **second context**; the photo service is a spy and the notice flag an
/// in-memory fake.
@Suite("WishlistDetailViewModel — stock photo")
struct WishlistDetailPhotoTests {
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
        let item: WishlistItem
    }

    private func world(photos: [Photo] = []) throws -> World {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(item)
        for photo in photos { context.insert(photo) }
        if !photos.isEmpty { item.photos = photos }
        try context.save()
        return World(container: container, context: context, item: item)
    }

    private func viewModel(
        _ world: World,
        service: any StockPhotoService = StockPhotoServiceSpy(),
        notice: PhotoNoticeStoreFake = PhotoNoticeStoreFake()
    ) -> WishlistDetailViewModel {
        let vm = WishlistDetailViewModel(
            modelContext: world.context, itemID: world.item.id,
            photoService: service, noticeStore: notice)
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
        let vm = viewModel(world)

        #expect(vm.store(StockPhotoDownload(imageData: Data([0x01, 0x02]), attribution: attribution)))
        #expect(!world.context.hasChanges, "store left unsaved changes behind")

        let photos = try storedPhotos(in: world.container)
        #expect(photos.count == 1)
        let stored = try #require(photos.first)
        #expect(stored.source == .fetched)
        #expect(stored.attribution == attribution)
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

    @Test func aFailedDownloadStoresNothing() async throws {
        let world = try world()
        let vm = viewModel(world)

        let candidate = StockPhotoCandidate(
            id: 1, title: "Summicron 35mm f/2",
            thumbnailURL: URL(string: "https://upload.wikimedia.org/thumb.jpg")!,
            storageURL: URL(string: "https://upload.wikimedia.org/storage.jpg")!,
            attribution: attribution)
        let spy = StockPhotoServiceSpy(imageData: [.failure(.unreachable)])
        let fetchVM = PhotoFetchViewModel(seed: "Summicron 35mm f/2", service: spy)

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
