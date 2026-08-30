import SwiftUI

/// Every color the app is allowed to draw with, named for what it means
/// rather than what it looks like. Transcribed from `design/tokens.md`; the
/// values are pinned by `ThemeColorTokenTests`.
///
/// v1 ships one instance (`.dark`). A light mode or an alternate palette is a
/// second instance injected into the environment — see plan.md's "Future:
/// theming" — which only works if no view ever reaches past this type for a
/// color. `NoHardcodedColorsTests` enforces that.
struct ThemeColors: Sendable {
    let background: Color
    let surface: Color
    let surfaceInset: Color
    let divider: Color

    let textPrimary: Color
    let textBody: Color
    let textLabel: Color
    let textLabelSecondary: Color
    let textMonoMeta: Color
    let textQuiet: Color
    let textDisabled: Color
    let textInactive: Color

    /// Primary accent — value figures and CTAs.
    let accentBrass: Color
    let accentBrassHover: Color
    /// Brass held back for repeated marks that would shout in full strength —
    /// the dashboard ruler's minor ticks, where only the majors are at full.
    let accentBrassDim: Color
    /// Background wash for selected rows and chips.
    let accentBrassTint: Color

    /// Secondary accent. **Strokes, borders and fills only** — it fails
    /// contrast on `surface` as text. Use `accentMossText` there instead.
    let accentMoss: Color
    /// The contrast-safe lift of `accentMoss`, for when moss has to be text.
    let accentMossText: Color

    /// Low-desire / sell-candidate accent. **Strokes, borders and fills
    /// only**, for the same contrast reason as `accentMoss`.
    let accentRust: Color
    /// The contrast-safe lift of `accentRust`, for when rust has to be text.
    let accentRustText: Color

    /// The desire dial's middle of range, between rust and moss.
    let dialMidpoint: Color

    /// The neutral the dashboard's breakdown falls back to once the three
    /// accents are spent — "everything else", not a category of its own.
    let categoryNeutral: Color

    /// The extruded-plate treatment's three alphas (`010`, tokens.md's "Row
    /// treatment" table) — depth layered over `surface` from ivory and black
    /// alphas, never a new hue, which is what keeps the plate inside
    /// `brief.md`'s amended skeuomorphism boundary.
    /// The 1px inner top edge that catches the light.
    let plateHighlight: Color
    /// The 1px inner bottom edge that falls into shadow.
    let plateEdgeShadow: Color
    /// The soft shadow the plate casts on the background.
    let plateCastShadow: Color

    /// Swatches for the dashboard's category breakdown, in assignment order.
    /// Three accents to tell the largest categories apart, then
    /// `categoryNeutral` for the tail, matching Design's mock.
    var categorySwatches: [Color] { [accentBrass, accentRust, accentMoss] }
}

extension ThemeColors {
    /// The warm ivory every text token is a percentage of.
    private static let ink = "#F2EDE4"

    static let dark = ThemeColors(
        background: Color(hex: "#17181A"),
        surface: Color(hex: "#201F1D"),
        surfaceInset: Color(hex: "#26272A"),
        divider: Color(hex: "#3A3B3E"),

        textPrimary: Color(hex: ink),
        textBody: Color(hex: ink, opacity: 0.75),
        textLabel: Color(hex: ink, opacity: 0.60),
        textLabelSecondary: Color(hex: ink, opacity: 0.55),
        textMonoMeta: Color(hex: ink, opacity: 0.45),
        textQuiet: Color(hex: ink, opacity: 0.40),
        textDisabled: Color(hex: ink, opacity: 0.35),
        textInactive: Color(hex: ink, opacity: 0.30),

        accentBrass: Color(hex: "#C79A56"),
        accentBrassHover: Color(hex: "#DDB877"),
        accentBrassDim: Color(hex: "#746140"),
        accentBrassTint: Color(hex: "#C79A56", opacity: 0.12),

        accentMoss: Color(hex: "#52634F"),
        accentMossText: Color(hex: "#7E9679"),

        accentRust: Color(hex: "#9C4A34"),
        accentRustText: Color(hex: "#B8674F"),

        // Retuned twice since the dial's "keep" end moved from brass to moss,
        // both times by searching an Oklab model of the ramp rather than
        // picking a hex by eye. #A87C4A was the middle of the old rust→brass
        // ramp and left everything up to 4 in orange; #75774A fixed the hue
        // cliff but sat too dark and grey to read as anything but green's
        // neighbour. See `design/tokens.md` for the measurements.
        dialMidpoint: Color(hex: "#8F8C38"),

        categoryNeutral: Color(hex: "#6B6C6F"),

        plateHighlight: Color(hex: ink, opacity: 0.055),
        plateEdgeShadow: Color(hex: "#000000", opacity: 0.40),
        plateCastShadow: Color(hex: "#000000", opacity: 0.50)
    )
}
