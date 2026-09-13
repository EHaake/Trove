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

/// `nonisolated` explicitly (011/T008): the export pipeline fetches photo
/// blobs from background `ModelContext`s off the main actor, and the
/// project's MainActor default would otherwise make `imageData` unreadable
/// there. SwiftData models are context-bound, not actor-bound — the type
/// stays non-`Sendable`, so instances still can't cross isolation domains;
/// each domain fetches through its own context.
@Model
nonisolated final class Photo {
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

    /// The stock photo's author, for the credit (spec P4). Nil on a `.device`
    /// photo, and on a `.fetched` photo whose Wikimedia file names no author,
    /// where the credit reads "Wikimedia Commons".
    ///
    /// Optional with a default so the field is CloudKit-additive — an existing
    /// store validates against the new schema without migration
    /// (`CloudKitSchemaTests`).
    var attributionAuthor: String? = nil

    /// The Wikimedia licence's short name, e.g. "CC BY-SA 4.0" (spec P4). Nil
    /// on a `.device` photo. Optional-with-default for the same CloudKit-additive
    /// reason as `attributionAuthor`.
    var attributionLicense: String? = nil

    /// The Commons file page — the link the credit opens (spec P4). Stored as a
    /// String (a URL round-trips through String and is CloudKit-safe as one).
    /// Nil on a `.device` photo; optional-with-default like the fields above.
    var attributionSourceURL: String? = nil

    /// Inverse of `Item.photos`, which owns the `@Relationship` declaration.
    var item: Item?

    /// Inverse of `WishlistItem.photos`, declared the same way on that side.
    ///
    /// A photo belongs to at most one of `item` or `wishlistItem`, never both.
    /// SwiftData can't express "exactly one of these two", so what actually
    /// holds the line is that each form only ever writes its own side —
    /// `PhotoOwnershipTests` is what keeps that true rather than a comment.
    /// Two independently-optional relationships is what lets one `Photo` type
    /// serve both entities without a shared parent protocol or the polymorphic
    /// relationship SwiftData doesn't really support.
    var wishlistItem: WishlistItem?

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

extension Photo {
    /// The credit to show, when this is a stock photo. `nil` for a `.device`
    /// photo. Reconstructs a `StockPhotoAttribution` from the three stored
    /// strings, keeping the read side of the two-way mapping in one place next
    /// to the builder that writes it.
    ///
    /// Total by construction: a `.fetched` photo built by `fetched(...)` always
    /// carries the three fields, but this decodes defensively — a nil author
    /// falls back to "Wikimedia Commons" (spec P4), and an unparseable or nil
    /// source URL falls back to Commons' main page so the credit still links
    /// somewhere real.
    var attribution: StockPhotoAttribution? {
        guard source == .fetched else { return nil }
        let author = attributionAuthor ?? "Wikimedia Commons"
        let licenseName = attributionLicense ?? ""
        let sourceURL = attributionSourceURL.flatMap(URL.init(string:))
            ?? URL(string: "https://commons.wikimedia.org")!
        return StockPhotoAttribution(
            author: author, licenseName: licenseName, sourceURL: sourceURL)
    }

    /// Builds a stored stock photo from a downloaded candidate: sets
    /// `source = .fetched` and flattens the attribution into the three stored
    /// strings, the write side of the mapping `attribution` reads back.
    static func fetched(
        imageData: Data, attribution: StockPhotoAttribution, sortOrder: Int
    ) -> Photo {
        let photo = Photo(imageData: imageData, source: .fetched, sortOrder: sortOrder)
        photo.attributionAuthor = attribution.author
        photo.attributionLicense = attribution.licenseName
        photo.attributionSourceURL = attribution.sourceURL.absoluteString
        return photo
    }
}
