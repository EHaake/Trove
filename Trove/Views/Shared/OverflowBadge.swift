import SwiftUI

/// The list headers' "…" overflow control — 011's `ExportBadge`, renamed at
/// 012/T013 when the import actions joined its menu and the old name became
/// a lie (`DetailOverflowMenu` already established the vocabulary).
///
/// Hosts a **system `Menu`**, not a `SortDropdown` clone, and the T029c
/// history says why that's safe here: the Menu was evicted from this header
/// because UIKit animated its *variable-width label's* bounds outside
/// SwiftUI's reach — this label is a constant-size glyph, the exact shape
/// `DetailOverflowMenu` already runs safely in production. If the border
/// ever tears the way T029c's did, the custom dropdown is the known
/// fallback.
///
/// Menu contents since 013 (criterion 1): the two export actions, disabled
/// exactly when the view has nothing to export; a divider; Import from
/// CSV…; a divider; **Settings**, its own section at the bottom. The blank
/// template left this menu for Settings — the organizing rule 013 settled
/// is that this menu holds what you do repeatedly with the list in front
/// of you, and Settings holds whole-collection and one-time things. Import
/// and Settings are always enabled, which is why the badge itself shows
/// regardless of collection size (the headers own that half). The whole
/// control disables behind a compact spinner while any export or import
/// runs (`isBusy`).
struct OverflowBadge: View {
    let isBusy: Bool
    let canExport: Bool
    let exportCSV: () -> Void
    let exportPDF: () -> Void
    let importCSV: () -> Void
    let openSettings: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Button("Export as CSV…", action: exportCSV)
                .disabled(!canExport)
            Button("Export as PDF…", action: exportPDF)
                .disabled(!canExport)
            Divider()
            Button("Import from CSV…", action: importCSV)
            Divider()
            // No ellipsis: it opens a screen, not a flow that needs input.
            Button("Settings", action: openSettings)
        } label: {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors.accentBrass)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(theme.colors.accentBrass)
            // Sized against SortBadge's content row (mono 11 text) so the
            // two badges share a height without either knowing the other's.
            .frame(width: 18, height: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
            )
            .contentShape(Rectangle())
        }
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Working" : "More actions")
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                SortBadge(label: "Custom") {}
                OverflowBadge(
                    isBusy: false, canExport: true,
                    exportCSV: {}, exportPDF: {}, importCSV: {}, openSettings: {}
                )
            }
            OverflowBadge(
                isBusy: true, canExport: true,
                exportCSV: {}, exportPDF: {}, importCSV: {}, openSettings: {}
            )
        }
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
