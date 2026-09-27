import SwiftUI

/// 018: a list screen's two sides as the system segmented control — on iOS
/// 26 a capsule whose selected segment is a glass pill that slides. Reports
/// a choice through `select` and never writes the side (Q3).
///
/// The Items tab's Owned / Sold (`006`) and the Plans tab's Active /
/// Completed (`009`), generic over each screen's own side type, with one
/// constrained `init(side:select:)` per screen below so each call site names
/// only its side and its tap, and every word, label and identifier lives
/// here. Not themed: no tint, no appearance proxy (Decision 7) — the system
/// draws it, and sizes each segment to its word (P7).
///
/// **It never writes the side.** `ItemListViewModel.side` is `private(set)`,
/// so the `Binding` lives here and its setter is `select`: a choice goes to
/// `show(_:)` and the view model decides what it means — `PlansViewModel`
/// the same way. A `Picker` sets its binding only on a change, so choosing
/// the segment already showing does not reload that side (R2); pull to
/// refresh still does.
struct SidePicker<Side: Hashable>: View {
    /// The side showing.
    let side: Side

    /// The two sides, left to right, and the words on their segments.
    let leading: Side, leadingLabel: String
    let trailing: Side, trailingLabel: String

    /// The pair's VoiceOver label and UI-test identifier.
    let accessibilityLabel: String
    let identifier: String

    /// What a chosen segment asks for.
    let select: (Side) -> Void

    var body: some View {
        Picker(accessibilityLabel, selection: Binding(get: { side }, set: select)) {
            Text(leadingLabel).tag(leading)
            Text(trailingLabel).tag(trailing)
        }
        .pickerStyle(.segmented)
        // Hugs its words, left-aligned where the bespoke switch stood,
        // rather than stretching gutter to gutter (R1).
        .fixedSize()
        .accessibilityIdentifier(identifier)
    }
}

/// The Items tab's Owned / Sold switch.
extension SidePicker where Side == ItemListViewModel.Side {
    init(side: Side, select: @escaping (Side) -> Void) {
        self.init(
            side: side,
            leading: .owned,
            leadingLabel: SaleCopy.owned,
            trailing: .sold,
            trailingLabel: SaleCopy.sold,
            accessibilityLabel: "Owned or sold",
            identifier: "items.sideSwitch",
            select: select
        )
    }
}

/// The Plans tab's Active / Completed switch.
extension SidePicker where Side == PlansViewModel.Side {
    init(side: Side, select: @escaping (Side) -> Void) {
        self.init(
            side: side,
            leading: .active,
            leadingLabel: SellPlanCopy.active,
            trailing: .completed,
            trailingLabel: SellPlanCopy.completed,
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
            SidePicker(side: ItemListViewModel.Side.owned, select: { _ in })
            SidePicker(side: ItemListViewModel.Side.sold, select: { _ in })
            SidePicker(side: PlansViewModel.Side.active, select: { _ in })
            SidePicker(side: PlansViewModel.Side.completed, select: { _ in })
        }
        .padding(24)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
