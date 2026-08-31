import Foundation
import Testing
@testable import Trove

/// T056. The three tab roots each answer a pull with their own `load()`.
///
/// Checked per screen and inside the modifier's own closure, not by asking
/// whether the file mentions `.refreshable` somewhere. That distinction isn't
/// hypothetical: the first version of `StillSyncingWiringTests` asked whether
/// `ContentView` contained a string anywhere, which one wired tab out of three
/// satisfied, and only mutation testing found it.
///
/// A source scan because there's nothing else to look at — `.refreshable`
/// installs an action in the environment for the nearest scrollable to run, and
/// no unit test can pull a list down. That the gesture, the indicator and the
/// action all work was established on the simulator instead, by slowing the
/// action until the spinner was catchable in a screenshot. What a test *can*
/// do is catch the gesture being wired to nothing, or to the wrong screen's
/// view model.
@Suite("Pull to refresh")
struct PullToRefreshTests {
    private nonisolated static let tabRoots = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
        "Trove/Views/Dashboard/DashboardView.swift",
    ]

    @Test(arguments: tabRoots)
    func eachTabRootRefreshesItself(path: String) throws {
        let bodies = SourceScan.closureBodies(after: ".refreshable", in: try SourceScan.production(path))

        #expect(bodies.count == 1, "\(path) has \(bodies.count) .refreshable modifiers, expected exactly 1")
        for body in bodies {
            #expect(
                body.contains("viewModel.load()"),
                """
                \(path) pulls to refresh but doesn't call its own view model's \
                load(), so the gesture animates and fetches nothing: \
                .refreshable {\(body)}
                """
            )
            // T037h: load() completes within a frame, so without the hold the
            // list snaps back up under the still-animating spinner. Pinned
            // per screen because the three closures are written
            // independently — dropping it from one reintroduces the defect
            // on that screen alone, silently.
            #expect(
                body.contains("RefreshPacing.hold()"),
                "\(path)'s refresh doesn't hold, so it snaps back under the spinner (T037h): .refreshable {\(body)}"
            )
        }
    }
}
