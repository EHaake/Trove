import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Trove

/// Guards T008's fix: the colour the unselected Appearance segments draw in
/// must stay legible on the segmented-control track in *both* themes. The bug
/// was the system default reading near-black on Dark's dark grey track; the fix
/// drives the colour from `ThemeColors.textPrimary`, and this asserts that
/// choice clears a WCAG legibility bar — so a regression to a low-contrast token
/// turns it red rather than shipping the same defect back.
///
/// The track is a system material (`UISegmentedControl`'s `tertiarySystemFill`),
/// not a design token, so it can't be pinned the way `ThemeColors` is; the two
/// constants below are that fill composited over each theme's background,
/// documented as representative. The load-bearing part is the mutation check:
/// point the bridge at `textDisabled`/`textInactive` and both `#expect`s go red.
@Suite("Appearance segmented-control label contrast")
struct SegmentedControlContrastTests {
    /// `tertiarySystemFill` (118,118,128 @ 0.24) over the Dark background
    /// `#17181A` — a dark grey. Near-black labels disappear here; that was the
    /// bug.
    private let darkTrack = (r: 0x2E / 255.0, g: 0x2F / 255.0, b: 0x32 / 255.0)
    /// `tertiarySystemFill` (118,118,128 @ 0.12) over the Light background
    /// `#ECE7DC` — a light grey. Light labels would disappear here instead.
    private let lightTrack = (r: 0xDE / 255.0, g: 0xD9 / 255.0, b: 0xD1 / 255.0)

    /// WCAG 2.1 AA for normal-size text. `textPrimary` clears ~11:1 both ways,
    /// well clear; a translucent or ill-matched token drops under this.
    private let legibilityBar = 4.5

    private typealias RGB = (r: Double, g: Double, b: Double)

    /// The bridge's colour, resolved for one trait, then composited over the
    /// track (so an alpha < 1 blends into the track the way it renders).
    private func effectiveLabel(style: UIUserInterfaceStyle, over track: RGB) -> RGB {
        let color = SegmentedControlAppearance.unselectedTitleColor()
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let alpha = Double(a)
        return (
            r: alpha * Double(r) + (1 - alpha) * track.r,
            g: alpha * Double(g) + (1 - alpha) * track.g,
            b: alpha * Double(b) + (1 - alpha) * track.b
        )
    }

    private func relativeLuminance(_ c: RGB) -> Double {
        func linearize(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(c.r) + 0.7152 * linearize(c.g) + 0.0722 * linearize(c.b)
    }

    private func contrastRatio(_ foreground: RGB, _ background: RGB) -> Double {
        let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
        let darker = min(relativeLuminance(foreground), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    @Test func unselectedLabelIsLegibleOnTheDarkTrack() {
        let ratio = contrastRatio(effectiveLabel(style: .dark, over: darkTrack), darkTrack)
        #expect(ratio >= legibilityBar, "Dark unselected-label contrast \(ratio) is under \(legibilityBar):1")
    }

    @Test func unselectedLabelIsLegibleOnTheLightTrack() {
        let ratio = contrastRatio(effectiveLabel(style: .light, over: lightTrack), lightTrack)
        #expect(ratio >= legibilityBar, "Light unselected-label contrast \(ratio) is under \(legibilityBar):1")
    }

    /// The resolved RGBA of a colour under one trait, for exact comparison. Both
    /// sides of the wiring check run through the identical `UIColor(Color)` →
    /// `resolvedColor` conversion, so equal tokens compare bit-identical.
    private func rgba(_ color: UIColor, _ style: UIUserInterfaceStyle) -> (Double, Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    /// **Wiring guard.** The two contrast tests above call
    /// `unselectedTitleColor()` directly, so they stay green even when nothing
    /// installs it on the appearance proxy — the exact false-pass CLAUDE.md
    /// warns about, since removing the install brings the bug back while those
    /// still read the factory colour. This exercises the real path:
    /// `installUnselectedTitleColor()`, then read the `.normal` foreground back
    /// off the process-global `UISegmentedControl.appearance()` and confirm it
    /// resolves to `textPrimary` in both traits. Emptying `setTitleTextAttributes`
    /// (or removing the install) leaves the foreground unset and turns this red —
    /// mutation-verified.
    @Test func installSetsTheProxyNormalForegroundToTextPrimary() throws {
        // Self-contained: clear the process-global proxy first so a value a
        // prior test left can't mask a missing install — with the setter gone,
        // the `.normal` foreground then stays nil and this goes red.
        UISegmentedControl.appearance().setTitleTextAttributes(nil, for: .normal)

        SegmentedControlAppearance.installUnselectedTitleColor()

        let installed = try #require(
            UISegmentedControl.appearance()
                .titleTextAttributes(for: .normal)?[.foregroundColor] as? UIColor,
            "install left the .normal segment foreground unset"
        )

        let expected = SegmentedControlAppearance.unselectedTitleColor()
        for style in [UIUserInterfaceStyle.dark, .light] {
            #expect(
                rgba(installed, style) == rgba(expected, style),
                "installed \(style == .dark ? "dark" : "light") foreground is not textPrimary"
            )
        }
    }
}
