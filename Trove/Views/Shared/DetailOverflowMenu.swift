import SwiftUI

/// Edit and Delete on a detail screen, behind one circular "..." button —
/// with an optional row between them (`006` plan §5).
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
/// **This is the app's one system menu, deliberately** (013 Amendment A,
/// Decision 17): bespoke inside the page, system in the bars. It lives in
/// the navigation bar beside the system back chevron, drawn in the
/// system's circle, and stays the system's — while every menu drawn inside
/// a page's content is Trove's own `DropdownSurface`. `MenuPolicyTests`
/// pins this file as the only one that may host a `Menu`.
///
/// This changes how Edit and Delete are *reached*, and nothing else. Each
/// screen still owns its own edit sheet and its own delete confirmation —
/// including `WishlistDetailView`'s alert about the cascade/nullify asymmetry,
/// which says something this component has no way to know.
///
/// `006` gave the first row a title of its own and added the middle one, so
/// one item's page can offer Edit / **Mark as sold…** / Delete while it is
/// owned and **Edit sale…** / **Return to collection…** / Delete once it is
/// sold. The original `(noun:edit:delete:)` initializer is kept and still
/// means "Edit"/pencil with nothing between, which was what the wishlist's
/// page asked for through `006` — that spec left it untouched.
///
/// **`015` reversed that** (plan §8, criterion 2): the wanted entry's page
/// takes the middle row too, offering Edit / **Mark as bought…** / Delete
/// through the same `(noun:edit:middle:delete:)` initializer, so both detail
/// screens now build their rows themselves and the sentence above holds only
/// as history (`specs/006-mark-as-sold/plan.md` carries the pointer). The
/// `(noun:edit:delete:)` initializer stays all the same, and is not dead: the preview
/// at the foot of this file calls it, and a preview is invisible to the
/// source scans that read this file (they stop at it), so a scan reporting
/// the initializer unused would be wrong — removing it is no part of what
/// `015` set out to do, and would break that preview.
///
/// **`009` adds a third shape, Delete alone** (plan Q12): `(noun:delete:)`,
/// with no Edit row, for the Sell Plan screen. A plan has nothing to edit —
/// its selection is made on the page itself — but deleting one should still
/// take the second tap every other detail page's Delete takes, rather than
/// sitting bare in the bar a thumb-width from Buy. So `edit` is optional, and
/// only this initializer leaves it out; the other two still always draw it.
struct DetailOverflowMenu: View {
    /// One row of the menu: what it says, the SF Symbol beside it, and what
    /// it does. Delete is not a `Row` — its `.destructive` role and its word
    /// are the component's own, not a caller's choice.
    struct Row {
        let title: String
        let systemImage: String
        let action: () -> Void
    }

    /// What the menu acts on, for VoiceOver — "item", "wanted item". Reads as
    /// "More actions for this item".
    let noun: String
    /// Edit, or nothing — nothing only from `(noun:delete:)`.
    let edit: Row?
    /// The row between Edit and Delete, or nothing.
    var middle: Row?
    let delete: () -> Void

    /// The shape both detail screens used through `005`: Edit, then Delete.
    init(noun: String, edit: @escaping () -> Void, delete: @escaping () -> Void) {
        self.init(
            noun: noun,
            edit: Row(title: "Edit", systemImage: "pencil", action: edit),
            middle: nil,
            delete: delete
        )
    }

    init(noun: String, edit: Row, middle: Row?, delete: @escaping () -> Void) {
        self.noun = noun
        self.edit = edit
        self.middle = middle
        self.delete = delete
    }

    /// Delete alone, for a screen with nothing to edit (`009`, the Sell Plan).
    init(noun: String, delete: @escaping () -> Void) {
        self.noun = noun
        self.edit = nil
        self.middle = nil
        self.delete = delete
    }

    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            if let edit {
                Button(edit.title, systemImage: edit.systemImage, action: edit.action)
            }
            if let middle {
                Button(middle.title, systemImage: middle.systemImage, action: middle.action)
            }
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
