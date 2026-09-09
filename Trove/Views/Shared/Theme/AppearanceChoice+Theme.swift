import SwiftUI

/// The SwiftUI side of `AppearanceChoice`, kept out of the model itself so the
/// enum imports no SwiftUI (plan.md Q1).
extension AppearanceChoice {
    /// What the root hands to `.preferredColorScheme` so system chrome follows
    /// the choice — `nil` for System, which lets the device decide.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// The CONCRETE colour scheme the Settings sheet adopts so its own system
    /// chrome follows the choice on a live switch. Never nil: passing nil to a
    /// presented sheet's .preferredColorScheme hits a documented SwiftUI
    /// refresh bug, so .system resolves to the device scheme the caller reads.
    func sheetColorScheme(device: ColorScheme) -> ColorScheme {
        switch self {
        case .system: device
        case .light: .light
        case .dark: .dark
        }
    }

    /// The palette to inject for this choice.
    ///
    /// An explicit `.light`/`.dark` choice **never** consults `colorScheme` —
    /// so the theme does not depend on `.preferredColorScheme` feeding back
    /// into the same view's `@Environment(\.colorScheme)`, a SwiftUI behaviour
    /// this plan does not want to rely on. Only `.system` reads the live system
    /// scheme, which is exactly the signal it should follow (plan.md Q1).
    func resolvedTheme(systemColorScheme: ColorScheme) -> Theme {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: systemColorScheme == .dark ? .dark : .light
        }
    }
}
