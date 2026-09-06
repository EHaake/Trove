import Foundation
import SwiftData

/// The app's persisted model types, in one place — two lists, because they
/// go to two stores.
///
/// `models` is the synced collection: both the live container's CloudKit
/// configuration and `CloudKitSchemaTests` read it, so a new synced `@Model`
/// is covered by the CloudKit compatibility check the moment it's registered.
///
/// `localModels` (002) is the device-local store — market figures, history,
/// the matched product's catalog snapshot, and per-device facts like the
/// one-time notice. **Never in `models`**: registering one there would sync
/// it, and `CloudKitSchemaTests` would not object (every field is defaulted).
/// `MarketLocalSchemaTests` pins the two lists disjoint, and pins that the
/// container's schema is exactly their union.
nonisolated enum TroveSchema {
    static let models: [any PersistentModel.Type] = [
        Item.self,
        WishlistItem.self,
        Photo.self,
    ]

    static let localModels: [any PersistentModel.Type] = [
        MarketFigureRecord.self,
        MarketHistoryPoint.self,
        MarketMatchSnapshot.self,
        MarketDeviceState.self,
    ]

    /// What CloudKit validates and syncs.
    static var schema: Schema { Schema(models) }

    /// What the local configuration owns.
    static var localSchema: Schema { Schema(localModels) }

    /// What the one `ModelContainer` is built over.
    static var combinedSchema: Schema { Schema(models + localModels) }

    /// The same union as a type list, for `.modelContainer(for:inMemory:)`.
    static var allModels: [any PersistentModel.Type] { models + localModels }
}
