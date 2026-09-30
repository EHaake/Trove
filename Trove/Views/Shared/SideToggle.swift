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
/// **Styled as `OverflowMenu` is, minus the circle, and brass on the primary
/// side**: the glass button style at the system's regular control size, with
/// 4 pt of padding above and below the label. The showing row is the app's
/// brass while the leading side shows (Owned, Active) and the system's
/// primary label colour while the trailing side shows (Sold, Completed) —
/// spec Decision 20, the one header control that carries the app's colour,
/// so the primary side reads as such. The colour is the row's own
/// `foregroundStyle`, not the button's tint: the row sets it, so a tint
/// would reach nothing drawn. The word is in the badges' label type
/// (`SortMenuCopy.labelFont`), and the label stands in one hidden line of
/// that type, so the three controls in the row render at one height
/// (`ItemListHeaderLayoutTests`, G1). No other colour is named here;
/// `ThemeTests` lets exactly the one row-colour line through.
///
/// **One width for both sides, and the swap animates** (spec Decision 21):
/// both sides' rows are laid out hidden under the showing one, so the
/// capsule is the wider side's width on both sides (Items 79 pt, Plans
/// 105 pt) and the shorter word sits centred — the glass capsule's own
/// resize runs outside SwiftUI's transactions and clipped "Completed" for
/// ~0.17 s (filmed, T009d). The showing row is replaced with a blur under a
/// 0.3 s smooth animation, which never draws both words legibly at once
/// (filmed on 27.0 and 26.5, T009d).
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

    @Environment(\.theme) private var theme

    /// The side a tap shows.
    var other: Side { side == leading ? trailing : leading }

    /// A side's word, as the label and as the spoken value.
    func word(_ side: Side) -> String { side == leading ? leadingLabel : trailingLabel }

    /// A side's SF Symbol.
    func icon(_ side: Side) -> String { side == leading ? leadingIcon : trailingIcon }

    /// A side's glyph and word.
    func row(_ side: Side) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon(side))
                .font(.system(size: 11, weight: .semibold))
            Text(word(side))
                .font(SortMenuCopy.labelFont)
        }
    }

    var body: some View {
        Button {
            select(other)
        } label: {
            // One hidden line of the badges' label type sets the row's
            // height, as the "…"'s glyph row does in `OverflowMenu`; the
            // glyphs and the words are laid out at no height over it, so a
            // glyph taller than the mono line can't grow the capsule past its
            // two neighbours.
            ZStack {
                Text(verbatim: "0")
                    .font(SortMenuCopy.labelFont)
                    .hidden()
                // Both sides laid out hidden, so the capsule is always the
                // wider side's width and never resizes (Decision 21).
                row(leading).frame(height: 0).hidden()
                row(trailing).frame(height: 0).hidden()
                // The showing side, blur-replaced on a change. Decision 20:
                // brass on the leading side, the system's label colour
                // (Decision 17, as on the two badges beside it) on the
                // trailing one.
                ZStack {
                    row(side)
                        .foregroundStyle(side == leading ? theme.colors.accentBrass : Color.primary)
                        .id(side)
                        .transition(.blurReplace)
                }
                .frame(height: 0)
                .animation(.smooth(duration: 0.3), value: side)
            }
            // `SortMenu`'s label padding (Decision 17).
            .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
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
