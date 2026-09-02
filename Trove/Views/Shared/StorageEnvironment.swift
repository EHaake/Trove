import SwiftUI

/// Why the store isn't `.cloudKit` when it isn't — the reason `TroveStore`
/// has recorded since `001` with nowhere to say it, until the Settings
/// screen's iCloud row (013).
///
/// A string rather than the error itself: an environment value wants a
/// default and equality, and the only thing a screen can do with the
/// reason is show it. Declared here rather than beside `storageMode` in
/// `SaveCaption.swift` because that file is named for a caption that never
/// reads this key; the two keys share a concern, not a consumer.
extension EnvironmentValues {
    @Entry var storageFallbackReason: String? = nil
}
