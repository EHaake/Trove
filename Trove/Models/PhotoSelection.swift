import Foundation

/// The list arithmetic behind `PhotoPickerField`, kept out of the view so it
/// can be tested. `PhotosPicker` itself can't be driven in the simulator
/// without a seeded photo library, so everything that *can* be checked without
/// it lives here.
///
/// The invariant throughout: `sortOrder` equals position, always. It's what
/// display order is derived from, so letting the two disagree would show
/// photos in an order the user didn't choose.
enum PhotoSelection {
    /// Newly picked images join the end of the existing set.
    static func appending(_ imageData: [Data], to existing: [Photo]) -> [Photo] {
        let added = imageData.map { Photo(imageData: $0, source: .device) }
        return renumbered(inDisplayOrder(existing) + added)
    }

    static func removing(_ photo: Photo, from existing: [Photo]) -> [Photo] {
        renumbered(inDisplayOrder(existing).filter { $0.id != photo.id })
    }

    /// Restates `sortOrder` as position. Called after every mutation rather
    /// than trusting whatever the previous numbering was — removing the middle
    /// photo of three would otherwise leave a gap at 1.
    static func renumbered(_ photos: [Photo]) -> [Photo] {
        for (index, photo) in photos.enumerated() {
            photo.sortOrder = index
        }
        return photos
    }

    /// Photos as the user should see them. The relationship comes back
    /// unordered from SwiftData, so display order is `sortOrder`, with `id`
    /// breaking ties to keep it stable if two ever collide.
    static func inDisplayOrder(_ photos: [Photo]) -> [Photo] {
        photos.sorted {
            $0.sortOrder != $1.sortOrder
                ? $0.sortOrder < $1.sortOrder
                : $0.id.uuidString < $1.id.uuidString
        }
    }
}
