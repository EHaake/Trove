import Foundation
import SwiftData
import Testing
@testable import Trove

/// Guards the claim this project kept making while T002 was blocked: that the
/// schema was CloudKit-compatible from the start, so turning sync on would be
/// a contained swap rather than a migration. It was, and it was.
///
/// SwiftData enforces CloudKit's schema rules — every attribute optional or
/// defaulted, every relationship optional, no unique constraints — when a
/// container is configured with a CloudKit database. Building the container is
/// enough to run that validation; no entitlement, account, or network access is
/// involved. That mattered most before the Developer Program membership
/// landed, when the alternative was leaving the claim unverified until the one
/// moment it would be most expensive to find wrong. It still matters now: sync
/// is live, so a model change that breaks CloudKit's rules stops being a
/// launch-time error and starts being other people's devices going quiet.
///
/// This caught `Item.photos` declared as `[Photo]` instead of `[Photo]?`.
///
/// The second thing it has been asked to catch is `015`'s
/// `WishlistItem.boughtDate`: the plan claims that field is optional, carries
/// no unique constraint, and is therefore additive to a store already in the
/// field, and T001 proved the claim is checked here rather than merely
/// asserted — declaring it `@Attribute(.unique) var boughtDate: Date?` turns
/// this test red.
///
/// The third is `009`'s `WishlistItem.sellPlanCreatedAt` and
/// `sellPlanCheckedAt`: both optional, neither unique, additive to the same
/// store — and T001 proved it the same way, declaring
/// `@Attribute(.unique) var sellPlanCreatedAt: Date?` turns this test red.
///
/// The fourth is `009` Amendment A's relationship pair
/// `WishlistItem.boughtItem` ↔ `Item.boughtFromWishlistItem`: both ends
/// optional, an inverse declared, `.nullify` rather than `.deny` — and T017
/// proved it the same way, `deleteRule: .deny` on either end turns this test
/// red. Removing `inverse:` from `Item`'s declaration turns it red as well:
/// T017 observed SwiftData make two one-way links, not pair the record with
/// `Item`'s other to-one into `WishlistItem`. `WishlistPurchaseStoreTests`
/// reads both ends back on a second context.
@Suite("CloudKit schema compatibility")
struct CloudKitSchemaTests {
    @Test func schemaMeetsCloudKitRequirements() throws {
        let url = URL.temporaryDirectory.appending(path: "cloudkit-schema-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // The container the app really asks for, not a copy of its name — a
        // test that validated the schema against some other container would
        // still pass while the app failed to launch. The URL is the one thing
        // overridden, to keep the check off the app's own store file.
        let configuration = ModelConfiguration(
            schema: TroveSchema.schema,
            url: url,
            cloudKitDatabase: .private(TroveStore.cloudKitContainerIdentifier)
        )

        // A violation throws SwiftDataError.loadIssueModelContainer, which
        // carries no detail. The actionable message — which model and which
        // property — is in the CoreData error logged just above the failure.
        _ = try ModelContainer(for: TroveSchema.schema, configurations: configuration)
    }
}
