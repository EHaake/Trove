import Foundation
import SwiftData

/// The app's persisted model types, in one place.
///
/// Both the live `ModelContainer` and `CloudKitSchemaTests` read this list, so
/// a new `@Model` type is covered by the CloudKit compatibility check the
/// moment it's registered — there's no second list to remember to update.
enum TroveSchema {
    static let models: [any PersistentModel.Type] = [
        Item.self,
        WishlistItem.self,
        Photo.self,
    ]

    static var schema: Schema { Schema(models) }
}
