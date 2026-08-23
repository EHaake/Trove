import Foundation
import Testing
@testable import Trove

/// T052. `NSPersistentCloudKitContainer.Event` has no public initialiser and a
/// real one needs an account, a network and a container, so the state machine
/// is written against `SyncEvent` and driven directly here — the fake is the
/// test surface, not a stand-in for one.
///
/// What the mapping from the real event type looks like is checked by the
/// compiler and by T051's probe against a live launch; what it *means* is
/// checked here.
@Suite("Sync monitor")
struct SyncMonitorTests {
    private func started(_ kind: SyncEvent.Kind) -> SyncEvent {
        SyncEvent(kind: kind, isFinished: false, succeeded: false)
    }

    private func finished(_ kind: SyncEvent.Kind, succeeded: Bool) -> SyncEvent {
        SyncEvent(kind: kind, isFinished: true, succeeded: succeeded)
    }

    // MARK: - Starting position

    @Test func aCloudKitLaunchStartsNotKnowing() {
        let monitor = SyncMonitor(mode: .cloudKit)

        #expect(monitor.phase == .unknown)
        #expect(monitor.mayStillBeImporting)
    }

    /// Without this, every caller would need its own mode check, and the one
    /// that forgot would show "still catching up" on a store that has no
    /// mirror at all.
    @Test(arguments: [StorageMode.localOnly, .ephemeral])
    func aStoreWithNoMirrorIsNeverWaitingOnOne(mode: StorageMode) {
        let monitor = SyncMonitor(mode: mode)

        #expect(monitor.phase == .unavailable)
        #expect(!monitor.mayStillBeImporting)
    }

    // MARK: - The sequence a real device produces

    /// The order T051's probe observed, then the import a signed-in device
    /// goes on to run.
    @Test func aFirstImportRunsFromNotKnowingToCaughtUp() {
        let monitor = SyncMonitor(mode: .cloudKit)

        monitor.record(started(.setup))
        #expect(monitor.phase == .working)

        monitor.record(finished(.setup, succeeded: true))
        #expect(monitor.phase == .working, "Setup finishing isn't data arriving")

        monitor.record(started(.importChanges))
        #expect(monitor.mayStillBeImporting)

        monitor.record(finished(.importChanges, succeeded: true))
        #expect(monitor.phase == .caughtUp)
        #expect(!monitor.mayStillBeImporting)
    }

    /// The sequence T051's probe actually recorded, on a simulator with no
    /// iCloud account: setup starts, setup fails, nothing follows. The
    /// collection on screen is the whole collection, and saying otherwise
    /// forever would be worse than the bug this phase fixes.
    @Test func aSignedOutDeviceStopsClaimingItMightBeImporting() {
        let monitor = SyncMonitor(mode: .cloudKit)

        monitor.record(started(.setup))
        monitor.record(finished(.setup, succeeded: false))

        #expect(monitor.phase == .unavailable)
        #expect(!monitor.mayStillBeImporting)
    }

    @Test func aFailedImportAlsoStopsTheClaim() {
        let monitor = SyncMonitor(mode: .cloudKit)

        monitor.record(finished(.importChanges, succeeded: false))

        #expect(monitor.phase == .unavailable)
    }

    // MARK: - Which transitions stick

    /// Signing in, or a network coming back, happens without relaunching.
    @Test func unavailableIsNotTheEndOfIt() {
        let monitor = SyncMonitor(mode: .cloudKit)

        monitor.record(finished(.setup, succeeded: false))
        monitor.record(started(.importChanges))

        #expect(monitor.phase == .working)
    }

    /// The flicker guard. Routine syncs run for the life of the app; if each
    /// one reopened the question, a list that's empty because it *is* empty
    /// would keep flashing "still catching up" at its owner.
    @Test func caughtUpStaysCaughtUp() {
        let monitor = SyncMonitor(mode: .cloudKit)

        monitor.record(finished(.importChanges, succeeded: true))
        for event in [started(.importChanges), started(.setup), finished(.importChanges, succeeded: false)] {
            monitor.record(event)
            #expect(monitor.phase == .caughtUp, "\(event) reopened a settled question")
        }
    }

    // MARK: - Telling the screens to look again

    /// A long first import lands in passes, and each one is more of someone's
    /// collection appearing. Counting them is what lets a screen that's
    /// already open refetch instead of waiting to be navigated away from.
    @Test func everyLandedImportIsCounted() {
        let monitor = SyncMonitor(mode: .cloudKit)

        monitor.record(finished(.importChanges, succeeded: true))
        monitor.record(started(.importChanges))
        monitor.record(finished(.importChanges, succeeded: true))

        #expect(monitor.completedImports == 2)
    }

    /// Nothing arrived, so there's nothing new to fetch — and a refetch on a
    /// failure would be a retry loop, not a refresh.
    @Test func nothingThatFailedOrIsStillRunningCounts() {
        let monitor = SyncMonitor(mode: .cloudKit)

        for event in [
            started(.importChanges),
            finished(.importChanges, succeeded: false),
            finished(.setup, succeeded: true),
            finished(.exportChanges, succeeded: true),
        ] {
            monitor.record(event)
        }

        #expect(monitor.completedImports == 0)
    }

    /// Exports are this device's own changes going out. Treating one as
    /// activity would make saving an item on an empty device announce that
    /// the collection might still be arriving.
    @Test(arguments: [SyncPhase.unknown, .unavailable])
    func exportsAreNotEvidenceOfAnythingArriving(startingFrom: SyncPhase) {
        for event in [started(.exportChanges), finished(.exportChanges, succeeded: true), finished(.exportChanges, succeeded: false)] {
            #expect(SyncMonitor.phase(after: event, from: startingFrom) == startingFrom, "\(event)")
        }
    }
}
