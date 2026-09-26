import SwiftUI

/// 018: Sort By's two strings. Not on `SortMenu` — a generic type can't hold
/// stored statics (`009` Q14's finding).
enum SortMenuCopy {
    static let header = "Sort by"
    /// The badges' label type — Sort By's label, and the line box that sets
    /// the "…" glyph row's height in `OverflowMenu`, so the two capsules are
    /// one height (`018` G1). One source, so the two can't drift.
    static let labelFont = ThemeTypography.font(.mono, size: 11)
    /// P3: what the REORDER tag became — the manual-order row's subtitle,
    /// drawn by the system under the row's title whether or not it is the
    /// selected sort.
    static let reorderSubtitle = "Drag rows to reorder"
}

/// 018: Sort By — a Liquid Glass button opening the system menu, one row
/// per option under one "Sort by" header, the current option checked (spec
/// "Sort By", plan §1).
///
/// Replaces `SortBadge` + `SortDropdown` screen by screen. One per side on a
/// two-sided screen, each over its side's own options and selection, so the
/// label is always the selection of the menu it opens. Generic over
/// `Hashable` rather than `Identifiable` so the header's render test can
/// build one over bare strings (plan Q1).
///
/// **Its label is in the system's primary label colour** (spec Decisions 15
/// and 17, overtaking R3) — the default monochrome label the guidelines ask
/// for on Liquid Glass, matching the system menu it opens. The glass style
/// paints its label with the button's tint and ignores the label's own
/// foreground, so the colour arrives as the button's tint, set to the
/// primary style directly after the glass style, overriding the root brass
/// tint. The glyph's bars are primary-coloured views rather than shapes: a
/// shape under the hierarchical tint draws dimmed on the device, a colour
/// view at full strength. Never a theme colour: `HeaderControlsWiringTests`
/// (G2) pins the tint's place and that this file names no theme colour;
/// `NoHardcodedColorsTests` lets exactly those two lines through.
///
/// **Its width follows its label** (spec Decision 18, withdrawing P4): the
/// capsule is sized to the current option's text, and the glass style's own
/// horizontal padding gives the glyph and the text equal insets (12.33 pt
/// left, 13.33 pt right on iOS 27.0) with no padding of the app's own. The
/// price is recorded, not hidden: on iOS 26.5 a menu-driven relabel from a
/// narrow option to a wider one leaves the capsule at the old width for about
/// 1.4 s (Date → Market ↓: 41 pt under a 54 pt label from +0.3 s to +1.4 s),
/// then it snaps to the right width in one frame; wide to narrow morphs
/// correctly, and iOS 27.0 is clean. Resetting the menu's identity on each
/// selection removes that, but it replaces the system's menu-to-button morph
/// with a crossfade on both runtimes; the person kept the morph — it is the
/// standard iOS behaviour, and a menu button that looks standard should
/// behave so — and accepted the 26.5 transient, which T009 films and times.
struct SortMenu<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    /// The option whose row carries "Drag rows to reorder" — nil where the
    /// list has no manual order (Items' Sold side, both Plans sides).
    var manualOrder: Option? = nil
    let select: (Option) -> Void

    var body: some View {
        Menu {
            // Q8: one "Sort by" header over checkmark rows. A `Toggle` row is
            // what iOS draws checked and announces as selected; its setter
            // re-selects on any tap, so there is no turning a sort off. A
            // second `Text` is the row's subtitle.
            Section(SortMenuCopy.header) {
                ForEach(options, id: \.self) { option in
                    Toggle(isOn: Binding(get: { option == selection },
                                         set: { _ in select(option) })) {
                        Text(label(option))
                        if option == manualOrder { Text(SortMenuCopy.reorderSubtitle) }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                // The three-bar sort glyph at `SortBadge`'s token widths.
                VStack(alignment: .leading, spacing: 2.5) {
                    bar(width: 10)
                    bar(width: 7)
                    bar(width: 4)
                }
                // Sized to the selection's text (Decision 18).
                Text(label(selection))
                    .font(SortMenuCopy.labelFont)
            }
            // Q6 as overtaken by spec Decision 17: 4 pt above and below the
            // label, so the capsule sits between the system's two sizes.
            .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        // Decision 17: the glass style paints the label with the tint, so the
        // system's label colour, not the root tint's brass, is set here.
        .tint(.primary)
        // Q6 as overtaken by spec Decision 17: the system's regular control
        // size with the label's padding above — the capsule the person chose
        // from rendered candidates. The badge row, not the Items title's line
        // box, sets the header's height, equally on both sides
        // (`ItemListHeaderLayoutTests`).
        .controlSize(.regular)
    }

    /// A colour view rather than a shape, so it draws at the tint's full
    /// primary with the text rather than dimmed (Decision 17).
    private func bar(width: CGFloat) -> some View {
        Color.primary
            .frame(width: width, height: 1.5)
    }
}
