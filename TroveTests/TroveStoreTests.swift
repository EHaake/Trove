import Foundation
import SwiftData
import Testing
@testable import Trove

/// Sync fails quietly. A container identifier that doesn't match the
/// entitlement, a background mode the Info.plist generator dropped, a fallback
/// that asks for CloudKit a second time — none of those fail to build, fail to
/// launch, or show anything on screen. They look exactly like an app that
/// works, right up until someone installs it on a second device and their
/// collection isn't there.
///
/// So the decisions get tested even though sync itself doesn't (plan.md's
/// testing strategy: CloudKit sync is verified by hand across two devices,
/// T048). What's checked here is everything that can be checked without an
/// account: which configurations each launch asks for, what happens when they
/// won't load, and whether the two files outside the Swift sources agree with
/// the one string in them. The two-store shape itself — which models go where,
/// the filenames, the disjointness — is `MarketLocalSchemaTests`' (002).
@Suite("Trove store")
struct TroveStoreTests {
    // MARK: - Which configuration a launch asks for

    /// Not conditional on an iCloud account, deliberately — see `TroveStore`'s
    /// doc comment. This test is most of what pins that: a change to
    /// "only ask for CloudKit when signed in" has to come through here.
    @Test func everyRealLaunchAsksForCloudKit() {
        #expect(TroveStore.intendedMode(isUITesting: false) == .cloudKit)
    }

    @Test func uiTestLaunchesAskForAThrowawayStore() {
        #expect(TroveStore.intendedMode(isUITesting: true) == .ephemeral)
    }

    @Test func theCloudKitConfigurationNamesTheContainer() {
        #expect(
            TroveStore.configurations(for: .cloudKit)[0].cloudKitContainerIdentifier
                == TroveStore.cloudKitContainerIdentifier
        )
    }

    /// `ModelConfiguration`'s `cloudKitDatabase` defaults to `.automatic`,
    /// which now resolves to the real container because the app carries the
    /// entitlement. A UI test that inherited that default would be reading and
    /// writing the developer's own iCloud data — and `-uiTesting` exists
    /// precisely so a test run has no ambient state.
    ///
    /// Audit (002/T001a): `cloudKitContainerIdentifier` is `nil` for
    /// `.automatic` as well as `.none`, so the `== nil` half of this test
    /// **cannot** see a dropped `.none` — it pins only that no configuration
    /// names the container outright. The guard that can see the label is
    /// `MarketLocalSchemaTests.everyConfigurationSpellsOutItsCloudKitDatabase`.
    @Test func uiTestsNeverReachICloud() {
        let configurations = TroveStore.configurations(for: .ephemeral)

        #expect(!configurations.isEmpty)
        for configuration in configurations {
            #expect(configuration.isStoredInMemoryOnly)
            #expect(
                configuration.cloudKitContainerIdentifier == nil,
                "UI tests would sync to \(configuration.cloudKitContainerIdentifier ?? "")"
            )
        }
    }

    // MARK: - The fallback

    /// The point of the fallback: the user's collection is the same file
    /// either way, so dropping sync costs sync and nothing else. Both synced
    /// configurations leave the URL unset so SwiftData resolves its default —
    /// naming a path in one and not the other is how this would break, and
    /// it would look like the app had forgotten everything.
    @Test func theFallbackOpensTheSameCollection() {
        #expect(
            TroveStore.configurations(for: .cloudKit)[0].url
                == TroveStore.configurations(for: .localOnly)[0].url
        )
    }

    /// A fallback that inherited `.automatic` would ask for the CloudKit
    /// container it just failed on, fail identically, and turn a lost sync
    /// into a crash.
    ///
    /// Audit (002/T001a): as with `uiTestsNeverReachICloud`, `nil` here is
    /// what `.automatic` reports too, so this pins only that the fallback
    /// doesn't name the container explicitly; the label scan in
    /// `MarketLocalSchemaTests` is the guard against a dropped `.none`.
    @Test func theFallbackDoesNotAskForCloudKitAgain() {
        #expect(TroveStore.configurations(for: .localOnly)[0].cloudKitContainerIdentifier == nil)
    }

    @Test func onlyCloudKitHasSomethingToFallBackTo() {
        #expect(TroveStore.fallback(after: .cloudKit) == .localOnly)
        #expect(TroveStore.fallback(after: .localOnly) == nil)
        #expect(TroveStore.fallback(after: .ephemeral) == nil)
    }

    /// End to end through `make`, because the three tests above are each
    /// satisfiable while `make` ignores all of them.
    @Test func aCloudKitFailureLeavesAWorkingLocalStore() throws {
        var asked: [String?] = []
        var recreated: [URL] = []
        let store = try TroveStore.make(isUITesting: false, build: { configurations in
            asked.append(configurations[0].cloudKitContainerIdentifier)
            if configurations[0].cloudKitContainerIdentifier != nil {
                // Stands in for the real causes — an entitlement the
                // provisioning profile no longer carries, a container this
                // build can't reach.
                throw CocoaError(.fileReadUnknown)
            }
            return try inMemoryContainer()
        }, recreateLocalStore: { recreated.append($0) })

        #expect(store.mode == .localOnly)
        #expect(store.cloudKitFailure != nil, "The reason CloudKit dropped out was thrown away")
        #expect(asked == [TroveStore.cloudKitContainerIdentifier, nil])
        #expect(recreated.isEmpty, "A CloudKit failure is not a reason to touch the local store")
    }

    /// Plan Q21: the third attempt. A local store that won't open fails the
    /// intended pair and the fallback pair alike — the synced half is the
    /// same file in both — and without this step the launch would end in
    /// `TroveApp`'s `fatalError` forever, over the app's own disposable
    /// summaries. The recreate hook is called once, with the local URL and
    /// never the collection's, and the launch opens `.localOnly` so the
    /// next one can ask for CloudKit again.
    @Test func aBrokenLocalStoreIsRecreatedOnceAndTheLaunchStillOpens() throws {
        var attempts = 0
        var recreated: [URL] = []
        let store = try TroveStore.make(isUITesting: false, build: { _ in
            attempts += 1
            if attempts < 3 { throw CocoaError(.fileReadCorruptFile) }
            return try inMemoryContainer()
        }, recreateLocalStore: { recreated.append($0) })

        #expect(attempts == 3)
        #expect(recreated == [TroveStore.localConfiguration().url])
        #expect(recreated.first != TroveStore.configurations(for: .cloudKit)[0].url, "The collection was handed to the recreate hook")
        #expect(store.mode == .localOnly)
        #expect(store.cloudKitFailure != nil)
    }

    @Test func aStoreThatOpensFirstTimeIsNeverRecreated() throws {
        var recreated: [URL] = []
        let store = try TroveStore.make(isUITesting: false, build: { _ in try inMemoryContainer() },
                                        recreateLocalStore: { recreated.append($0) })

        #expect(store.mode == .cloudKit)
        #expect(recreated.isEmpty)
    }

    /// Three failures is the end: the recreate ran once, and the error that
    /// reaches the caller is the last one, not a fourth attempt.
    @Test func aLaunchThatFailsAllThreeTimesThrowsAfterOneRecreate() {
        var attempts = 0
        var recreated: [URL] = []
        #expect(throws: CocoaError.self) {
            _ = try TroveStore.make(isUITesting: false, build: { _ in
                attempts += 1
                throw CocoaError(.fileReadCorruptFile)
            }, recreateLocalStore: { recreated.append($0) })
        }
        #expect(attempts == 3)
        #expect(recreated.count == 1)
    }

    /// The other half. Retrying without CloudKit only makes sense for a
    /// failure CloudKit caused; a UI test whose store won't load has to say so
    /// rather than quietly running against something else — and never reach
    /// for the recreate step, which is about a disk file it doesn't have.
    ///
    /// The fake fails only the in-memory configuration, so a `fallback` that
    /// offered `.localOnly` to every mode would be caught here — `make` would
    /// hand back a working on-disk store instead of throwing. A fake that
    /// threw for everything would let that mistake through.
    @Test func aUITestStoreThatWillNotLoadIsNotQuietlyReplacedByTheRealOne() {
        var recreated: [URL] = []
        #expect(throws: CocoaError.self) {
            _ = try TroveStore.make(isUITesting: true, build: { configurations in
                if configurations[0].isStoredInMemoryOnly { throw CocoaError(.fileReadUnknown) }
                return try inMemoryContainer()
            }, recreateLocalStore: { recreated.append($0) })
        }
        #expect(recreated.isEmpty)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TroveSchema.combinedSchema,
            configurations: ModelConfiguration(
                schema: TroveSchema.combinedSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }

    // MARK: - Agreement with the two files that aren't Swift

    /// `Trove.entitlements` and `TroveStore` name the same container in two
    /// places that can't see each other. If they disagree the app builds,
    /// launches, and never syncs.
    @Test func theContainerIdentifierMatchesTheEntitlement() throws {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove/Trove.entitlements")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: url),
            format: nil
        ) as? [String: Any]

        let declared = plist?["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []

        #expect(!declared.isEmpty, "Trove.entitlements declares no iCloud container — nothing can sync.")
        #expect(
            declared.contains(TroveStore.cloudKitContainerIdentifier),
            """
            TroveStore asks for "\(TroveStore.cloudKitContainerIdentifier)", \
            which the app isn't entitled to use. Entitled to: \
            \(declared.joined(separator: ", "))
            """
        )
    }

    /// Read from the built bundle rather than from `Config/Info.plist`,
    /// because the hazard is the gap between the two: `UIBackgroundModes` is
    /// array-valued, `INFOPLIST_KEY_UIBackgroundModes` is silently ignored by
    /// the Info.plist generator, and the partial plist that works around that
    /// is easy to lose in a project-file edit. Without the mode, changes made
    /// on another device wait for the next foreground instead of arriving.
    @Test func theAppCanReceiveTheSilentPushesThatDriveSync() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []

        #expect(
            modes.contains("remote-notification"),
            """
            The built app's UIBackgroundModes is \(modes.isEmpty ? "empty" : modes.joined(separator: ", ")). \
            CloudKit's push-driven sync needs "remote-notification" — see Config/Info.plist.
            """
        )
    }
}
