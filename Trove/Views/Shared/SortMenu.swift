import SwiftUI

/// 018: Sort By's two strings. Not on `SortMenu` — a generic type can't hold
/// stored statics (`009` Q14's finding).
enum SortMenuCopy {
    static let header = "Sort by"
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
/// **It draws no colour of its own** (R3): the glyph's bars are unfilled
/// `Rectangle`s and the label carries no style, so both take the glass
/// style's foreground together, and brass arrives only through the root
/// tint where the style applies it. `HeaderControlsWiringTests` (G2) pins
/// that this file names no theme colour.
///
/// **Its footprint is constant** (spec P4): the label reserves the widest of
/// its menu's options, sized once, so choosing a row never changes the
/// badge's width. T002 filmed why: on iOS 26.5 the glass capsule keeps the
/// previous label's width after a menu-driven relabel until the next tap —
/// the label standing past the capsule's rim after a narrow-to-wide switch,
/// a stale wider shadow after a wide-to-narrow one. With no width to change,
/// the dismiss has none to animate. `ItemListHeaderLayoutTests` (G1) holds
/// every selection to one width.
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
                // P4's constant footprint: every option's label laid out
                // hidden under the visible one, so the badge is always as
                // wide as its widest option and a relabel changes no width.
                ZStack(alignment: .leading) {
                    ForEach(options, id: \.self) { option in
                        Text(label(option)).hidden()
                    }
                    Text(label(selection))
                }
                .font(ThemeTypography.font(.mono, size: 11))
            }
        }
        .buttonStyle(.glass)
        // Q6: the largest size whose badge stays under the Items title's
        // line box — 29 pt at `.regular` (25 at `.small`) against 33.
        .controlSize(.regular)
    }

    /// Unfilled, so it takes the style's foreground with the label (R3).
    private func bar(width: CGFloat) -> some View {
        Rectangle()
            .frame(width: width, height: 1.5)
    }
}
