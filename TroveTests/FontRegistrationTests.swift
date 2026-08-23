import CoreText
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// `Font.custom` falls back to the system font when a name isn't registered,
/// silently — a typo'd PostScript name, a file missing from `UIAppFonts`, or a
/// renamed `.ttf` all look exactly like "the design just isn't applied yet".
/// That's the failure this suite exists to make loud.
@Suite("Font registration")
struct FontRegistrationTests {
    private var registeredNames: Set<String> {
        let names = CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? []
        return Set(names)
    }

    @Test func everyFaceTheThemeAsksForIsRegistered() {
        let missing = ThemeTypography.requiredPostScriptNames
            .filter { !registeredNames.contains($0) }

        #expect(
            missing.isEmpty,
            """
            Not registered: \(missing.joined(separator: ", ")).
            Add the .ttf under Trove/Fonts and list it in UIAppFonts \
            (Config/Info.plist), or the app renders on system faces instead.
            """
        )
    }

    /// Guards the switch-over itself: with the flag off, everything above is
    /// moot because nothing asks for a custom face.
    @Test func customFontsAreTurnedOn() {
        #expect(ThemeTypography.customFontsInstalled)
    }

    /// The three roles resolve to three different families. Catches the case
    /// where names are registered but every role points at the same one.
    @Test func theThreeRolesUseThreeDifferentFamilies() {
        let display = FontFamily.display.postScriptName(for: .semibold)
        let body = FontFamily.body.postScriptName(for: .regular)
        let mono = FontFamily.mono.postScriptName(for: .regular)

        #expect(Set([display, body, mono]).count == 3)
    }

    /// Mono ships 400 and 500 per tokens.md. This collapsed to a single face
    /// for a while when IBMPlexMono-Medium.ttf was missing, and the only
    /// symptom was `monoValue` and `monoLabel` rendering slightly light —
    /// invisible unless you were looking for it.
    @Test func monoWeightsResolveToDistinctFaces() {
        let regular = FontFamily.mono.postScriptName(for: .regular)
        let medium = FontFamily.mono.postScriptName(for: .medium)

        #expect(regular != medium)
    }

    /// Body weights have to be distinct faces, not one face plus a synthesized
    /// weight — that's why separate files ship.
    @Test func bodyWeightsResolveToDistinctFaces() {
        let regular = FontFamily.body.postScriptName(for: .regular)
        let medium = FontFamily.body.postScriptName(for: .medium)
        let semibold = FontFamily.body.postScriptName(for: .semibold)

        #expect(Set([regular, medium, semibold]).count == 3)
    }
}
