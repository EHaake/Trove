import Foundation
import SwiftData
import Testing
@testable import Trove

/// The item form view model's stock-photo state and intents (spec 005, plan
/// §6). The form persists at its own `save()`, so `store(_:)` only mutates the
/// in-memory `photos` array — there is no second-context persistence claim to
/// check here (that lives on the detail side). The photo service is a spy —
/// nothing here opens a connection — and the notice flag is an in-memory fake,
/// never the device's.
@Suite("ItemFormViewModel — stock photo")
struct ItemFormPhotoTests {
    private let attribution = StockPhotoAttribution(
        author: "Ansel Adams",
        licenseName: "CC BY-SA 4.0",
        sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!
    )

    private func viewModel(
        notice: PhotoNoticeStoreFake = PhotoNoticeStoreFake()
    ) throws -> ItemFormViewModel {
        ItemFormViewModel(
            modelContext: try makeInMemoryContext(),
            photoService: StockPhotoServiceSpy(),
            noticeStore: notice
        )
    }

    // MARK: - The pick's landing (criterion 3, 6)

    @Test func aStoredPickLandsOneFetchedPhotoInPhotos() throws {
        let vm = try viewModel()

        vm.store(StockPhotoDownload(imageData: Data([0x01, 0x02]), attribution: attribution))

        #expect(vm.photos.filter { $0.source == .fetched }.count == 1)
        #expect(vm.photos.first { $0.source == .fetched }?.attribution == attribution)
        #expect(!vm.isFindingPhoto, "storing a pick left the sheet open")
        #expect(vm.photoSheetStep == .pick)
    }

    // MARK: - The notice, then the picker (criterion 1)

    @Test func findPhotoShowsTheNoticeFirstAndContinueHandsToThePicker() throws {
        let notice = PhotoNoticeStoreFake(acknowledged: false)
        let vm = try viewModel(notice: notice)

        vm.findPhoto()
        #expect(vm.photoSheetStep == .notice)
        #expect(vm.isFindingPhoto)

        vm.continuePhotoNotice()
        #expect(notice.hasAcknowledged, "Continue didn't acknowledge the notice")
        #expect(vm.photoSheetStep == .pick, "Continue didn't hand the sheet to the picker")
    }

    @Test func findPhotoGoesStraightToThePickerWhenAlreadyAcknowledged() throws {
        let vm = try viewModel(notice: PhotoNoticeStoreFake(acknowledged: true))

        vm.findPhoto()
        #expect(vm.photoSheetStep == .pick, "an acknowledged device still saw the notice")
        #expect(vm.isFindingPhoto)
    }

    @Test func declineLeavesTheFlagFalseAndClosesTheSheet() throws {
        let notice = PhotoNoticeStoreFake(acknowledged: false)
        let vm = try viewModel(notice: notice)

        vm.findPhoto()
        vm.declinePhotoNotice()
        #expect(!vm.isFindingPhoto, "Not now left the sheet open")
        #expect(!notice.hasAcknowledged, "Not now acknowledged the notice")
    }

    // MARK: - canFindPhoto follows the owned-photo rule (criterion 1)

    @Test func canFindPhotoFollowsTheOwnedPhotoRule() throws {
        let empty = try viewModel()
        #expect(empty.canFindPhoto, "a form with no photos should offer Find a photo…")

        let stockOnly = try viewModel()
        stockOnly.photos = [Photo.fetched(imageData: Data([0x01]), attribution: attribution, sortOrder: 0)]
        #expect(stockOnly.canFindPhoto, "a stock-only form should still offer Find a photo…")

        let owned = try viewModel()
        owned.photos = [Photo(imageData: Data([0x01]), source: .device)]
        #expect(!owned.canFindPhoto, "a form with an owned photo still offered Find a photo…")
    }
}
