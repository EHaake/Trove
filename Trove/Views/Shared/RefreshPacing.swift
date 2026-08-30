import Foundation

/// Timing for pull-to-refresh over a local store.
///
/// `load()` completes within a frame (see the T056 note in CLAUDE.md), so a
/// bare `.refreshable { viewModel.load() }` returns before the spinner has
/// even settled — the scroll offset starts collapsing while the spinner is
/// still animating, and for a moment it draws on top of the first row. Both
/// lists showed it; the dashboard shares the mechanism. Holding the refresh
/// open briefly keeps the content parked below the spinner until the system
/// runs its own coordinated retraction.
///
/// Presentation pacing, not work — which is why it lives with the views
/// rather than inside the view models' load paths, where a sleep would slow
/// every unit test that calls `load()`.
enum RefreshPacing {
    static func hold() async {
        try? await Task.sleep(for: .milliseconds(500))
    }
}
