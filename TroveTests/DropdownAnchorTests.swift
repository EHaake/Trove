import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// What a badge's `.dropdownAnchor` tags actually reach the host as.
///
/// The host draws a dropdown only for an identifier that has an anchor, so a
/// tag that gets dropped on the way up is a badge that opens nothing — with
/// every wiring guard still green, since the wiring is in the view model.
/// That is exactly what happened at `cf3e1ee`, where the Items "…" carried
/// three stacked tags and published one (plan Q17 as corrected at T009f).
///
/// So this is measured rather than reasoned about: a real render, through
/// `renderBitmap` (the `DropdownPlacementTests` shape), with a real
/// `.overlayPreferenceValue` reader standing in for the host's, recording
/// what it was handed. The two cases are the two halves of the mechanism —
/// several tags on one view (the transform), and tags on two views (the
/// key's `reduce`).
@Suite("Dropdown anchors")
struct DropdownAnchorTests {
    /// What the reader was handed, and how often it ran. The count matters:
    /// a reader that never runs records no keys, which would otherwise look
    /// identical to a tag being dropped.
    @MainActor
    private final class AnchorProbe {
        private(set) var keys: Set<AnyHashable> = []
        private(set) var runs = 0

        func record(_ anchors: [AnyHashable: Anchor<CGRect>]) {
            keys = Set(anchors.keys)
            runs += 1
        }
    }

    /// A fixed-size stand-in for a badge, tagged and read the way the host
    /// tags and reads one.
    private func render(_ probe: AnchorProbe, @ViewBuilder content: () -> some View) throws {
        let view = content()
            .overlayPreferenceValue(DropdownAnchorKey.self) { anchors in
                let _ = probe.record(anchors)
                Color.clear
            }
        _ = try #require(renderBitmap(view), "ImageRenderer produced nothing — nothing was rendered to read anchors from.")
        try #require(probe.runs > 0, "The preference reader never ran under ImageRenderer, so this suite measured nothing.")
    }

    /// The Items badge's shape: three tags stacked on one view. All three
    /// have to arrive, or the badge they name opens nothing. Reverting
    /// `dropdownAnchor` to `anchorPreference` leaves one key here.
    @Test func threeTagsOnOneViewAllReachTheReader() throws {
        let probe = AnchorProbe()
        try render(probe) {
            Color.red
                .frame(width: 50, height: 30)
                .dropdownAnchor("a")
                .dropdownAnchor("b")
                .dropdownAnchor("c")
        }

        let expected: Set<AnyHashable> = ["a", "b", "c"]
        #expect(probe.keys == expected)
    }

    /// The other half: a second badge elsewhere on the screen publishes its
    /// own tag, and the key's `reduce` merges the two subtrees rather than
    /// letting one win. A `reduce` of `value = nextValue()` drops a key here.
    @Test func aSiblingBadgesTagMergesWithTheStackedThree() throws {
        let probe = AnchorProbe()
        try render(probe) {
            HStack(spacing: 0) {
                Color.red
                    .frame(width: 50, height: 30)
                    .dropdownAnchor("a")
                    .dropdownAnchor("b")
                    .dropdownAnchor("c")
                Color.blue
                    .frame(width: 50, height: 30)
                    .dropdownAnchor("d")
            }
        }

        let expected: Set<AnyHashable> = ["a", "b", "c", "d"]
        #expect(probe.keys == expected)
    }
}
