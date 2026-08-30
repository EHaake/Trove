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

    /// Design's own copy, from the item form and item detail mocks —
    /// including level 3, which `010`'s refresh renamed from "Undecided".
    /// Pinned because the last two shipped strings that weren't (the delete
    /// copy at T010a, "Yours" at T025a) each drifted unnoticed.
    @Test func usesDesignsWordingWhereDesignProvidedIt() {
        #expect(DesireLevel.undecided.summary == "On the fence")
        #expect(DesireLevel.keepingForNow.summary == "Keeping for now")
        #expect(DesireLevel.absolutelyKeeping.summary == "Absolutely keeping it")
    }

    // MARK: - The per-level hint (`010`)

    @Test(arguments: [true, false])
    func everyLevelHasADistinctEnoughHint(isValued: Bool) {
        let hints = DesireLevel.allCases.map { $0.detail(isValued: isValued) }
        #expect(hints.allSatisfy { !$0.isEmpty })
    }

    /// The rewording's whole point: no hint may promise behaviour `010`
    /// doesn't ship. The mock's originals described target-shortfall
    /// escalation and per-level exclusion overrides — neither exists, so
    /// neither may be described. (Restore the richer copy *with* the
    /// feature, not before it.)
    @Test(arguments: [true, false])
    func noHintDescribesUnbuiltSellPlanMechanics(isValued: Bool) {
        let forbidden = ["target", "far short", "unless you say otherwise", "override"]
        for level in DesireLevel.allCases {
            let hint = level.detail(isValued: isValued).lowercased()
            for phrase in forbidden {
                #expect(
                    hint.contains(phrase) == false,
                    "level \(level.rawValue) promises unbuilt behaviour: \(hint)"
                )
            }
        }
    }

    /// An unvalued item can't join a plan whatever its rating
    /// (`SellPlanViewModel.qualifies`), so a candidate-level hint must say so
    /// rather than claiming it'll be offered.
    @Test func candidateLevelsSayWhatAnUnvaluedItemActuallyDoes() {
        for level in DesireLevel.allCases where level.isSellCandidate {
            let unvalued = level.detail(isValued: false)
            #expect(unvalued.contains("value"), "level \(level.rawValue) said: \(unvalued)")
            #expect(unvalued != level.detail(isValued: true))
        }
    }

    /// A value changes nothing for a non-candidate: it isn't in the pool
    /// either way, and implying the value is what's holding it back would be
    /// the same false promise from the other direction.
    @Test func nonCandidateLevelsReadTheSameValuedOrNot() {
        for level in DesireLevel.allCases where !level.isSellCandidate {
            #expect(level.detail(isValued: true) == level.detail(isValued: false))
        }
    }

    /// Candidate and non-candidate levels must not read alike — the hint is
    /// the only place the threshold is stated in words.
    @Test func candidatesAndKeepersDoNotShareAHint() {
        let candidates = Set(DesireLevel.allCases.filter(\.isSellCandidate).map { $0.detail(isValued: true) })
        let keepers = Set(DesireLevel.allCases.filter { !$0.isSellCandidate }.map { $0.detail(isValued: true) })
        #expect(candidates.isDisjoint(with: keepers))
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
