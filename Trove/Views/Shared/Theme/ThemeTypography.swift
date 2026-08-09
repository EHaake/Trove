import SwiftUI

/// The three type roles from `design/tokens.md`.
enum FontFamily: Sendable {
    /// Archivo 600 — screen titles, hero figures, dial numerals.
    case display
    /// IBM Plex Sans — list text, labels, form fields.
    case body
    /// IBM Plex Mono — money, serial numbers, dates, all-caps labels.
    case mono

    /// The actual face for a weight, rather than one face with `.weight()`
    /// applied on top — that synthesizes an approximation instead of using the
    /// drawn one, which is the whole reason for shipping separate files.
    func postScriptName(for weight: Font.Weight) -> String {
        switch self {
        case .display:
            // tokens.md specifies Archivo 600 only.
            "Archivo-SemiBold"
        case .body:
            switch weight {
            case .semibold: "IBMPlexSans-SemiBold"
            case .medium: "IBMPlexSans-Medium"
            default: "IBMPlexSans-Regular"
            }
        case .mono:
            switch weight {
            case .medium: "IBMPlexMono-Medium"
            default: "IBMPlexMono-Regular"
            }
        }
    }

    /// What the system substitutes while the real faces are missing. Mono has
    /// to stay monospaced: the design leans on tabular figures to keep price
    /// columns aligned, and a proportional fallback would quietly break that.
    var systemFallbackDesign: Font.Design {
        switch self {
        case .display, .body: .default
        case .mono: .monospaced
        }
    }
}

/// Named type roles. Views ask for `theme.typography.rowTitle`, never for a
/// point size.
struct ThemeTypography: Sendable {
    /// The faces in `Trove/Fonts/` are registered through `UIAppFonts` in
    /// `Trove/Info.plist`. `FontRegistrationTests` asserts every name this
    /// type asks for is actually registered, because `Font.custom` falls back
    /// to the system font silently when it isn't — a typo'd PostScript name
    /// looks like nothing happened.
    ///
    /// Set to `false` to render the whole app on system faces.
    static let customFontsInstalled = true

    let screenTitle: Font
    let heroFigure: Font
    let heroFigureSecondary: Font
    let formInput: Font
    let rowTitle: Font
    let body: Font
    let secondary: Font
    /// Money.
    let monoValue: Font
    /// Serial numbers, dates.
    let monoMeta: Font
    /// All-caps section and field labels. Pair with `ThemeMetrics.monoLabelTracking`.
    let monoLabel: Font

    /// The dial's numeral, sized from the dial itself.
    ///
    /// One fixed size can't serve a 40pt dial in a list row and a 130pt one on
    /// the detail screen — at 26pt the numeral all but fills the small one.
    func dialNumeral(diameter: CGFloat) -> Font {
        Self.font(.display, size: max(diameter * 0.30, 11), weight: .semibold)
    }

    /// Every PostScript name the app can ask for. `UIAppFonts` has to list a
    /// file for each of these, and `FontRegistrationTests` checks that it does.
    static let requiredPostScriptNames: [String] = [
        FontFamily.display.postScriptName(for: .semibold),
        FontFamily.body.postScriptName(for: .regular),
        FontFamily.body.postScriptName(for: .medium),
        FontFamily.body.postScriptName(for: .semibold),
        FontFamily.mono.postScriptName(for: .regular),
        FontFamily.mono.postScriptName(for: .medium),
    ]

    static func font(
        _ family: FontFamily,
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        guard customFontsInstalled else {
            return .system(size: size, weight: weight, design: family.systemFallbackDesign)
        }
        return .custom(family.postScriptName(for: weight), fixedSize: size)
    }
}

extension ThemeTypography {
    /// Sizes are fixed rather than Dynamic Type-relative, matching the exact
    /// point values in `design/tokens.md`. Where tokens.md gives a range, the
    /// value here is the one that matches Design's own build; ranges resolve
    /// per-screen as those screens get built.
    static let standard = ThemeTypography(
        screenTitle: font(.display, size: 30, weight: .semibold),
        heroFigure: font(.display, size: 34, weight: .semibold),
        heroFigureSecondary: font(.display, size: 26, weight: .semibold),
        formInput: font(.body, size: 19),
        rowTitle: font(.body, size: 15, weight: .medium),
        body: font(.body, size: 13.5),
        secondary: font(.body, size: 12.5),
        monoValue: font(.mono, size: 15, weight: .medium),
        monoMeta: font(.mono, size: 11.5),
        monoLabel: font(.mono, size: 10.5, weight: .medium)
    )
}
