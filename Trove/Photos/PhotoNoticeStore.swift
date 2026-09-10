import Foundation

/// Whether the one-time "finding a photo sends this item's name" notice
/// (spec §5, criterion 9) has been acknowledged. A `nonisolated` protocol so
/// the view model can hold it without actor hops, mirroring how
/// `StockPhotoService` is declared; constructor-injected as
/// `(any PhotoNoticeStore)? = nil` → `UserDefaultsPhotoNoticeStore` at the
/// call site, and faked in tests.
nonisolated protocol PhotoNoticeStore: Sendable {
    var hasAcknowledged: Bool { get }
    func acknowledge()
}

/// The live store: one bool key in `UserDefaults`, per-device and unsynced
/// (criterion 9's "stored on the device and does not sync"). A missing key
/// reads `false`; a read that fails reads as *not acknowledged* — the safe
/// direction, where the notice shows once more rather than being suppressed.
nonisolated final class UserDefaultsPhotoNoticeStore: PhotoNoticeStore {
    private static let key = "stockPhotoNoticeAcknowledged"

    /// `nonisolated(unsafe)` because `UserDefaults` isn't `Sendable`, though
    /// it is documented thread-safe; the store holds it immutably and only
    /// reads/writes one key.
    private nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasAcknowledged: Bool {
        defaults.bool(forKey: Self.key)
    }

    func acknowledge() {
        defaults.set(true, forKey: Self.key)
    }
}

extension UserDefaultsPhotoNoticeStore {
    /// A UI-test launch must start with the notice unacknowledged — the same
    /// controlled start `-uiTesting` gives the SwiftData store. This flag lives
    /// in `UserDefaults`, which `-uiTesting` does not otherwise reset, so the
    /// in-memory launch clears it once at startup.
    ///
    /// **Structurally bound** (CLAUDE.md's 003 amendment): gated on the store
    /// the app actually built being the in-memory one, never on a second read
    /// of the launch argument — so a persistent store keeps the person's
    /// acknowledgement even if the argument were present, and a test can show
    /// it refusing. Its only possible effect is losing that one flag for that
    /// one launch (the T050 bound). `.ephemeral` is UI-tests-only, so a shipped
    /// launch never reaches this.
    static func shouldResetForUITesting(mode: StorageMode) -> Bool {
        // Pattern match rather than `==`: this extension is `nonisolated` (like
        // its class), and `StorageMode`'s `Equatable` conformance is
        // MainActor-isolated, so `==` isn't usable here. A `case` match needs
        // no conformance and reads the same.
        if case .ephemeral = mode { true } else { false }
    }

    /// Clears the acknowledgement iff the built store is the in-memory one.
    static func resetForUITesting(mode: StorageMode, defaults: UserDefaults = .standard) {
        guard shouldResetForUITesting(mode: mode) else { return }
        defaults.removeObject(forKey: key)
    }
}
