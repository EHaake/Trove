import SwiftUI

/// 011's "…" overflow control — the list headers' second badge, sitting
/// right of `SortBadge` and drawn to its proportions (brass hairline border,
/// same paddings) so the pair reads as one control family.
///
/// Hosts a **system `Menu`**, not a `SortDropdown` clone, and the T029c
/// history says why that's safe here: the Menu was evicted from this header
/// because UIKit animated its *variable-width label's* bounds outside
/// SwiftUI's reach — this label is a constant-size glyph, the exact shape
/// `DetailOverflowMenu` already runs safely in production. If the border
/// ever tears the way T029c's did, the custom dropdown is the known
/// fallback.
///
/// The spec expects this menu to accumulate actions later; today it carries
/// exactly the two export actions, disabled when the view is empty
/// (criterion 2), and the whole control disables behind a compact spinner
/// while a file generates (criterion 11's progress affordance).
struct ExportBadge: View {
    let isExporting: Bool
    let canExport: Bool
    let exportCSV: () -> Void
    let exportPDF: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Button("Export as CSV…", action: exportCSV)
                .disabled(!canExport)
            Button("Export as PDF…", action: exportPDF)
                .disabled(!canExport)
        } label: {
            Group {
                if isExporting {
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
        .disabled(isExporting)
        .accessibilityLabel(isExporting ? "Exporting" : "More actions")
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                SortBadge(label: "Custom") {}
                ExportBadge(isExporting: false, canExport: true, exportCSV: {}, exportPDF: {})
            }
            ExportBadge(isExporting: true, canExport: true, exportCSV: {}, exportPDF: {})
        }
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
