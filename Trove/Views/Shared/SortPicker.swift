import SwiftUI

/// `010`'s sort picker, per tokens.md's "Sort picker" table: a compact brass
/// badge showing the current selection, and a custom dropdown listing the
/// options with the selected row tinted, checked, and — on the manual-order
/// option only — tagged REORDER, which is what replaced the wishlist's old
/// standalone button in the design.
///
/// Custom-built rather than a system `Menu`, deliberately: the Menu's UIKit
/// machinery animates its label's bounds outside any SwiftUI transaction's
/// reach, which is what tore the old control's border at T029c and forced a
/// constant-footprint workaround. Everything here is SwiftUI — nothing
/// animates that this view doesn't animate — so the badge simply hugs its
/// label.
///
/// The two list screens own the open/close state and the full-screen
/// tap-to-dismiss layer, because the dropdown has to float over content the
/// badge can't reach from inside the header.
struct SortBadge: View {
    let label: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // The three-bar sort glyph, drawn to the token widths rather
                // than borrowed from SF Symbols so the strokes match.
                VStack(alignment: .leading, spacing: 2.5) {
                    bar(width: 10)
                    bar(width: 7)
                    bar(width: 4)
                }
                Text(label)
                    .font(ThemeTypography.font(.mono, size: 11))
            }
            .foregroundStyle(theme.colors.accentBrass)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func bar(width: CGFloat) -> some View {
        Rectangle()
            .fill(theme.colors.accentBrass)
            .frame(width: width, height: 1.5)
    }
}

/// The dropdown half — see `SortBadge`. Since 013 Amendment A a composition
/// of `DropdownSurface` and `DropdownRow`, the drawing every in-page menu
/// shares; only the rows are Sort By's — the selected one tinted and
/// checked, the manual-order option tagged REORDER.
struct SortDropdown<Option: Identifiable & Equatable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    let isManualOrder: (Option) -> Bool
    let onSelect: (Option) -> Void

    var body: some View {
        DropdownSurface(title: "SORT BY") {
            ForEach(options) { option in
                // The REORDER tag belongs to the manual option alone — it's
                // what tells the user this row is also where dragging
                // lives, the job the old standalone button did.
                DropdownRow(
                    title: label(option),
                    isSelected: option == selection,
                    tag: isManualOrder(option) ? "REORDER" : nil
                ) {
                    onSelect(option)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .trailing, spacing: 8) {
            SortBadge(label: "Custom") {}
            SortDropdown(
                options: WishlistViewModel.SortOrder.allCases,
                selection: .custom,
                label: \.label,
                isManualOrder: { $0 == .custom },
                onSelect: { _ in }
            )
        }
        .padding(24)
    }
    .environment(\.theme, .dark)
    .environment(\.dismissDropdown, DismissDropdownAction {})
}
