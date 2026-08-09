import SwiftUI

/// The three type roles from `design/tokens.md`.
enum FontFamily: Sendable {
    /// Archivo 600 — screen titles, hero figures, dial numerals.
    case display
    /// IBM Plex Sans — list text, labels, form fields.
    case body
    /// IBM Plex Mono — money, serial numbers, dates, all-caps labels.
    case mono

    var postScriptName: String {
        switch self {
        case .display: "Archivo-SemiBold"
        case .body: "IBMPlexSans-Regular"
        case .mono: "IBMPlexMono-Regular"
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
    /// Archivo and IBM Plex are both SIL Open Font License, so embedding them
    /// needs no licensing step — but the files aren't in the repo yet, so
    /// nothing can reference them.
    ///
    /// To switch over: add the `.ttf` files under `Trove/`, list them in the
    /// target's `UIAppFonts`, and flip this to `true`. Nothing else changes —
    /// that's the point of routing every size through this one type.
    static let customFontsInstalled = false

    let screenTitle: Font
    let heroFigure: Font
    let heroFigureSecondary: Font
    let dialNumeral: Font
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

    static func font(
        _ family: FontFamily,
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {
        guard customFontsInstalled else {
            return .system(size: size, weight: weight, design: family.systemFallbackDesign)
        }
        return .custom(family.postScriptName, fixedSize: size).weight(weight)
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
        dialNumeral: font(.display, size: 26, weight: .semibold),
        formInput: font(.body, size: 19),
        rowTitle: font(.body, size: 15, weight: .medium),
        body: font(.body, size: 13.5),
        secondary: font(.body, size: 12.5),
        monoValue: font(.mono, size: 15, weight: .medium),
        monoMeta: font(.mono, size: 11.5),
        monoLabel: font(.mono, size: 10.5, weight: .medium)
    )
}
