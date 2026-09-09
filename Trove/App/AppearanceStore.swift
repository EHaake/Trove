import Foundation

/// The app-level home of the appearance choice, mirroring `SyncMonitor`'s
/// shape: one `@Observable` instance the root and Settings both hold, so a
/// change propagates by observation with no relaunch (spec criteria 3, 4).
///
/// The choice is stored in `UserDefaults` — per-device and readable
/// synchronously before the SwiftData store is built, so the first frame draws
/// in the right palette. It is deliberately **not** mirrored to CloudKit: a
/// choice made on one device does not change another (spec Decisions 3 and 4,
/// criterion 5). `AppStorage` is not the source of truth here; this concrete
/// instance is (plan.md Q2).
@Observable
final class AppearanceStore {
    var choice: AppearanceChoice {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// The single `UserDefaults` key this store reads and writes. Exposed at
    /// module scope (not `private`) so `AppearanceStoreTests` can set exactly
    /// the key the store genuinely reads, rather than re-declaring a matching
    /// literal that could silently drift out of step and pass vacuously.
    static let defaultsKey = "appearanceChoice"

    /// Reads the stored raw value now, defaulting to `.dark` when the key is
    /// absent (a fresh or upgrading install) or holds a string this version
    /// doesn't recognise (spec criterion 6).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.defaultsKey)
        choice = raw.flatMap(AppearanceChoice.init(rawValue:)) ?? .dark
    }

    private func persist() {
        defaults.set(choice.rawValue, forKey: Self.defaultsKey)
    }
}
