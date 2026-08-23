import Foundation
import Testing
@testable import Trove

private func data(_ byte: UInt8) -> Data { Data([byte]) }

@Suite("PhotoSelection — appending")
struct PhotoSelectionAppendTests {
    @Test func appendingToAnEmptySelectionNumbersFromZero() {
        let photos = PhotoSelection.appending([data(1), data(2), data(3)], to: [])

        #expect(photos.map(\.sortOrder) == [0, 1, 2])
        #expect(photos.map(\.imageData) == [data(1), data(2), data(3)])
    }

    @Test func appendingContinuesAfterExistingPhotos() {
        let existing = PhotoSelection.appending([data(1), data(2)], to: [])
        let photos = PhotoSelection.appending([data(3)], to: existing)

        #expect(photos.count == 3)
        #expect(photos.map(\.sortOrder) == [0, 1, 2])
        #expect(photos.last?.imageData == data(3))
    }

    @Test func appendingLeavesExistingPhotosInPlace() {
        let existing = PhotoSelection.appending([data(1), data(2)], to: [])
        let photos = PhotoSelection.appending([data(3)], to: existing)

        #expect(photos.prefix(2).map(\.imageData) == [data(1), data(2)])
    }

    /// v1 only ever writes device photos — see spec.md's stock-photo non-goal.
    @Test func newPhotosAreMarkedAsComingFromTheDevice() {
        let photos = PhotoSelection.appending([data(1)], to: [])

        #expect(photos.allSatisfy { $0.source == .device })
    }

    @Test func appendingNothingLeavesTheSelectionUnchanged() {
        let existing = PhotoSelection.appending([data(1), data(2)], to: [])
        let photos = PhotoSelection.appending([], to: existing)

        #expect(photos.map(\.imageData) == [data(1), data(2)])
        #expect(photos.map(\.sortOrder) == [0, 1])
    }

    /// Appending to an out-of-order selection has to sort first, or the new
    /// photo's number collides with an existing one.
    @Test func appendingNormalisesAnOutOfOrderSelection() {
        let first = Photo(imageData: data(1), sortOrder: 7)
        let second = Photo(imageData: data(2), sortOrder: 3)

        let photos = PhotoSelection.appending([data(3)], to: [first, second])

        #expect(photos.map(\.sortOrder) == [0, 1, 2])
        #expect(photos.map(\.imageData) == [data(2), data(1), data(3)])
    }
}

@Suite("PhotoSelection — removing")
struct PhotoSelectionRemoveTests {
    @Test func removingTakesThePhotoOut() {
        let photos = PhotoSelection.appending([data(1), data(2), data(3)], to: [])
        let remaining = PhotoSelection.removing(photos[1], from: photos)

        #expect(remaining.count == 2)
        #expect(remaining.map(\.imageData) == [data(1), data(3)])
    }

    /// Removing from the middle must close the gap, or display order and
    /// `sortOrder` drift apart.
    @Test func removingFromTheMiddleRenumbersWithoutAGap() {
        let photos = PhotoSelection.appending([data(1), data(2), data(3)], to: [])
        let remaining = PhotoSelection.removing(photos[1], from: photos)

        #expect(remaining.map(\.sortOrder) == [0, 1])
    }

    @Test func removingTheOnlyPhotoEmptiesTheSelection() {
        let photos = PhotoSelection.appending([data(1)], to: [])

        #expect(PhotoSelection.removing(photos[0], from: photos).isEmpty)
    }

    @Test func removingAPhotoThatIsNotThereChangesNothing() {
        let photos = PhotoSelection.appending([data(1), data(2)], to: [])
        let stranger = Photo(imageData: data(9))

        let remaining = PhotoSelection.removing(stranger, from: photos)

        #expect(remaining.count == 2)
        #expect(remaining.map(\.sortOrder) == [0, 1])
    }

    @Test func removingThenAppendingKeepsNumberingContiguous() {
        let photos = PhotoSelection.appending([data(1), data(2), data(3)], to: [])
        let afterRemoval = PhotoSelection.removing(photos[0], from: photos)
        let afterAppend = PhotoSelection.appending([data(4)], to: afterRemoval)

        #expect(afterAppend.map(\.sortOrder) == [0, 1, 2])
        #expect(afterAppend.map(\.imageData) == [data(2), data(3), data(4)])
    }
}

@Suite("PhotoSelection — display order")
struct PhotoSelectionOrderTests {
    /// SwiftData hands relationships back unordered, so display order comes
    /// from `sortOrder` rather than from however the array arrived.
    @Test func ordersBySortOrderRatherThanArrayOrder() {
        let third = Photo(imageData: data(3), sortOrder: 2)
        let first = Photo(imageData: data(1), sortOrder: 0)
        let second = Photo(imageData: data(2), sortOrder: 1)

        let ordered = PhotoSelection.inDisplayOrder([third, first, second])

        #expect(ordered.map(\.imageData) == [data(1), data(2), data(3)])
    }

    /// Duplicate `sortOrder` shouldn't leave the order down to chance.
    @Test func breaksTiesDeterministically() {
        let a = Photo(imageData: data(1), sortOrder: 0)
        let b = Photo(imageData: data(2), sortOrder: 0)

        let forwards = PhotoSelection.inDisplayOrder([a, b]).map(\.id)
        let backwards = PhotoSelection.inDisplayOrder([b, a]).map(\.id)

        #expect(forwards == backwards)
    }

    @Test func orderingNothingYieldsNothing() {
        #expect(PhotoSelection.inDisplayOrder([]).isEmpty)
    }

    @Test func renumberingRewritesSortOrderToPosition() {
        let photos = [
            Photo(imageData: data(1), sortOrder: 40),
            Photo(imageData: data(2), sortOrder: 41),
        ]

        #expect(PhotoSelection.renumbered(photos).map(\.sortOrder) == [0, 1])
    }
}
