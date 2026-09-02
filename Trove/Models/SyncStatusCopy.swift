import Foundation

/// What the Settings screen's iCloud row shows: a headline and a detail
/// line, computed from what the app already knows — how the store was
/// configured, why it fell back if it did, and what the sync monitor has
/// heard — and nothing it would have to ask iCloud for (013).
struct SyncStatus: Equatable, Sendable {
    let headline: String
    let detail: String
}

/// The truth about where the collection is and whether it's moving, in the
/// save captions' voice: being configured for iCloud says nothing about
/// being signed in, so no state may claim another device has the
/// collection (spec criterion 10). `SyncStatusCopyTests` pins every cell of
/// the (mode, phase, reason) table as a whole string.
enum SyncStatusCopy {
    static func status(mode: StorageMode, phase: SyncPhase, fallbackReason: String?) -> SyncStatus {
        switch mode {
        case .cloudKit:
            switch phase {
            case .caughtUp:
                return SyncStatus(
                    headline: "Syncing with iCloud",
                    detail: "This device has your collection."
                )
            case .unknown, .working:
                // The empty states' own headline, so the two surfaces
                // describe one condition in one voice.
                return SyncStatus(
                    headline: "Catching up with iCloud",
                    detail: "Your collection is on its way to this device."
                )
            case .unavailable:
                // Signed out and unreachable are indistinguishable from
                // here — `SyncMonitor`'s doc records why — so the row names
                // both rather than guessing at one.
                return SyncStatus(
                    headline: "iCloud isn't available",
                    detail: "No iCloud account is signed in, or iCloud can't be reached. "
                        + "Your collection stays on this device."
                )
            }
        case .localOnly, .ephemeral:
            // The detail hangs on whether a reason was *recorded*, never on
            // the mode: a fallback always records one, and the UI-test
            // store — which never attempted iCloud — has none. Claiming a
            // failed setup for it would be stating something that didn't
            // happen.
            let detail = fallbackReason.map {
                "iCloud couldn't be set up when Trove launched: \($0)"
            } ?? "Nothing syncs from here."
            return SyncStatus(headline: "On this device only", detail: detail)
        }
    }
}
