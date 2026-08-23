import Testing
import UIKit
@testable import Trove

/// A system symbol that doesn't exist draws nothing — no crash, no warning,
/// just a gap above the headline where the mark should be. Exactly the failure
/// `TabIconTests` was written for, arriving through the other API.
///
/// Worth guarding because nothing else would notice. The first version of
/// these states used `arrow.trianglehead.2.clockwise.rotate.90.icloud`, picked
/// from memory; it turned out to be real, but only this test could have said
/// so, and the next such guess is the one that isn't.
///
/// Mutation-verified against a name that genuinely doesn't exist — the first
/// attempt used a *valid* alternative and passed, which proved nothing.
///
/// **Uses `UIImage` deliberately**, the same flagged exception `TabIconTests`
/// documents: `Image` can't report whether an asset resolved.
@Suite("Empty state marks")
struct EmptyStateMarkTests {
    @Test func theStillSyncingMarkResolves() throws {
        guard case .system(let name) = EmptyStateView.Mark.stillSyncing else {
            Issue.record("The shared sync mark stopped being a system symbol")
            return
        }

        #expect(
            UIImage(systemName: name) != nil,
            "No SF Symbol named \"\(name)\" — all four sync empty states draw a blank space"
        )
    }
}
