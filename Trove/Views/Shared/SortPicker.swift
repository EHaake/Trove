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

/// The dropdown half — see `SortBadge`.
struct SortDropdown<Option: Identifiable & Equatable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    let isManualOrder: (Option) -> Bool
    let onSelect: (Option) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text("SORT BY")
                .font(ThemeTypography.font(.mono, size: 10))
                .tracking(1.6)
                .foregroundStyle(theme.colors.textQuiet)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 11, leading: 14, bottom: 9, trailing: 14))

            ForEach(options) { option in
                row(for: option)
            }
        }
        .frame(width: 232)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                .fill(theme.colors.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                .strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
        )
    }

    private func row(for option: Option) -> some View {
        let isSelected = option == selection

        return Button {
            onSelect(option)
        } label: {
            HStack(spacing: 10) {
                Text(label(option))
                    .font(theme.typography.body)
                    .foregroundStyle(isSelected ? theme.colors.accentBrass : theme.colors.textBody)

                Spacer(minLength: 0)

                if isSelected {
                    // The REORDER tag belongs to the manual option alone —
                    // it's what tells the user this row is also where
                    // dragging lives, the job the old standalone button did.
                    if isManualOrder(option) {
                        Text("REORDER")
                            .font(ThemeTypography.font(.mono, size: 9.5))
                            .tracking(1.14)
                            .foregroundStyle(theme.colors.textQuiet)
                    }
                    CheckmarkGlyph()
                        .stroke(
                            theme.colors.accentBrass,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 12, height: 12)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(isSelected ? theme.colors.accentBrassTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Between rows, and between the header and the first row — the mock
        // draws both.
        .overlay(alignment: .top) {
            theme.colors.surfaceInset.frame(height: theme.metrics.hairline)
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// tokens.md's 12×12 checkmark at 1.6 stroke, drawn rather than borrowed so
/// the stroke weight is exact.
private struct CheckmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.25))
        return path
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
}
