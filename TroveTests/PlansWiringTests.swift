import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// How the Plans tab is wired (spec `009`). T010 opens it with G18; T011
/// extends it.
@Suite("Plans wiring")
@MainActor
struct PlansWiringTests {
    // MARK: - The side switch (plan §10, Q14)

    /// G18: every label of both side switches fits its half. Each word is
    /// rendered on a scratch `ImageRenderer` at the font the switch draws it
    /// in — `SideSwitchMetrics.labelFont`, at both weights, since the active
    /// half lifts to medium — and must be narrower than the switch's own half
    /// less 4 pt either side. The words and the widths are read off switches
    /// built through each screen's own `init(side:select:)`, so a label or a
    /// half changed in production lands in this measurement rather than being
    /// typed out here.
    ///
    /// Mutation (T010): the Plans half at 50 pt → red on "Completed".
    @Test func everyLabelOfBothSwitchesFitsItsHalf() throws {
        let items = SideSwitch(side: ItemListViewModel.Side.owned, select: { _ in })
        let plans = SideSwitch(side: PlansViewModel.Side.active, select: { _ in })

        let switches: [(name: String, labels: [String], halfWidth: CGFloat)] = [
            ("Items", [items.leadingLabel, items.trailingLabel], items.halfWidth),
            ("Plans", [plans.leadingLabel, plans.trailingLabel], plans.halfWidth),
        ]

        for control in switches {
            let room = control.halfWidth - 2 * 4
            for label in control.labels {
                try #require(!label.isEmpty, "the \(control.name) switch has an empty label")
                for isActive in [false, true] {
                    let width = try labelWidth(label, isActive: isActive)
                    print("SideSwitch \(control.name) \"\(label)\" \(isActive ? "medium" : "regular"): \(width) pt in a \(control.halfWidth) pt half")
                    #expect(
                        CGFloat(width) < room,
                        "the \(control.name) switch's \"\(label)\" measures \(width) pt at \(isActive ? "medium" : "regular"), not narrower than its \(control.halfWidth) pt half less 4 pt either side (\(room) pt)"
                    )
                }
            }
        }
    }

    // MARK: - The instrument

    /// A label's rendered width at the switch's own type, at 1×.
    private func labelWidth(_ label: String, isActive: Bool) throws -> Int {
        try #require(
            renderBitmap(Text(label).font(SideSwitchMetrics.labelFont(isActive: isActive))),
            "ImageRenderer produced nothing to measure for \"\(label)\"."
        ).width
    }
}
