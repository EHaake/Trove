import Foundation

/// What the person picked in Settings for the app's light/dark appearance.
///
/// A plain model, per the constitution: no SwiftUI import. The SwiftUI mapping
/// (`preferredColorScheme`, `resolvedTheme(systemColorScheme:)`) lives in
/// `AppearanceChoice+Theme.swift`, which may import SwiftUI (plan.md Q1).
enum AppearanceChoice: String, CaseIterable, Sendable {
    case system, light, dark

    /// The only user-facing copy this type owns.
    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
