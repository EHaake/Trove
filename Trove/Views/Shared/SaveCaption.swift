import SwiftUI

/// How the app's store is configured, for the views that have something
/// truthful to say about it.
///
/// Injected rather than read from a global so previews and tests can set it,
/// and declared here rather than beside `StorageMode` because `TroveStore` is
/// the storage layer and has no business importing SwiftUI. The default is
/// `.cloudKit` — the mode every real launch asks for, so a preview shows what
/// a person would actually see.
extension EnvironmentValues {
    @Entry var storageMode: StorageMode = .cloudKit
}

/// The line under the save button, which says where a saved record ends up.
///
/// It used to say "on this device" unconditionally. That was true for the
/// whole of v1's development and became false the moment T002 turned sync on
/// — the kind of sentence that goes stale silently, because nothing about a
/// hardcoded string knows the store underneath it changed.
enum SaveCaption {
    /// - Parameter noun: "library" or "wishlist" — the two screens keep their
    ///   own word for the collection, as they do everywhere else.
    ///
    /// **`.cloudKit` means the container is configured for sync, not that the
    /// user is signed in.** Nothing here asks about the account — that's
    /// `TroveStore`'s deliberate design, and T049 confirmed a signed-out
    /// launch takes the identical path. So the syncing copy is written to be
    /// true either way: "if signed in" is doing real work, not hedging.
    /// Promising "syncs across your devices" to someone with no iCloud
    /// account would just swap one false claim for another.
    ///
    /// `.ephemeral` shares the local-only wording. It's a UI-test store that
    /// doesn't outlive the process, so "on this device" is if anything
    /// generous — but it never reaches a person, and giving it a third string
    /// would mean maintaining copy nobody reads.
    static func text(for mode: StorageMode, noun: String) -> String {
        switch mode {
        case .cloudKit:
            "Saves to your \(noun), iCloud if signed in"
        case .localOnly, .ephemeral:
            "Saves to your \(noun) on this device"
        }
    }
}
