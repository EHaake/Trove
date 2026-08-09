import Foundation
import SwiftData
import Testing
@testable import Trove

/// Guards the claim this project keeps making: that the schema is
/// CloudKit-compatible from the start, so turning sync on once T002 is
/// unblocked is a contained swap rather than a migration.
///
/// SwiftData enforces CloudKit's schema rules — every attribute optional or
/// defaulted, every relationship optional, no unique constraints — when a
/// container is configured with a CloudKit database. Building the container is
/// enough to run that validation; no entitlement, account, or network access is
/// involved. Without this test the compatibility claim stays unverified until
/// the Developer Program membership lands, which is exactly when it would be
/// most expensive to discover it was wrong.
///
/// This caught `Item.photos` declared as `[Photo]` instead of `[Photo]?`.
@Suite("CloudKit schema compatibility")
struct CloudKitSchemaTests {
    /// Every `@Model` type in the app. Add new models here as they land.
    static let models: [any PersistentModel.Type] = [Item.self, Photo.self]

    @Test func schemaMeetsCloudKitRequirements() throws {
        let url = URL.temporaryDirectory.appending(path: "cloudkit-schema-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let configuration = ModelConfiguration(
            schema: Schema(Self.models),
            url: url,
            cloudKitDatabase: .private("iCloud.com.erikhaake.trove")
        )

        // A violation throws SwiftDataError.loadIssueModelContainer, which
        // carries no detail. The actionable message — which model and which
        // property — is in the CoreData error logged just above the failure.
        _ = try ModelContainer(for: Schema(Self.models), configurations: configuration)
    }
}
