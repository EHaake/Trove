import SwiftUI

/// The list screens' header: the screen title, the controls it carries, and
/// the meta line under both.
///
/// Extracted from `ItemListView` at `014`/T010a, when the device pass
/// measured criterion 3 failing — the Sold side's switch at 168.00 pt
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
/// Since `018` T009e (spec Decision 22) the Wishlist composes it too, and its
/// old stacked header — title and meta in a column beside the controls — is
/// gone; Plans, with no meta line, uses `TitleRowLayout` on its own.
struct ItemsListHeader<Meta: View, Trailing: View>: View {
    let title: String
    /// The space between this header and what the screen puts under it —
    /// `sectionGap` above a search field, `listRowGap` on a side with nothing
    /// to narrow. The meta line takes half of it and the title row's old 6 pt
    /// between them (`MetaLineSpacing`); the screen pads the other half.
    let gapBelow: CGFloat
    @ViewBuilder var meta: Meta
    @ViewBuilder var trailing: Trailing

    @Environment(\.theme) private var theme

    /// The title's baseline sits on the controls' bottom edge (spec Decision
    /// 22), and the meta line sits midway between the title row and what
    /// follows — so the header's height is the control row, the meta line's
    /// share of the gap, and one meta line, the same on both sides. G38
    /// measures it rather than assuming it: that sum on both sides, and the
    /// same header with an empty trailing slot coming out shorter.
    ///
    /// One disclosed consequence (plan Q18): VoiceOver now reads title,
    /// badges, meta rather than title, meta, badges. The person confirms it
    /// at criterion 12's Accessibility Inspector step.
    var body: some View {
        VStack(alignment: .leading, spacing: MetaLineSpacing.split(before: gapBelow)) {
            TitleRowLayout {
                Text(title)
                    .font(theme.typography.screenTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)

                trailing
            }

            meta
        }
    }
}

/// The space around the header's meta line (`018` spec Decision 22): equal
/// above and below it, redistributed from what was already there so the
/// search field or the first row under the header does not move by a point.
enum MetaLineSpacing {
    /// The meta line's distance under the title row before Decision 22. With
    /// the gap the screen leaves under the meta line, it is the total the
    /// split shares out.
    static let titleRowToMeta: CGFloat = 6

    /// The space on each side of the meta line, given the gap that follows
    /// the header: 15 pt above a search field (`sectionGap`), 8 pt on a side
    /// with nothing to narrow (`listRowGap`), where the empty state stays put.
    static func split(before gap: CGFloat) -> CGFloat {
        (titleRowToMeta + gap) / 2
    }
}

/// The header's title row (`018` spec Decision 22): the title at the leading
/// edge, the trailing controls at their ideal width, and the title's baseline
/// on the controls' bottom edge.
///
/// A `Layout` because no stack alignment gives this. `.bottom` puts the
/// title's descender on that edge, not its baseline; an `HStack` aligned on
/// the baseline grows the row by the title's descent (37 → 44 pt) and moves
/// every first row under it by the same. Here the row is as tall as the
/// taller of the controls and the title's baseline — read from the title's
/// dimensions at runtime, never written down as a font property — and the
/// descent hangs below the row, into the space above the meta line.
///
/// Its subviews are the title, then at most one view for the controls.
struct TitleRowLayout: Layout {
    /// The least space between the title and the controls. The title takes
    /// what the controls leave less this, on one line: since `018` Decision
    /// 19 the row carries three glass controls, and squeezing them wrapped
    /// their labels.
    private let minimumGap: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let row = measure(width: proposal.width, subviews: subviews)
        return CGSize(width: row.width, height: row.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let row = measure(width: bounds.width, subviews: subviews)
        subviews.first?.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + row.height - row.titleBaseline),
            anchor: .topLeading,
            proposal: row.titleProposal
        )
        if subviews.count > 1 {
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY + row.height),
                anchor: .bottomTrailing,
                proposal: ProposedViewSize(row.controlsSize)
            )
        }
    }

    private struct Row {
        let width: CGFloat
        let height: CGFloat
        let titleProposal: ProposedViewSize
        let titleBaseline: CGFloat
        let controlsSize: CGSize
    }

    private func measure(width proposedWidth: CGFloat?, subviews: Subviews) -> Row {
        assert(subviews.count <= 2, "TitleRowLayout lays out a title and one control row, got \(subviews.count) views")
        let controlsSize = subviews.count > 1 ? subviews[1].sizeThatFits(.unspecified) : .zero
        let gap = subviews.count > 1 ? minimumGap : 0

        let width: CGFloat
        if let proposedWidth, proposedWidth.isFinite {
            width = proposedWidth
        } else {
            width = (subviews.first?.sizeThatFits(.unspecified).width ?? 0) + gap + controlsSize.width
        }

        let titleProposal = ProposedViewSize(width: max(0, width - gap - controlsSize.width), height: nil)
        let titleBaseline = subviews.first?.dimensions(in: titleProposal)[.firstTextBaseline] ?? 0

        return Row(
            width: width,
            height: max(controlsSize.height, titleBaseline),
            titleProposal: titleProposal,
            titleBaseline: titleBaseline,
            controlsSize: controlsSize
        )
    }
}
