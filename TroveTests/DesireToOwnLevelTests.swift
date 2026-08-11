import Foundation
import Testing
@testable import Trove

@Suite("DesireToOwnLevel")
struct DesireToOwnLevelTests {
    @Test(arguments: [(1, DesireToOwnLevel.someday), (2, .soon), (3, .next)])
    func mapsEachStoredValueToItsLevel(raw: Int, expected: DesireToOwnLevel) {
        #expect(DesireToOwnLevel(clamping: raw) == expected)
    }

    /// The range is enforced in the view model, not the schema, so anything
    /// reading a stored value has to cope with one written before that rule —
    /// or by a future import.
    @Test(arguments: [-99, -1, 0, 4, 5, 99])
    func clampsValuesOutsideTheScale(raw: Int) {
        let level = DesireToOwnLevel(clamping: raw)
        #expect(DesireToOwnLevel.allCases.contains(level))
        #expect(level == (raw < 1 ? .someday : .next))
    }

    @Test func usesTheBriefsOwnWords() {
        #expect(DesireToOwnLevel.someday.summary == "Someday")
        #expect(DesireToOwnLevel.soon.summary == "Soon")
        #expect(DesireToOwnLevel.next.summary == "Next")
    }

    /// Coarser than the owned-item scale on purpose — spec.md's reasoning is
    /// that three levels match the resolution people have about their own
    /// wants, and keep the two ratings from reading as one measurement.
    @Test func isDeliberatelyCoarserThanTheDesireToKeepScale() {
        #expect(DesireToOwnLevel.allCases.count == 3)
        #expect(DesireToOwnLevel.allCases.count < DesireLevel.allCases.count)
    }
}
