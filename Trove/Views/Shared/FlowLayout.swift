import SwiftUI

/// Lays subviews out left to right, wrapping to a new line when the next one
/// won't fit. SwiftUI has no built-in flow layout, and the category chips in
/// `design/screens/Trove Item Form.png` wrap onto a second line.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        let rows = rows(fittingWidth: maxWidth, subviews: subviews)
        guard !rows.isEmpty else { return .zero }

        let height = rows.reduce(0) { $0 + $1.height }
            + verticalSpacing * CGFloat(rows.count - 1)
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(fittingWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var height: CGFloat = 0
    }

    private func rows(fittingWidth maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            // Always keep at least one subview per row, so something wider
            // than the container overflows rather than looping forever.
            if !current.indices.isEmpty, x + size.width > maxWidth {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.indices.append(index)
            current.height = max(current.height, size.height)
            x += size.width + horizontalSpacing
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
