import Foundation
import Testing
@testable import Trove

/// The taken-with relevance filter (T012a, spec Decision 7): a photo *of* the
/// searched gear outranks a snapshot taken *on* it. Run over a hand-built
/// fixture with no session, the `WikimediaDecodingTests` idiom. Every file in
/// the fixture carries a reusable licence, so the licence filter removes none
/// and the taken-with filter is the only thing under test.
@Suite("Wikimedia relevance")
struct WikimediaRelevanceTests {

    private func candidates(searching query: String) throws -> [StockPhotoCandidate] {
        try WikimediaDecoding.candidates(
            from: try wikimediaFixture("search-taken-with.json"), query: query, cap: 12
        )
    }

    // MARK: - Same-model taken-with is dropped

    @Test func aSameModelTakenWithFileIsDropped() throws {
        let titles = try candidates(searching: "Hasselblad X2D 100C ii").map(\.title)
        // The "Taken with Hasselblad X2D 100C" portrait is gone…
        #expect(!titles.contains("File:Portrait-on-X2D.jpg"),
                "a same-model taken-with photo survived: \(titles)")
        // …but the subject-category X2D product shot survives (it is not
        // "taken with" the X2D, it is *of* it).
        //
        // Mutation-verified: drop the `hasPrefix("taken with ")` guard in
        // `isTakenWithSearchedGear` (match any category containing the tokens)
        // and this file is wrongly dropped by its "Category:Hasselblad X2D" →
        // red.
        #expect(titles.contains("File:Hasselblad-X2D-product.jpg"),
                "the subject-category product shot was wrongly dropped: \(titles)")
    }

    // MARK: - Different-model taken-with is kept (the R5 case)

    @Test func aDifferentModelTakenWithFileIsKept() throws {
        let titles = try candidates(searching: "Canon R5").map(\.title)
        // "Taken with Canon EOS-1D X Mark II" is a *different* camera than the
        // searched R5 — the photo is of the R5, so it must survive.
        //
        // Mutation-verified: change the query-token filter to match on any
        // shared token (drop `filter { $0.contains(where: \.isNumber) }`) and
        // the shared brand word "canon" wrongly drops this file → red.
        #expect(titles.contains("File:Canon-R5-product.jpg"),
                "a different-model taken-with photo was wrongly dropped: \(titles)")
    }

    // MARK: - A query with no fused token drops nothing

    @Test func aNoFusedTokenQueryDropsNothing() throws {
        // "Leica Summicron" has no model designator fusing a letter and a
        // digit, so the filter has nothing to match and prunes nothing — all
        // five files survive.
        let titles = try candidates(searching: "Leica Summicron").map(\.title).sorted()
        #expect(titles == [
            "File:Canon-R5-product.jpg",
            "File:Hasselblad-X2D-product.jpg",
            "File:No-categories-file.jpg",
            "File:Portrait-on-X2D.jpg",
            "File:Sony-24-70-product.jpg",
        ])
    }

    // MARK: - A bare-number collision keeps the product shot

    @Test func aBareNumberCollisionKeepsTheProductShot() throws {
        // "Sony FE 24-70mm F2.8" fuses only {70mm, f2}; its bare numbers 24 and
        // 8 carry no letter and so are not model designators. The lens product
        // shot is "Taken with Apple iPhone 8" — whose only model-ish token, 8,
        // is bare — so nothing fused is shared and the shot must survive.
        //
        // Mutation-verified: revert the rule to the bare-digit filter
        // (`filter { $0.contains(where: \.isNumber) }`, no `.isLetter` clause)
        // and the shared bare "8" wrongly drops this product shot → red.
        let titles = try candidates(searching: "Sony FE 24-70mm F2.8").map(\.title)
        #expect(titles.contains("File:Sony-24-70-product.jpg"),
                "a bare-number collision wrongly dropped the product shot: \(titles)")
    }

    // MARK: - Absent/truncated categories keep the file

    @Test func aFileWithNoCategoriesIsKept() throws {
        // The no-categories file survives even a query that drops its
        // same-model neighbour — absence of categories reads as "keep".
        let titles = try candidates(searching: "Hasselblad X2D 100C ii").map(\.title)
        #expect(titles.contains("File:No-categories-file.jpg"),
                "a categories-absent file was wrongly dropped: \(titles)")
    }

    // MARK: - The classifier oracle, directly

    @Test func theMatchRuleMatchesTheTwoAnchorCases() {
        // R5 kept: shared brand word "canon" carries no digit, so a different
        // model never triggers a drop.
        #expect(WikimediaDecoding.isTakenWithSearchedGear(
            categoryTitles: ["Category:Taken with Canon EOS-1D X Mark II"],
            query: "Canon R5"
        ) == false)
        // X2D dropped: the shared digit-bearing designators x2d/100c match.
        #expect(WikimediaDecoding.isTakenWithSearchedGear(
            categoryTitles: ["Category:Taken with Hasselblad X2D 100C"],
            query: "Hasselblad X2D 100C ii"
        ) == true)
        // Brand-only overlap never drops.
        #expect(WikimediaDecoding.isTakenWithSearchedGear(
            categoryTitles: ["Category:Taken with Canon EOS-1D X Mark II"],
            query: "Canon"
        ) == false)
        // A subject category is not a taken-with category.
        #expect(WikimediaDecoding.isTakenWithSearchedGear(
            categoryTitles: ["Category:Hasselblad X2D"],
            query: "Hasselblad X2D 100C ii"
        ) == false)
    }
}
