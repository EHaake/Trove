import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The dropdown's placement rule (013 Amendment A), as a table over the pure
/// function the layout calls — the only way "flips above near the tab bar"
/// is a checkable claim rather than a sentence.
///
/// The region is the iPhone 17 Pro's safe area as T020's probe measured it:
/// 402 wide, 729 tall (874 less the 62-point status bar and the 83-point
/// floating tab bar), so its top is the status bar's bottom edge and its
/// bottom is the tab bar's top edge. Badges are in the same space: the
/// lists' header badges sit at y = 24, the section gap. The gutter is 24,
/// the gap 6, and the dropdown 232 × 327 — the Sort By surface at seven
/// rows, which is what both lists show since the Market pair joined them
/// (002/T012). Not a remembered number — the last case in this suite
/// renders the real surface and pins it — so the arithmetic in the cases
/// below can't quietly describe a dropdown that no longer exists.
@Suite("Dropdown placement")
struct DropdownPlacementTests {
    private let region = CGRect(x: 0, y: 0, width: 402, height: 729)
    private let size = CGSize(width: 232, height: 327)
    private let gutter: CGFloat = 24
    private let gap: CGFloat = 6

    private func origin(badge: CGRect, size: CGSize? = nil, region: CGRect? = nil) -> CGPoint {
        DropdownPlacement.origin(badge: badge, region: region ?? self.region, size: size ?? self.size, gutter: gutter, gap: gap)
    }

    /// The lists' header badge: room below, so it hangs below the badge by
    /// the gap, trailing edge at the gutter — what `.padding(.top, 60)` and
    /// `.padding(.trailing, screenGutter)` produced before the host: 24 + 30
    /// + 6 = 60 under the safe top.
    @Test func hangsBelowTheBadgeAtTheTrailingGutterWhenThereIsRoom() {
        let badge = CGRect(x: 328, y: 24, width: 50, height: 30)   // the "…" pill, trailing edge at 378 = 402 − 24
        let origin = origin(badge: badge)
        // Explicit CGFloat: an arithmetic literal expression inside #expect
        // is typed Int and never equals a CGFloat, whatever its value.
        let expectedY: CGFloat = 24 + 30 + 6
        let expectedX: CGFloat = 402 - 24 - 232
        #expect(origin.y == expectedY)
        #expect(origin.x == expectedX)
    }

    /// The badge supplies only the vertical: a badge left of the gutter (the
    /// sort badge sits 8 points and a pill's width left of the "…") still
    /// hangs its dropdown at the gutter, not at its own trailing edge.
    @Test func theTrailingEdgeIsTheGuttersNotTheBadges() {
        let sortBadge = CGRect(x: 250, y: 24, width: 70, height: 30)
        let gutterEdge: CGFloat = 402 - 24 - 232
        #expect(origin(badge: sortBadge).x == gutterEdge)
    }

    /// The Dashboard's order control near the tab bar: below would run past
    /// the region's bottom, so the dropdown flips above the badge.
    @Test func flipsAboveWhenBelowWouldRunPastTheBottom() {
        let badge = CGRect(x: 300, y: 600, width: 78, height: 20)
        // Below: 600 + 20 + 6 + 327 = 953 > 729 → above.
        let above: CGFloat = 600 - 6 - 327
        #expect(origin(badge: badge).y == above)
    }

    /// Exactly at the bottom is still "fits": the dropdown's bottom edge may
    /// touch the tab bar's top edge, not cross it.
    @Test func touchingTheBottomStillHangsBelow() {
        // maxY + 6 + 327 must equal 729 → maxY = 396.
        let badge = CGRect(x: 300, y: 376, width: 78, height: 20)
        let below: CGFloat = 396 + 6
        #expect(origin(badge: badge).y == below)
    }

    /// A dropdown too tall for either direction: pinned to the region's top
    /// rather than pushed off-screen.
    @Test func pinsToTheTopWhenNeitherDirectionFits() {
        let badge = CGRect(x: 328, y: 24, width: 50, height: 30)
        #expect(origin(badge: badge, size: CGSize(width: 232, height: 800)).y == 0)
    }

    /// Cheap insurance for a region narrower than the gutters plus the
    /// dropdown: the leading gutter wins over the trailing one.
    @Test func neverPastTheLeadingGutter() {
        let narrow = CGRect(x: 0, y: 0, width: 260, height: 729)
        let badge = CGRect(x: 200, y: 24, width: 36, height: 30)
        #expect(origin(badge: badge, region: narrow).x == 24)
    }

    /// The size every case above is arithmetic about, measured rather than
    /// remembered: the real Sort By surface at the seven rows both lists now
    /// carry, rendered at 1×. A row added or a row's height changed moves
    /// this number, and this is where that is noticed — the placement cases
    /// would otherwise keep passing about a dropdown of the wrong height.
    @Test func theSortBySurfaceIsTheSizeThisSuiteMeasuresAgainst() throws {
        try #require(ItemListViewModel.SortOrder.allCases.count == 7)
        try #require(WishlistViewModel.SortOrder.allCases.count == 7)

        let surface = SortDropdown(
            options: ItemListViewModel.SortOrder.allCases,
            selection: ItemListViewModel.SortOrder.custom,
            label: \.label,
            isManualOrder: { $0 == .custom },
            onSelect: { _ in }
        )
        // The first row's focus marking off, as every render test must be
        // (see `DropdownSurface`), and a dismiss action to stand in for the
        // host's.
        let image = try #require(
            renderBitmap(
                surface
                    .environment(\.dropdownFocusesFirstRow, false)
                    .environment(\.dismissDropdown, DismissDropdownAction {})
            ),
            "ImageRenderer produced nothing to measure."
        )

        #expect(CGFloat(image.width) == size.width)
        #expect(CGFloat(image.height) == size.height)
    }

    /// The growth anchor (Decision 20): the badge's trailing edge at its
    /// vertical centre, as a point of the region — so the "…" pill at the
    /// gutter anchors at x = 378/402, and a badge scrolled off the top of
    /// the region anchors at the top edge rather than above it.
    @Test func growsFromTheBadgesTrailingEdge() {
        let badge = CGRect(x: 328, y: 24, width: 50, height: 30)
        let anchor = DropdownPlacement.growthAnchor(badge: badge, region: region)
        let expectedX: CGFloat = 378 / 402
        let expectedY: CGFloat = 39 / 729
        #expect(abs(anchor.x - expectedX) < 0.0001)
        #expect(abs(anchor.y - expectedY) < 0.0001)

        let scrolledOff = CGRect(x: 328, y: -80, width: 50, height: 30)
        #expect(DropdownPlacement.growthAnchor(badge: scrolledOff, region: region).y == 0)
    }

    /// A region with a non-zero origin (a pushed screen's content under its
    /// nav bar, say) measures its gutters and edges from its own origin.
    @Test func measuresFromTheRegionsOwnOrigin() {
        let offset = CGRect(x: 0, y: 100, width: 402, height: 629)
        let badge = CGRect(x: 328, y: 124, width: 50, height: 30)
        let expectedY: CGFloat = 124 + 30 + 6
        #expect(origin(badge: badge, region: offset).y == expectedY)
        #expect(origin(badge: badge, size: CGSize(width: 232, height: 800), region: offset).y == 100)
    }
}
