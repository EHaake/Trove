import SwiftUI

/// 018: the header's "…" — a Liquid Glass button opening the system menu the
/// screen writes (spec "The '…' menus", plan §2). Spinner and inert while an
/// export or import runs.
///
/// Replaced the bespoke "…" badge and its dropdown (plan Q2). **No shared row
/// set**: the screen writes its own rows in the `@ViewBuilder` — the Items
/// list's export rows are submenus, the Wishlist's are buttons, and the
/// Dashboard's and Plans' menus are one row — so a shared four-row view would
/// be a switch over rows that differ in kind. Group breaks are `Divider()`s
/// and a gated row is `.disabled(…)`, the system's own separator and disabled
/// row; the system menu dismisses itself before a row's action runs.
///
/// **Styled exactly as `SortMenu` is, in the same order** (spec Decisions 15,
/// 16 and 17): the glass button style, then the system's primary label colour
/// as the button's tint — the glass style resolves a hierarchical foreground
/// such as the primary style against the tint, so on the label it would not
/// hold (an explicit colour would), and the colour has to arrive that way,
/// overriding the root brass tint — then the system's regular control size,
/// with 4 pt of padding above and below the label. The glyph row is one
/// hidden line of the sort badge's label type (`SortMenuCopy.labelFont`), so
/// the two badges render at one height (`ItemListHeaderLayoutTests`, G1). Never a theme colour; `ThemeTests`
/// lets exactly the one tint line through.
///
/// **One difference, its shape** (spec Decision 18): the "…" is a glass
/// circle, like the one in an item's detail, where Sort By stays a capsule
/// sized to its text. The circle's border shape sits between the glass style
/// and the tint; its hidden glyph row is 22 pt wide so the circle comes out
/// at the capsule's height (`HeaderControlsWiringTests`, G2, pins the shape;
/// G1 the height).
///
/// No accessibility hint (criterion 11): a menu's button announces itself as
/// a pop-up button, which is the job "Opens more actions" did for the bespoke
/// badge.
struct OverflowMenu<Content: View>: View {
    var isBusy = false
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            // The glyph row is one line of the sort badge's own label type,
            // laid out hidden, so its height is the sort badge's content row
            // exactly rather than a rounded literal (a 14 pt frame left the
            // capsule a third of a point short). The glyph or the spinner is
            // an overlay on it, so neither can grow the row.
            //
            // 22 pt wide because the button is a circle (spec Decision 18): a
            // glass circle's diameter is the label's width + 14.67, so 22
            // gives 36.67 × 36.33 — the sort capsule's height to the pixel.
            // 18 gave 32.67, four points short.
            Text(verbatim: "0")
                .font(SortMenuCopy.labelFont)
                .hidden()
                .frame(width: 22)
                .overlay {
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                // `SortMenu`'s label padding (Decision 17).
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        // Decision 18: a full circle, as the "…" in an item's detail is.
        .buttonBorderShape(.circle)
        // Decision 17: the system's label colour as the tint, as on the
        // sort badge beside it.
        .tint(.primary)
        .controlSize(.regular)
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Working" : "More actions")
    }
}
