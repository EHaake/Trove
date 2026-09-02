import Testing
@testable import Trove

/// 013/T005: the iCloud row's copy as a full-string table over every
/// (mode, phase, reason) cell — that table *is* criterion 10's guard (no
/// state claims another device has the collection), rather than a
/// substring check that would catch one phrasing of the claim.
@Suite("Sync status copy")
struct SyncStatusCopyTests {
    private nonisolated static let reason = "The operation couldn't be completed. (CKErrorDomain error 1.)"

    // `nonisolated`: `@Test(arguments:)` reads its source outside the
    // suite's main-actor default.
    private nonisolated static let table: [(StorageMode, SyncPhase, String?, SyncStatus)] = [
        (.cloudKit, .caughtUp, nil,
         SyncStatus(headline: "Syncing with iCloud", detail: "This device has your collection.")),
        (.cloudKit, .unknown, nil,
         SyncStatus(headline: "Catching up with iCloud", detail: "Your collection is on its way to this device.")),
        (.cloudKit, .working, nil,
         SyncStatus(headline: "Catching up with iCloud", detail: "Your collection is on its way to this device.")),
        (.cloudKit, .unavailable, nil,
         SyncStatus(
            headline: "iCloud isn't available",
            detail: "No iCloud account is signed in, or iCloud can't be reached. Your collection stays on this device."
         )),
        (.localOnly, .unavailable, reason,
         SyncStatus(
            headline: "On this device only",
            detail: "iCloud couldn't be set up when Trove launched: \(reason)"
         )),
        (.ephemeral, .unavailable, nil,
         SyncStatus(headline: "On this device only", detail: "Nothing syncs from here.")),
    ]

    @Test(arguments: table)
    func everyCellReadsExactly(_ cell: (StorageMode, SyncPhase, String?, SyncStatus)) {
        let (mode, phase, reason, expected) = cell
        #expect(SyncStatusCopy.status(mode: mode, phase: phase, fallbackReason: reason) == expected)
    }

    /// A configured-for-iCloud mode never claims a fallback, whatever
    /// reason happens to be injected; a local mode never claims a fallback
    /// it has no recorded reason for.
    @Test func theReasonOnlySpeaksForALocalModeThatRecordedOne() {
        let syncing = SyncStatusCopy.status(mode: .cloudKit, phase: .caughtUp, fallbackReason: Self.reason)
        #expect(!syncing.detail.contains("couldn't be set up"))

        let ephemeral = SyncStatusCopy.status(mode: .ephemeral, phase: .unavailable, fallbackReason: nil)
        #expect(!ephemeral.detail.contains("couldn't be set up"))

        let local = SyncStatusCopy.status(mode: .localOnly, phase: .unavailable, fallbackReason: nil)
        #expect(local.detail == "Nothing syncs from here.")
    }

    @Test func aLongReasonIsCarriedVerbatim() {
        let long = String(repeating: "A very long developer-facing sentence. ", count: 8)
        let status = SyncStatusCopy.status(mode: .localOnly, phase: .unavailable, fallbackReason: long)
        #expect(status.detail.hasSuffix(long))
    }

    /// Criterion 10, stated directly over every cell of the table: nothing
    /// tells a possibly signed-out user that other devices have the
    /// collection.
    @Test func noStateClaimsOtherDevicesHaveTheCollection() {
        for (mode, phase, reason, _) in Self.table {
            let status = SyncStatusCopy.status(mode: mode, phase: phase, fallbackReason: reason)
            for text in [status.headline, status.detail] {
                #expect(!text.localizedCaseInsensitiveContains("other devices"), "\(mode)/\(phase): \(text)")
                #expect(!text.localizedCaseInsensitiveContains("your devices"), "\(mode)/\(phase): \(text)")
            }
        }
    }

    /// The catching-up headline is the empty states' own, so the two
    /// surfaces describe one condition in one voice.
    @Test func catchingUpUsesTheEmptyStatesHeadline() {
        let status = SyncStatusCopy.status(mode: .cloudKit, phase: .working, fallbackReason: nil)
        #expect(status.headline == "Catching up with iCloud")
    }
}
