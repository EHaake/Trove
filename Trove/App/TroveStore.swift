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

    /// The name of the device-local configuration — and, through SwiftData's
    /// default URL rule, its file: `Application Support/MarketLocal.store`,
    /// beside the collection's `default.store`. The synced configuration is
    /// deliberately *unnamed*: naming it would move the shipped collection to
    /// a new file and the app would open empty. `MarketLocalSchemaTests` pins
    /// both filenames.
    static let localStoreName = "MarketLocal"

    /// Three attempts, then throw (plan Q21). The intended pair; the fallback
    /// pair (sync dropped); and — because a local store that won't open is
    /// the app's own disposable summaries, not the collection — the fallback
    /// pair again with the local store recreated. `recreateLocalStore` is a
    /// parameter so the decision is testable without touching a real file.
    static func make(
        isUITesting: Bool,
        build: ([ModelConfiguration]) throws -> ModelContainer = TroveStore.buildContainer,
        recreateLocalStore: (URL) throws -> Void = TroveStore.removeLocalStoreFiles
    ) throws -> TroveStore {
        let intended = intendedMode(isUITesting: isUITesting)
        do {
            return TroveStore(container: try build(configurations(for: intended)), mode: intended, cloudKitFailure: nil)
        } catch let firstFailure {
            guard let fallback = fallback(after: intended) else { throw firstFailure }
            do {
                return TroveStore(container: try build(configurations(for: fallback)), mode: fallback, cloudKitFailure: firstFailure)
            } catch {
                // Reached only when the synced store also fails without
                // CloudKit — which, since it is the same file either way,
                // points at the *other* store in the pair. The reason
                // recorded is still the first failure: a local-store fault
                // reported as a CloudKit one is the accepted misattribution
                // (plan §1); the collection opens, and the next launch asks
                // for CloudKit again.
                try recreateLocalStore(localConfiguration().url)
                return TroveStore(container: try build(configurations(for: fallback)), mode: fallback, cloudKitFailure: firstFailure)
            }
        }
    }

    /// The real builder — one container over the union schema, each model
    /// owned by exactly one of the configurations.
    nonisolated static func buildContainer(_ configurations: [ModelConfiguration]) throws -> ModelContainer {
        try ModelContainer(for: TroveSchema.combinedSchema, configurations: configurations)
    }

    /// Deletes the local store's file and SQLite's sidecars, if present.
    /// Never called with the collection's URL — `make` passes only
    /// `localConfiguration().url`, and `TroveStoreTests` pins that.
    nonisolated static func removeLocalStoreFiles(at url: URL) throws {
        let manager = FileManager.default
        for candidate in [url, URL(filePath: url.path + "-wal"), URL(filePath: url.path + "-shm")]
        where manager.fileExists(atPath: candidate.path) {
            try manager.removeItem(at: candidate)
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

    /// `cloudKitDatabase` is spelled out on every configuration because its
    /// default is `.automatic`, which means "sync if the app carries an iCloud
    /// entitlement" — and the app does. Left implicit, `.localOnly` would
    /// retry exactly the configuration that just failed, a UI test would
    /// reach for the developer's real iCloud container, and the local store
    /// would sync the one thing the spec says never syncs. Note that
    /// `cloudKitContainerIdentifier` reads `nil` for `.automatic` *and* for
    /// `.none` (checked 2026-09-03), so no test can see a dropped `.none`
    /// through that property; `MarketLocalSchemaTests` scans this file for
    /// the label instead.
    ///
    /// The two disk modes return a pair: the synced configuration first, the
    /// device-local `MarketLocal` second. `.ephemeral` is one in-memory
    /// configuration over everything — two in-memory stores would share
    /// `/dev/null`, and in memory nothing syncs, so the split has no meaning.
    /// `directory` exists so a test can build the production pairing into a
    /// scratch folder (`TwoStoreContainerTests`); the app passes nothing and
    /// gets SwiftData's default location.
    static func configurations(for mode: StorageMode, directory: URL? = nil) -> [ModelConfiguration] {
        switch mode {
        case .cloudKit:
            [
                syncedConfiguration(cloudKitDatabase: .private(cloudKitContainerIdentifier), directory: directory),
                localConfiguration(directory: directory),
            ]
        case .localOnly:
            [
                syncedConfiguration(cloudKitDatabase: .none, directory: directory),
                localConfiguration(directory: directory),
            ]
        case .ephemeral:
            [
                ModelConfiguration(
                    schema: TroveSchema.combinedSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
            ]
        }
    }

    /// The collection. Unnamed — see `localStoreName`.
    private static func syncedConfiguration(
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase,
        directory: URL?
    ) -> ModelConfiguration {
        if let directory {
            ModelConfiguration(
                schema: TroveSchema.schema,
                url: directory.appending(path: "default.store"),
                cloudKitDatabase: cloudKitDatabase
            )
        } else {
            ModelConfiguration(
                schema: TroveSchema.schema,
                cloudKitDatabase: cloudKitDatabase
            )
        }
    }

    /// The device-local store (002). Never `.automatic`.
    static func localConfiguration(directory: URL? = nil) -> ModelConfiguration {
        if let directory {
            ModelConfiguration(
                localStoreName,
                schema: TroveSchema.localSchema,
                url: directory.appending(path: "\(localStoreName).store"),
                cloudKitDatabase: .none
            )
        } else {
            ModelConfiguration(
                localStoreName,
                schema: TroveSchema.localSchema,
                cloudKitDatabase: .none
            )
        }
    }
}
