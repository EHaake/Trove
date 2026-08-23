import SwiftUI

/// The add action on a list screen — Design's raised brass disc, floating over
/// the content at the bottom-right.
///
/// **This is the permanent v1 design, not a stand-in.** Design draws the disc
/// in the centre slot of a five-tab bar (Overview · Items · **+** · Wishlist ·
/// More); v1 ships three tabs and no More, so that centre slot doesn't exist.
/// The treatment is the part worth keeping — the position adapts to the tab
/// count we actually have, and bottom-right beats a top-corner toolbar button
/// for one-handed reach. See plan.md's Navigation section.
///
/// It briefly moved into each screen's header during T043, on a reading of
/// "toolbar" that plan.md has since replaced. What survived that attempt is
/// this being one shared component rather than two copies.
///
/// Positioning is the caller's: this is just the disc, so each screen states
/// its own `.overlay(alignment: .bottomTrailing)` and insets.
struct AddButton: View {
    /// What the button adds, for VoiceOver — "Add item", "Add wanted item".
    let label: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(theme.colors.background)
                .frame(width: 56, height: 56)
                .background(Circle().fill(theme.colors.accentBrass))
        }
        .buttonStyle(.plain)
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
