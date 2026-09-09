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

    /// `.system` resolves to the concrete device scheme the caller reads — the
    /// Settings sheet never gets a nil (T009's SwiftUI refresh-bug avoidance).
    /// Routing `.system` through the nil-prone `preferredColorScheme` (which
    /// hands back nil) fails to compile against the `ColorScheme` return type,
    /// and returning the wrong scheme here — e.g. `.dark` for both devices —
    /// turns one of these two rows red.
    @Test func systemSheetSchemeFollowsTheDevice() {
        #expect(AppearanceChoice.system.sheetColorScheme(device: .dark) == .dark)
        #expect(AppearanceChoice.system.sheetColorScheme(device: .light) == .light)
    }

    /// An explicit `.light` sheet scheme ignores the device scheme.
    @Test func explicitLightSheetSchemeIgnoresTheDevice() {
        #expect(AppearanceChoice.light.sheetColorScheme(device: .light) == .light)
        #expect(AppearanceChoice.light.sheetColorScheme(device: .dark) == .light)
    }

    /// An explicit `.dark` sheet scheme ignores the device scheme.
    @Test func explicitDarkSheetSchemeIgnoresTheDevice() {
        #expect(AppearanceChoice.dark.sheetColorScheme(device: .light) == .dark)
        #expect(AppearanceChoice.dark.sheetColorScheme(device: .dark) == .dark)
    }

    @Test func displayNameIsTheUserFacingCopy() {
        #expect(AppearanceChoice.system.displayName == "System")
        #expect(AppearanceChoice.light.displayName == "Light")
        #expect(AppearanceChoice.dark.displayName == "Dark")
    }
}
