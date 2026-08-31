import Foundation
import SwiftData

/// How the app's store is set up for this launch.
enum StorageMode: Equatable {
    /// On disk, synced through the app's private CloudKit database. The normal
    /// case, and the only one a shipped app should reach.
    case cloudKit

    /// On disk, not synced. The fallback when the CloudKit configuration
    /// refuses to load: the collection is still there and still editable, and
    /// only sync is lost.
    case localOnly

    /// In memory, not synced. UI tests only — see `TroveApp.isUITesting`.
    case ephemeral
}

/// Builds the app's `ModelContainer`, and records which of the three ways it
/// ended up configured.
///
/// ## Not being signed into iCloud is not handled here — on purpose
///
/// plan.md asks that the app handle a signed-out user gracefully: data still
/// works locally, sync just doesn't happen. The way to get that is to *not*
/// ask. `NSPersistentCloudKitContainer`, which is what SwiftData sets up
/// underneath a `cloudKitDatabase:` configuration, loads its local store
/// whether or not there's an account, and picks the account up when one
/// appears. Nothing about the app's storage changes at sign-in.
///
/// Gating the configuration on `CKContainer.accountStatus()` — the shape this
/// would take if "handle the signed-out case" were read as "check for it" —
/// would *introduce* the bug it looks like it's preventing: whoever launched
/// the app before signing in would get a container built without CloudKit, and
/// stay unsynced until they happened to relaunch. So `.cloudKit` is what every
/// non-test launch asks for, unconditionally.
///
/// ## What the fallback is actually for
///
/// A container can still fail to load for reasons that are about CloudKit
/// rather than about the user: a provisioning profile that no longer carries
/// the entitlement, a container that isn't reachable for this build. Those
/// have nothing to do with the collection sitting on disk, so losing sync is
/// the whole cost and crashing would be a wild overreaction to it.
///
/// The one CloudKit failure that *should* be loud — a schema that breaks
/// CloudKit's rules — is caught by `CloudKitSchemaTests` before it can ever
/// reach a launch, which is what makes falling back here safe rather than a
/// way to hide bugs.
struct TroveStore {
    /// The container declared in `Trove/Trove.entitlements`. Named once, here:
    /// a mismatch between this string and the entitlement doesn't fail to
    /// build or fail to launch, it just quietly never syncs.
    /// `TroveStoreTests` compares the two.
    static let cloudKitContainerIdentifier = "iCloud.com.erikhaake.trove"

    let container: ModelContainer

    /// What the store actually turned out to be, which is not always what was
    /// asked for.
    let mode: StorageMode

    /// Why `mode` is `.localOnly` when `.cloudKit` was intended. Nothing reads
    /// this yet — v1 has nowhere to say it (see plan.md's CloudKit section) —
    /// but the alternative is discarding the reason at the only moment it's
    /// known.
    let cloudKitFailure: (any Error)?

    static func make(
        isUITesting: Bool,
        build: (ModelConfiguration) throws -> ModelContainer = {
            try ModelContainer(for: TroveSchema.schema, configurations: $0)
        }
    ) throws -> TroveStore {
        let intended = intendedMode(isUITesting: isUITesting)
        do {
            return TroveStore(container: try build(configuration(for: intended)), mode: intended, cloudKitFailure: nil)
        } catch {
            guard let fallback = fallback(after: intended) else { throw error }
            return TroveStore(container: try build(configuration(for: fallback)), mode: fallback, cloudKitFailure: error)
        }
    }

    static func intendedMode(isUITesting: Bool) -> StorageMode {
        isUITesting ? .ephemeral : .cloudKit
    }

    /// What to try when `mode` won't load, or `nil` when there's nothing left
    /// worth trying. Only the CloudKit configuration has a second option;
    /// returning one for the other two would mean a UI test silently running
    /// against the simulator's real store, or an endless retry of the same
    /// on-disk configuration that just failed.
    static func fallback(after mode: StorageMode) -> StorageMode? {
        mode == .cloudKit ? .localOnly : nil
    }

    /// `cloudKitDatabase` is spelled out in all three cases because its default
    /// is `.automatic`, which means "sync if the app carries an iCloud
    /// entitlement" — and the app now does. Left implicit, `.localOnly` would
    /// retry exactly the configuration that just failed, and a UI test would
    /// reach for the developer's real iCloud container.
    static func configuration(for mode: StorageMode) -> ModelConfiguration {
        switch mode {
        case .cloudKit:
            ModelConfiguration(
                schema: TroveSchema.schema,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        case .localOnly:
            ModelConfiguration(
                schema: TroveSchema.schema,
                cloudKitDatabase: .none
            )
        case .ephemeral:
            ModelConfiguration(
                schema: TroveSchema.schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        }
    }
}

