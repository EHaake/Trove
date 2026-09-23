import CoreData
import Foundation

/// How far along this device's copy of the collection is.
///
/// The distinction that matters is between "empty" and "empty *so far*" —
/// `T048` measured a first import taking minutes, and for all of that time an
/// empty screen looked exactly like a collection nobody had added to.
enum SyncPhase: Equatable {
    /// CloudKit hasn't said anything yet. The honest starting position: the
    /// store may or may not be complete and there's no evidence either way.
    case unknown

    /// Setup or an import is in flight. Local data may be incomplete.
    case working

    /// An import finished successfully, so what's on disk is what there is.
    case caughtUp

    /// CloudKit reported a failure, or isn't running at all. Nothing further
    /// is arriving, so an empty collection is genuinely empty.
    ///
    /// **This case exists because of what T051's probe found**, not by
    /// anticipation. On a device with no iCloud account, setup completes with
    /// `succeeded == false` and *no import event ever follows*. A state
    /// machine that only left `.working` on a successful import would leave
    /// every signed-out device claiming "still catching up" forever — worse
    /// than the bug Phase 12 set out to fix.
    case unavailable
}

/// One CloudKit event, reduced to the three things the state machine reads.
///
/// `NSPersistentCloudKitContainer.Event` can't be constructed in a test — it
/// has no public initialiser — so the state machine is written against this
/// instead and the mapping is kept to one function. Per T052, the fake *is*
/// the test surface.
struct SyncEvent: Equatable, Sendable {
    enum Kind: Equatable { case setup, importChanges, exportChanges }

    let kind: Kind

    /// Every operation reports twice: once on starting, with no end date, and
    /// once on finishing.
    let isFinished: Bool

    /// Only meaningful when `isFinished` — the in-flight event reports
    /// `succeeded == false` simply because it hasn't yet.
    let succeeded: Bool
}

/// Watches CloudKit's mirroring events and reduces them to one question the
/// empty states can ask: might the collection still be arriving?
@Observable
final class SyncMonitor {
    /// The default for previews and tests: a store with no mirror, so nothing
    /// is ever in flight. Shared because it's immutable in practice — it
    /// observes nothing and no one records events into it.
    static let notSyncing = SyncMonitor(mode: .localOnly)

    private(set) var phase: SyncPhase

    /// `nonisolated(unsafe)` because `deinit` isn't `MainActor`-isolated and
    /// this is the only thing it touches. Written once during `init`, read
    /// once during `deinit`, never concurrently.
    ///
    /// `@ObservationIgnored` is load-bearing, not decoration: without it the
    /// `@Observable` macro rewrites this into a computed property, where
    /// `nonisolated(unsafe)` means nothing — which is what the Xcode 27
    /// compiler warns about, and its fixit (plain `nonisolated`) doesn't
    /// compile on a mutable stored property. A notification token is not
    /// state any view should re-render on, so keeping it out of observation
    /// is what was meant all along.
    @ObservationIgnored private nonisolated(unsafe) var observer: (any NSObjectProtocol)?

    /// Called on the main actor whenever this device's copy is known current
    /// or known to be the only copy (`009`, plan Q3) — the sell plan's
    /// carry-over runs here. A `let`, so observation ignores it.
    private let onSettled: (() -> Void)?

    /// - Parameters:
    ///   - mode: anything but `.cloudKit` starts (and stays) `.unavailable` —
    ///     there's no mirror, so nothing is in flight and an empty collection
    ///     is the whole truth. This is what saves every caller from having to
    ///     check the mode itself.
    ///   - onSettled: called once here for `.ephemeral` — an in-memory store no
    ///     other device can touch — and **never** here for `.localOnly`: that
    ///     is the synced store opened without its mirror for one launch, so a
    ///     write made now would export next launch from a copy of unknown age.
    ///     Skipping costs one launch. After that, see `record(_:)`.
    init(mode: StorageMode, onSettled: (() -> Void)? = nil) {
        self.onSettled = onSettled
        phase = mode == .cloudKit ? .unknown : .unavailable
        if mode == .ephemeral { settle() }
        guard mode == .cloudKit else { return }

        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = Self.event(from: notification) else { return }
            MainActor.assumeIsolated { self?.record(event) }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// How many imports have landed.
    ///
    /// The screens need this as well as `phase`, because they don't observe
    /// the store — each view model fetches on appear and holds an array (see
    /// plan.md's Loading states section). Without a nudge, a device that spent
    /// the import window on "Catching up with iCloud" would reach `.caughtUp`
    /// and switch to "No gear yet" over a store that had just filled with two
    /// hundred items: the same false claim as before, moved later.
    ///
    /// A count rather than a flag because a long first import arrives in
    /// several passes, and "it'll appear here as it arrives" should mean it.
    private(set) var completedImports = 0

    /// How many times `onSettled` has run — bumped right after each call.
    ///
    /// The Dashboard and the Plans tab reload on this as well as on
    /// `completedImports`, because a failed setup settles without moving the
    /// import count: without it, the launch tab would keep a stale zero.
    private(set) var settledCount = 0

    /// The hook fires on two **events**, not on the `.unavailable` edge:
    /// `phase(after:from:)` maps *any* finished failure to `.unavailable`, a
    /// failed import included — and a failed import is exactly the case where
    /// this device's copy may be stale, so it must never settle.
    ///
    /// - A successful import: the copy is current.
    /// - A finished failed setup: the signed-out signature T051 recorded, where
    ///   no import ever follows, so this device's copy is the only one.
    ///
    /// The hook runs **before** `completedImports` moves, by construction
    /// rather than by the unspecified order of two `onChange` handlers, so a
    /// screen refetching on the bump already sees what the hook wrote.
    func record(_ event: SyncEvent) {
        phase = Self.phase(after: event, from: phase)
        let imported = event.kind == .importChanges && event.isFinished && event.succeeded
        let signedOut = event.kind == .setup && event.isFinished && !event.succeeded
        if imported || signedOut { settle() }            // never on a failed import
        if imported { completedImports += 1 }            // after the hook
    }

    /// The hook, then the count.
    private func settle() {
        onSettled?()
        settledCount += 1
    }

    /// What the four empty-state call sites actually ask. `.unknown` counts:
    /// not having heard from CloudKit is a reason to hold off on claiming the
    /// collection is empty, not a reason to assume it.
    var mayStillBeImporting: Bool {
        phase == .unknown || phase == .working
    }

    // MARK: - The rule

    /// `.caughtUp` is the one absorbing state. Once an import has landed,
    /// this device has the collection, and a later import going by is no
    /// reason to start doubting an empty screen again — otherwise every
    /// routine sync would flicker "still catching up" over a list that's
    /// empty because it really is.
    ///
    /// `.unavailable` is deliberately *not* absorbing: an account can be
    /// signed into, and a network can come back, without relaunching.
    ///
    /// Exports say nothing about whether incoming data is complete — they're
    /// this device's own changes going the other way — so they're ignored
    /// rather than treated as activity.
    static func phase(after event: SyncEvent, from current: SyncPhase) -> SyncPhase {
        guard current != .caughtUp else { return .caughtUp }

        switch (event.kind, event.isFinished, event.succeeded) {
        case (.exportChanges, _, _):
            return current
        case (_, false, _):
            return .working
        case (.importChanges, true, true):
            return .caughtUp
        // Setup succeeding means the mirror is running, not that anything has
        // arrived yet — the import it triggers is a separate event.
        case (.setup, true, true):
            return .working
        case (_, true, false):
            return .unavailable
        }
    }

    // MARK: - The framework edge

    /// The one place `NSPersistentCloudKitContainer` is touched.
    ///
    /// **A flagged layering exception.** SwiftData is the public API this app
    /// is built on, and it publishes nothing about sync progress; the events
    /// come from the Core Data container underneath it. Verified at T051
    /// against a real launch — the notification does fire for a SwiftData
    /// container — rather than assumed from the class name.
    nonisolated static func event(from notification: Notification) -> SyncEvent? {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return nil }

        let kind: SyncEvent.Kind? = switch event.type {
        case .setup: .setup
        case .import: .importChanges
        case .export: .exportChanges
        @unknown default: nil
        }
        guard let kind else { return nil }

        return SyncEvent(
            kind: kind,
            isFinished: event.endDate != nil,
            succeeded: event.succeeded
        )
    }
}
