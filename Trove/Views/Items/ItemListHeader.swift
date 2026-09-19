import SwiftUI

/// The Items screen's header: the screen title, the badges it carries, and
/// the meta line under both.
///
/// Extracted from `ItemListView` at `014`/T010a, when the device pass
/// measured criterion 3 failing — the Sold side's `SideSwitch` at 168.00 pt
/// against the Owned side's 154.33 pt, one mono line apart, as soon as
/// anything was sold. The cause was this header's old shape: the title and
/// the meta line stood in a `VStack` *beside* the badges, so the meta line
/// only ever had the width the badges left it (226.3 pt on the Sold side
/// under "Date sold"), and the sold summary needs about 232 — so it wrapped
/// on one side and not the other (plan Q18).
///
/// The meta and the badges arrive as `@ViewBuilder`s, which is what makes
/// the header's height measurable off-device: `ItemListHeaderLayoutTests`
/// (G38) renders it over the real ingredients at the device's content width.
/// `WishlistView.header` still carries the old shape and is a follow-up, not
/// this task's footprint.
struct ItemsListHeader<Meta: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var meta: Meta
    @ViewBuilder var trailing: Trailing

    @Environment(\.theme) private var theme

    /// The badges stay top-aligned with the title rather than centred on it,
    /// so the header's height is the title's line box plus the 6 pt spacing
    /// plus one meta line — unchanged from the shape this replaced, provided
    /// the title's box is at least the badge row's 30 pt. G38's
    /// no-badges case is where that proviso is measured rather than
    /// assumed: the same header with an empty trailing slot must come out
    /// the same height, which it can only do while the title, and not the
    /// badge row, is what sets it.
    ///
    /// One disclosed consequence (plan Q18): VoiceOver now reads title,
    /// badges, meta rather than title, meta, badges. The person confirms it
    /// at criterion 12's Accessibility Inspector step.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(title)
                    .font(theme.typography.screenTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()

                trailing
            }

            meta
        }
    }
}
