import Foundation
import SwiftData

/// Where a photo came from.
///
/// v1 only ever writes `.device` — there is no stock-photo fetching yet (see
/// spec.md non-goals). `.fetched` exists now because the field is cheap to add
/// today and expensive to retrofit once real photos exist in CloudKit, so a
/// future fetch feature becomes a UI/network addition rather than a schema
/// migration.
enum PhotoSource: String, Codable, CaseIterable {
    case device
    case fetched
}

@Model
final class Photo {
    var id: UUID = UUID()

    /// `.externalStorage` keeps the blob out of the main store file and hands it
    /// to CloudKit as a `CKAsset` instead of inlining it — otherwise photos
    /// bloat both the local SQLite store and the sync payload.
    @Attribute(.externalStorage) var imageData: Data = Data()

    /// Backing store for ``source``. Persisted as a raw `String`; use `source`
    /// everywhere except in `FetchDescriptor` predicates and sort descriptors,
    /// which can only see stored properties.
    var sourceRawValue: String = PhotoSource.device.rawValue

    var sortOrder: Int = 0

    // The `item` back-reference to `Item` lands in T007, along with the `Item`
    // type it refers to and the `@Relationship(inverse:)` declaration there.

    var source: PhotoSource {
        get { PhotoSource(rawValue: sourceRawValue) ?? .device }
        set { sourceRawValue = newValue.rawValue }
    }

    init(imageData: Data = Data(), source: PhotoSource = .device, sortOrder: Int = 0) {
        self.imageData = imageData
        self.sourceRawValue = source.rawValue
        self.sortOrder = sortOrder
    }
}
