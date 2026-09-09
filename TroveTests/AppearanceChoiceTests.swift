import SwiftUI
import Testing
@testable import Trove

/// The enum's copy and its SwiftUI mapping (plan.md Q1). `resolvedTheme` is
/// the load-bearing rule: an explicit `.light`/`.dark` choice ignores the
/// system scheme, and only `.system` follows it (guard G1).
@Suite("Appearance choice")
struct AppearanceChoiceTests {
    /// Which palette a resolved theme carries, read off `background` — the two
    /// palettes differ there (0xEC… light, 0x17… dark), so it tells them apart
    /// without `Theme` needing to be `Equatable`.
    private func isLightPalette(_ theme: Theme) -> Bool {
        theme.colors.background == ThemeColors.light.background
    }

    private func isDarkPalette(_ theme: Theme) -> Bool {
        theme.colors.background == ThemeColors.dark.background
    }

    @Test func preferredColorSchemeMapsEachCase() {
        #expect(AppearanceChoice.system.preferredColorScheme == nil)
        #expect(AppearanceChoice.light.preferredColorScheme == .light)
        #expect(AppearanceChoice.dark.preferredColorScheme == .dark)
    }

    /// An explicit `.light` resolves to the light palette regardless of the
    /// system scheme — the resolver must not read `colorScheme` here (G1:
    /// making `.light` consult `colorScheme` turns the `.dark`-system row red).
    @Test func explicitLightIgnoresTheSystemScheme() {
        #expect(isLightPalette(AppearanceChoice.light.resolvedTheme(systemColorScheme: .light)))
        #expect(isLightPalette(AppearanceChoice.light.resolvedTheme(systemColorScheme: .dark)))
    }

    /// An explicit `.dark` resolves to the dark palette regardless of the
    /// system scheme.
    @Test func explicitDarkIgnoresTheSystemScheme() {
        #expect(isDarkPalette(AppearanceChoice.dark.resolvedTheme(systemColorScheme: .light)))
        #expect(isDarkPalette(AppearanceChoice.dark.resolvedTheme(systemColorScheme: .dark)))
    }

    /// `.system` follows the live system scheme (G1: inverting the branch
    /// swaps these two).
    @Test func systemFollowsTheSystemScheme() {
        #expect(isLightPalette(AppearanceChoice.system.resolvedTheme(systemColorScheme: .light)))
        #expect(isDarkPalette(AppearanceChoice.system.resolvedTheme(systemColorScheme: .dark)))
    }

    @Test func displayNameIsTheUserFacingCopy() {
        #expect(AppearanceChoice.system.displayName == "System")
        #expect(AppearanceChoice.light.displayName == "Light")
        #expect(AppearanceChoice.dark.displayName == "Dark")
    }
}
