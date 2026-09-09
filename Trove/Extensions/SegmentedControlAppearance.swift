import SwiftUI
import UIKit

/// **Flagged UIKit exception**, per CLAUDE.md: a `.segmented` SwiftUI `Picker`
/// exposes no API for the *unselected* ("normal") segment title colour, and its
/// system default is a near-black that vanishes on the dark grey track in Dark
/// mode (004, T008). The only way to set that colour is
/// `UISegmentedControl`'s title-text attributes, reached through the appearance
/// proxy — so this one file owns the UIKit, and the view layer imports none.
///
/// The colour is driven entirely from `ThemeColors` — never a literal — and is
/// installed as a **dynamic** `UIColor` that resolves per rendered trait: Dark's
/// ivory `textPrimary` on the dark track, Light's near-black `textPrimary` on
/// the light track. Because it is dynamic (not a value frozen to one palette),
/// a live Light/Dark switch — which flips the control's trait with no relaunch —
/// re-resolves the labels on the spot. Only `.normal` is touched; the selected
/// segment's already-legible dark-on-light-pill rendering is left system-default.
///
/// **Single-control assumption / blast radius.** `UISegmentedControl.appearance()`
/// is a *process-global* proxy: this one install governs the `.normal` title
/// colour of every segmented control in the app, not just the Appearance
/// picker. Trove has exactly one segmented control (that picker), so the reach
/// is moot today; and were another added, it would inherit the same
/// high-contrast, trait-resolving label — a legible default, never a
/// regression. That benign blast radius is why a single startup install is
/// enough and no per-control targeting is needed.
enum SegmentedControlAppearance {
    /// The dynamic label colour for unselected segments: the highest-contrast
    /// text token from whichever palette matches the current trait. `textPrimary`
    /// is opaque in both themes, so it reads on the track without compositing.
    static func unselectedTitleColor(
        dark: ThemeColors = .dark,
        light: ThemeColors = .light
    ) -> UIColor {
        UIColor { traits in
            let colors = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(colors.textPrimary)
        }
    }

    /// Installs the dynamic unselected-title colour on the segmented-control
    /// appearance proxy. The proxy is read when a control is realized, so call
    /// this *before* any picker is built — `TroveApp.init` does, once at
    /// startup. Idempotent; the dynamic colour then tracks the trait for each
    /// control's whole lifetime, so it needs no re-install on a theme change.
    static func installUnselectedTitleColor(
        dark: ThemeColors = .dark,
        light: ThemeColors = .light
    ) {
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: unselectedTitleColor(dark: dark, light: light)],
            for: .normal
        )
    }
}
