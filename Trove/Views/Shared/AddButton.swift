import SwiftUI

/// The add action in a list screen's header.
///
/// Design draws this as a raised brass circle centred in a five-slot tab bar
/// (Overview · Items · **+** · Wishlist · More). v1 ships three tabs and no
/// More tab, so that centre slot doesn't exist — a "+" between Items and
/// Wishlist would be the second of four positions rather than a centre — and
/// plan.md asks for the add action in each tab's toolbar instead.
///
/// This keeps Design's treatment and moves its position: the same brass disc
/// and dark glyph, in the screen's own header beside the sort control. Both
/// list screens draw their title in content with the navigation bar hidden, so
/// that header row *is* the toolbar here.
///
/// It replaced a floating overlay button that stood in until the real tab bar
/// existed. Worth being rid of: the overlay sat on top of the last row, which
/// is why the wishlist needed bottom scroll margin to see past it.
struct AddButton: View {
    /// What the button adds, for VoiceOver — "Add item", "Add wanted item".
    let label: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(theme.colors.background)
                .frame(width: 44, height: 44)
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
