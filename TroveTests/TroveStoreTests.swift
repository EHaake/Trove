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
/// account: which configuration each launch asks for, what happens when it
/// won't load, and whether the two files outside the Swift sources agree with
/// the one string in them.
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
            TroveStore.configuration(for: .cloudKit).cloudKitContainerIdentifier
                == TroveStore.cloudKitContainerIdentifier
        )
    }

    /// `ModelConfiguration`'s `cloudKitDatabase` defaults to `.automatic`,
    /// which now resolves to the real container because the app carries the
    /// entitlement. A UI test that inherited that default would be reading and
    /// writing the developer's own iCloud data — and `-uiTesting` exists
    /// precisely so a test run has no ambient state.
    @Test func uiTestsNeverReachICloud() {
        let configuration = TroveStore.configuration(for: .ephemeral)

        #expect(configuration.isStoredInMemoryOnly)
        #expect(
            configuration.cloudKitContainerIdentifier == nil,
            "UI tests would sync to \(configuration.cloudKitContainerIdentifier ?? "")"
        )
    }

    // MARK: - The fallback

    /// The point of the fallback: the user's collection is the same file
    /// either way, so dropping sync costs sync and nothing else. Both
    /// configurations leave the URL unset so SwiftData resolves its default —
    /// naming a path in one and not the other is how this would break, and
    /// it would look like the app had forgotten everything.
    @Test func theFallbackOpensTheSameCollection() {
        #expect(
            TroveStore.configuration(for: .cloudKit).url
                == TroveStore.configuration(for: .localOnly).url
        )
    }

    /// A fallback that inherited `.automatic` would ask for the CloudKit
    /// container it just failed on, fail identically, and turn a lost sync
    /// into a crash.
    @Test func theFallbackDoesNotAskForCloudKitAgain() {
        #expect(TroveStore.configuration(for: .localOnly).cloudKitContainerIdentifier == nil)
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
        let store = try TroveStore.make(isUITesting: false) { configuration in
            asked.append(configuration.cloudKitContainerIdentifier)
            if configuration.cloudKitContainerIdentifier != nil {
                // Stands in for the real causes — an entitlement the
                // provisioning profile no longer carries, a container this
                // build can't reach.
                throw CocoaError(.fileReadUnknown)
            }
            return try inMemoryContainer()
        }

        #expect(store.mode == .localOnly)
        #expect(store.cloudKitFailure != nil, "The reason CloudKit dropped out was thrown away")
        #expect(asked == [TroveStore.cloudKitContainerIdentifier, nil])
    }

    /// The other half. Retrying without CloudKit only makes sense for a
    /// failure CloudKit caused; a UI test whose store won't load has to say so
    /// rather than quietly running against something else.
    ///
    /// The fake fails only the in-memory configuration, so a `fallback` that
    /// offered `.localOnly` to every mode would be caught here — `make` would
    /// hand back a working on-disk store instead of throwing. A fake that
    /// threw for everything would let that mistake through.
    @Test func aUITestStoreThatWillNotLoadIsNotQuietlyReplacedByTheRealOne() {
        #expect(throws: CocoaError.self) {
            _ = try TroveStore.make(isUITesting: true) { configuration in
                if configuration.isStoredInMemoryOnly { throw CocoaError(.fileReadUnknown) }
                return try inMemoryContainer()
            }
        }
    }

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TroveSchema.schema,
            configurations: ModelConfiguration(
                schema: TroveSchema.schema,
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
