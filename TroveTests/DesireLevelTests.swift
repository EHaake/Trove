import Foundation
import Testing
@testable import Trove

@Suite("DesireLevel")
struct DesireLevelTests {
    @Test func coversTheWholeOneToFiveScale() {
        #expect(DesireLevel.allCases.map(\.rawValue) == [1, 2, 3, 4, 5])
    }

    @Test(arguments: [(1, DesireLevel.readyToSell), (3, .undecided), (5, .absolutelyKeeping)])
    func mapsAValueToItsLevel(value: Int, expected: DesireLevel) {
        #expect(DesireLevel(clamping: value) == expected)
    }

    /// Stored values predate the view model's clamping rule, so anything
    /// reading `Item.desireToKeep` has to survive one outside 1–5.
    @Test(arguments: [(0, DesireLevel.readyToSell), (-4, .readyToSell), (6, .absolutelyKeeping), (99, .absolutelyKeeping)])
    func clampsOutOfRangeValues(value: Int, expected: DesireLevel) {
        #expect(DesireLevel(clamping: value) == expected)
    }

    @Test func everyLevelHasASummary() {
        #expect(DesireLevel.allCases.allSatisfy { !$0.summary.isEmpty })
    }

    @Test func summariesAreAllDistinct() {
        #expect(Set(DesireLevel.allCases.map(\.summary)).count == DesireLevel.allCases.count)
    }

    /// Design's own copy, from the item form and item detail mocks.
    @Test func usesDesignsWordingWhereDesignProvidedIt() {
        #expect(DesireLevel.keepingForNow.summary == "Keeping for now")
        #expect(DesireLevel.absolutelyKeeping.summary == "Absolutely keeping it")
    }

    /// The threshold has to agree with the Sell Plan's candidate rule in
    /// spec.md — desire 3 or lower. Two places encoding it invites drift, so
    /// this pins the one the UI reads.
    @Test func sellCandidacyMatchesTheSpecThreshold() {
        #expect(DesireLevel.readyToSell.isSellCandidate)
        #expect(DesireLevel.wouldLetItGo.isSellCandidate)
        #expect(DesireLevel.undecided.isSellCandidate)
        #expect(DesireLevel.keepingForNow.isSellCandidate == false)
        #expect(DesireLevel.absolutelyKeeping.isSellCandidate == false)
    }
}
