import SwiftUI

/// 018: a list screen's two sides as one glass button in the header's control
/// row (spec Decision 19) — the current side as an SF Symbol and its word,
/// and a tap shows the other side. It opens no menu.
///
/// The Items tab's Owned / Sold (`006`) and the Plans tab's Active /
/// Completed (`009`), generic over each screen's own side type, with one
/// constrained `init(side:select:)` per screen below so each call site names
/// only its side and its tap, and every word, glyph, label and identifier
/// lives here.
///
/// **Styled exactly as `OverflowMenu` is, minus the circle**: the glass
/// button style, then the system's primary label colour as the button's
/// tint (the glass style paints its label with the tint, overriding the root
/// brass tint), then the system's regular control size, with 4 pt of padding
/// above and below the label. The word is in the badges' label type
/// (`SortMenuCopy.labelFont`), and the label stands in one hidden line of
/// that type, so the three controls in the row render at one height
/// (`ItemListHeaderLayoutTests`, G1). Never a theme colour; `ThemeTests`
/// lets exactly the one tint line through.
///
/// **It never writes the side.** `ItemListViewModel.side` is `private(set)`,
/// so a tap asks `select` for the other side and the screen's `show(_:)`
/// decides what that means — `PlansViewModel` the same way.
struct SideToggle<Side: Hashable>: View {
    /// The side showing.
    let side: Side

    /// The two sides, with each one's word and glyph.
    let leading: Side, leadingLabel: String, leadingIcon: String
    let trailing: Side, trailingLabel: String, trailingIcon: String

    /// The pair's VoiceOver label and UI-test identifier.
    let accessibilityLabel: String
    let identifier: String

    /// What a tap asks for: the side not showing.
    let select: (Side) -> Void

    /// The side a tap shows.
    var other: Side { side == leading ? trailing : leading }

    /// A side's word, as the label and as the spoken value.
    func word(_ side: Side) -> String { side == leading ? leadingLabel : trailingLabel }

    /// A side's SF Symbol.
    func icon(_ side: Side) -> String { side == leading ? leadingIcon : trailingIcon }

    var body: some View {
        Button {
            select(other)
        } label: {
            // One hidden line of the badges' label type sets the row's
            // height, as the "…"'s glyph row does in `OverflowMenu`; the glyph
            // and the word are laid out at no height over it, so a glyph
            // taller than the mono line can't grow the capsule past its two
            // neighbours. The row keeps its own width.
            ZStack {
                Text(verbatim: "0")
                    .font(SortMenuCopy.labelFont)
                    .hidden()
                HStack(spacing: 8) {
                    Image(systemName: icon(side))
                        .font(.system(size: 11, weight: .semibold))
                    Text(word(side))
                        .font(SortMenuCopy.labelFont)
                }
                .frame(height: 0)
            }
            // `SortMenu`'s label padding (Decision 17).
            .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        // Decision 17: the system's label colour as the tint, as on the two
        // badges beside it.
        .tint(.primary)
        .controlSize(.regular)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(word(side))
        .accessibilityIdentifier(identifier)
    }
}

/// The Items tab's Owned / Sold toggle.
extension SideToggle where Side == ItemListViewModel.Side {
    init(side: Side, select: @escaping (Side) -> Void) {
        self.init(
            side: side,
            leading: .owned,
            leadingLabel: SaleCopy.owned,
            leadingIcon: "shippingbox",
            trailing: .sold,
            trailingLabel: SaleCopy.sold,
            trailingIcon: "tag",
            accessibilityLabel: "Owned or sold",
            identifier: "items.sideSwitch",
            select: select
        )
    }
}

/// The Plans tab's Active / Completed toggle.
extension SideToggle where Side == PlansViewModel.Side {
    init(side: Side, select: @escaping (Side) -> Void) {
        self.init(
            side: side,
            leading: .active,
            leadingLabel: SellPlanCopy.active,
            leadingIcon: "clock",
            trailing: .completed,
            trailingLabel: SellPlanCopy.completed,
            trailingIcon: "checkmark.circle",
            accessibilityLabel: SellPlanCopy.sideSwitchLabel,
            identifier: "plans.sideSwitch",
            select: select
        )
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 24) {
            SideToggle(side: ItemListViewModel.Side.owned, select: { _ in })
            SideToggle(side: ItemListViewModel.Side.sold, select: { _ in })
            SideToggle(side: PlansViewModel.Side.active, select: { _ in })
            SideToggle(side: PlansViewModel.Side.completed, select: { _ in })
        }
        .padding(24)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
