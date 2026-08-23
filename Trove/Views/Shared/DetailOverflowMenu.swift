import SwiftUI

/// Edit and Delete on a detail screen, behind one circular "..." button.
///
/// Replaces the permanent `Edit` `Delete` pair both detail screens carried
/// through Phase 7. Two always-visible words in the nav bar — one of them a
/// destructive action a thumb-width from the other — read as dated against the
/// rest of the app's iOS 26 treatment: the floating `AddButton`, the
/// translucent tab bar, the circular back chevron this sits opposite.
///
/// **Delete keeps its `.destructive` role**, which is what makes the system
/// draw it in red and separate it from the rest of the menu. That's the only
/// signal a menu row has, so it isn't decorative.
///
/// This changes how Edit and Delete are *reached*, and nothing else. Each
/// screen still owns its own edit sheet and its own delete confirmation —
/// including `WishlistDetailView`'s alert about the cascade/nullify asymmetry,
/// which says something this component has no way to know.
struct DetailOverflowMenu: View {
    /// What the menu acts on, for VoiceOver — "item", "wanted item". Reads as
    /// "More actions for this item".
    let noun: String
    let edit: () -> Void
    let delete: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Button("Edit", systemImage: "pencil", action: edit)
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.colors.textBody)
                // A square frame, so the circle the system draws around it in
                // the nav bar is a circle rather than an oval.
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions for this \(noun)")
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Theme.dark.colors.background.ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DetailOverflowMenu(noun: "item", edit: {}, delete: {})
            }
        }
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
