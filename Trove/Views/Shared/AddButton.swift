import SwiftUI

/// The add action on a list screen — a prominent Liquid Glass button tinted
/// brass, floating over the content at the bottom-right.
///
/// **What `018` made it, and why** (spec Decision 14, plan §5 Q4): it is the
/// one control in the app that floats over scrolling content — where Apple
/// puts glass, and where the material actually refracts the rows passing
/// beneath it — and iOS 26's own compose buttons are glass discs in the same
/// corner. So the drawn brass disc and its shadow went, and the system's
/// `.glassProminent` style is the surface: a circle border shape, tinted
/// `accentBrass`, with the plus taking the style's own foreground. It kept
/// its size (56 × 56), its place, its plus and its label —
/// `testTheAddButtonKeepsItsSizeAndPlace` measured the disc before the
/// restyle and holds the glass to the same frame on both lists.
///
/// Brass rather than the header badges' `.primary` tint: this is the one
/// prominent action on the screen, and the brass fill is what says so.
///
/// Bottom-right rather than the centre slot of a five-tab bar Design drew:
/// v1 ships without that slot, and bottom-right beats a top-corner toolbar
/// button for one-handed reach. See `001`'s plan.md, Navigation section.
///
/// Positioning is the caller's: this is just the button, so each screen
/// states its own `.overlay(alignment: .bottomTrailing)` and insets.
struct AddButton: View {
    /// What the button adds, for VoiceOver — "Add item", "Add wanted item".
    let label: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            // Sized so the rendered circle is 56 × 56, the disc's size: the
            // prominent glass circle adds 7 pt around its label, so a 42 pt
            // label comes out at 56 (measured on the iOS 27.0 simulator; a
            // 60 pt label came out at 74).
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(theme.colors.accentBrass)
        .accessibilityLabel(label)
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        AddButton(label: "Add item") {}
    }
    .environment(\.theme, .dark)
}
