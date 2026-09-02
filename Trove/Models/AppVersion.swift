import Foundation

/// The running build's version and build number, for the Settings screen's
/// About section (013) — read from the bundle, never typed into a view, so
/// the screen can't go stale against the project's marketing version.
struct AppVersion: Equatable, Sendable {
    let version: String
    let build: String

    init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    /// From an Info dictionary — the app's first read of its own — with a
    /// visible "?" for a missing key rather than an empty string that would
    /// read as a layout bug.
    init(info: [String: Any]?) {
        version = info?["CFBundleShortVersionString"] as? String ?? "?"
        build = info?["CFBundleVersion"] as? String ?? "?"
    }

    static var current: AppVersion {
        AppVersion(info: Bundle.main.infoDictionary)
    }

    /// "Version 1.0 (1)" — the shape the About row prints.
    var display: String {
        "Version \(version) (\(build))"
    }
}
