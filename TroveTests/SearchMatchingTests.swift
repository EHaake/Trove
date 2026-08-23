import Foundation
import Testing
@testable import Trove

/// The shared search rule. Both list screens run through this, so a change
/// here changes both — which is the point of it existing, and the reason it's
/// worth pinning behaviour rather than assuming `localizedStandardContains`
/// does what the name suggests.
@Suite("Search matching")
struct SearchMatchingTests {
    @Test func anEmptyQueryMatchesEverything() {
        #expect(SearchMatching.matches(query: "", in: ["Leica M6"]))
        #expect(SearchMatching.matches(query: "", in: [nil]))
    }

    /// Autocorrect leaves trailing spaces behind constantly. A query of one
    /// space emptying the list looks like the data went missing.
    @Test(arguments: [" ", "   ", "\n", "\t"])
    func aWhitespaceOnlyQueryMatchesEverything(query: String) {
        #expect(SearchMatching.matches(query: query, in: ["Leica M6"]))
    }

    @Test func matchesASubstringAnywhereInAField() {
        #expect(SearchMatching.matches(query: "eica", in: ["Leica M6"]))
        #expect(SearchMatching.matches(query: "M6", in: ["Leica M6"]))
    }

    @Test(arguments: ["leica", "LEICA", "LeIcA"])
    func ignoresCase(query: String) {
        #expect(SearchMatching.matches(query: query, in: ["Leica M6"]))
    }

    /// Gear names are full of them, and half the listings you copy a name from
    /// drop the accents. Typing the plain letter finds the accented one.
    @Test func ignoresDecomposableDiacritics() {
        #expect(SearchMatching.matches(query: "voigtlander", in: ["Voigtländer Nokton 50mm"]))
        #expect(SearchMatching.matches(query: "Voigtländer", in: ["Voigtlander Nokton 50mm"]))
    }

    /// The boundary of that, pinned so it isn't rediscovered as a bug: `ø` is
    /// its own letter in Unicode rather than an accented `o`, so no amount of
    /// diacritic folding turns "rode" into "Røde". Typing any part of the name
    /// as written still finds it.
    @Test func doesNotFoldLettersThatMerelyLookAccented() {
        #expect(SearchMatching.matches(query: "rode", in: ["Røde NT1"]) == false)
        #expect(SearchMatching.matches(query: "røde", in: ["Røde NT1"]))
        #expect(SearchMatching.matches(query: "NT1", in: ["Røde NT1"]))
    }

    @Test func searchesEveryFieldGiven() {
        let fields: [String?] = ["Leica M6", "2842156"]
        #expect(SearchMatching.matches(query: "2842", in: fields))
        #expect(SearchMatching.matches(query: "Leica", in: fields))
    }

    /// An absent serial number is just a field that can't match, so callers
    /// pass it straight in without unwrapping.
    @Test func nilFieldsDoNotMatchAndDoNotCrash() {
        #expect(SearchMatching.matches(query: "anything", in: [nil, nil]) == false)
        #expect(SearchMatching.matches(query: "M6", in: [nil, "Leica M6"]))
    }

    @Test func reportsNoMatchWhenTheQueryIsAbsentFromEveryField() {
        #expect(SearchMatching.matches(query: "Hasselblad", in: ["Leica M6", "2842156"]) == false)
    }

    /// The query is trimmed before matching, so a copied-and-pasted serial
    /// with a trailing space still finds its item.
    @Test func trimsTheQueryBeforeMatching() {
        #expect(SearchMatching.matches(query: "  Leica  ", in: ["Leica M6"]))
        #expect(SearchMatching.normalized("  Leica  ") == "Leica")
    }
}
