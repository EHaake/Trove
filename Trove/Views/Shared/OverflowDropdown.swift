import SwiftUI

/// The lists' "…" menu on the shared surface (013 Amendment A, criterion 1):
/// five rows in three groups — the two exports, disabled exactly when the
/// view has nothing to export; Import from CSV…; Settings, its own group at
/// the bottom, no ellipsis because it opens a screen rather than a flow
/// that needs input. No header row (P9: "…" has no word to echo, and the
/// system menu it replaces had none); the two group breaks drawn as the
/// rows' own top hairlines in `divider` (P10).
///
/// The organizing rule 013 settled: this menu holds what you do repeatedly
/// with the list in front of you; Settings holds whole-collection and
/// one-time things. Import and Settings are never gated — an empty
/// collection is exactly who they serve — which is why the badge shows
/// regardless of collection size (the headers own that half).
///
/// Every row closes the dropdown before its action runs — `DropdownRow`'s
/// doing, so the intents here are the intents alone.
struct OverflowDropdown: View {
    /// One gate per export row (006, plan Q5): the Items list can have a CSV
    /// to write with nothing to put in a PDF — an all-sold collection — so a
    /// single `canExport` would have to be wrong about one of them. The
    /// Wishlist, which has no sold half, passes its one flag to both.
    let canExportCSV: Bool
    let canExportPDF: Bool
    let exportCSV: () -> Void
    let exportPDF: () -> Void
    let importCSV: () -> Void
    let openSettings: () -> Void

    var body: some View {
        DropdownSurface {
            DropdownRow(title: "Export as CSV…", isEnabled: canExportCSV, action: exportCSV)
            DropdownRow(title: "Export as PDF…", isEnabled: canExportPDF, action: exportPDF)
            DropdownRow(title: "Import from CSV…", startsGroup: true, action: importCSV)
            DropdownRow(title: "Settings", startsGroup: true, action: openSettings)
        }
    }
}

#Preview("With something to export") {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        OverflowDropdown(canExportCSV: true, canExportPDF: true, exportCSV: {}, exportPDF: {}, importCSV: {}, openSettings: {})
            .environment(\.dismissDropdown, DismissDropdownAction {})
    }
    .environment(\.theme, .dark)
}

#Preview("Empty collection") {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        OverflowDropdown(canExportCSV: false, canExportPDF: false, exportCSV: {}, exportPDF: {}, importCSV: {}, openSettings: {})
            .environment(\.dismissDropdown, DismissDropdownAction {})
    }
    .environment(\.theme, .dark)
}
