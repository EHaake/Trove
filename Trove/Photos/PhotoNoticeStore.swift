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
