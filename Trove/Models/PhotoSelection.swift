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

    /// Photos that were in `previous` and aren't in `current` — the ones a
    /// save has to *delete*, not merely unlink.
    ///
    /// SwiftData's `.cascade` fires when the parent is deleted; there is no
    /// orphan-removal rule for a child dropped from a to-many relationship.
    /// Reassigning `item.photos` therefore leaves the dropped `Photo` in the
    /// store with both inverses nil, still holding its
    /// `@Attribute(.externalStorage)` blob — which CloudKit uploads as a
    /// `CKAsset` and nothing ever collects. Invisible on screen, cumulative,
    /// and it syncs everywhere.
    ///
    /// Here rather than in each form so the two can't drift on it; both call
    /// it, and `PhotoRemovalTests` covers each path end to end.
    static func orphaned(previous: [Photo], current: [Photo]) -> [Photo] {
        let kept = Set(current.map(\.id))
        return previous.filter { !kept.contains($0.id) }
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

    /// Whether "Find a photo…" should be offered for this set (spec Decision 6).
    /// True iff no `.device` photo is present — a stock photo alone still offers
    /// it, to replace that stock photo. So an empty set and a stock-only set both
    /// qualify; any owned photo turns it off.
    static func canFindPhoto(_ photos: [Photo]) -> Bool {
        !photos.contains { $0.source == .device }
    }

    /// Adds a fetched stock photo to the set, keeping at most one (P5): any
    /// existing `.fetched` photo is dropped, and the new one is appended *after*
    /// all `.device` photos so owned photos lead (Decision 4a), then renumbered.
    /// The dropped fetched photo falls out of `current`, so `orphaned(...)`
    /// returns it for deletion and no blob is left behind.
    static func addingFetched(_ photo: Photo, to existing: [Photo]) -> [Photo] {
        let kept = inDisplayOrder(existing).filter { $0.source != .fetched }
        return renumbered(kept + [photo])
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
