import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("CategoryPathHelper")
struct CategoryPathHelperTests {
    @Test func returnsNoPathsWhenNothingExists() throws {
        let context = try makeInMemoryContext()
        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.allCategoryPaths().isEmpty)
    }

    /// Dedup spans both entities — an item and a wishlist item sharing a path
    /// should surface it once, not twice.
    @Test func dedupsAcrossItemsAndWishlistItems() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Photography/Cameras"))
        context.insert(Item(categoryPath: "Photography/Lenses"))
        context.insert(WishlistItem(categoryPath: "Photography/Cameras"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)
        let paths = try helper.allCategoryPaths()

        #expect(paths.count == 2)
        #expect(paths == ["Photography/Cameras", "Photography/Lenses"])
    }

    @Test func excludesEmptyPaths() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: ""))
        context.insert(Item(categoryPath: "Music/Guitars"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.allCategoryPaths() == ["Music/Guitars"])
    }

    @Test func suggestionsFilterByPrefixCaseInsensitively() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Photography/Cameras"))
        context.insert(Item(categoryPath: "Photography/Lenses"))
        context.insert(Item(categoryPath: "Music/Guitars/Electric"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.suggestions(matching: "photography") == ["Photography/Cameras", "Photography/Lenses"])
        #expect(try helper.suggestions(matching: "PHOTOGRAPHY/CAM") == ["Photography/Cameras"])
        #expect(try helper.suggestions(matching: "Music") == ["Music/Guitars/Electric"])
    }

    /// A prefix that matches nowhere in the path (only a substring elsewhere)
    /// should not match — this is prefix filtering, not full-text search.
    @Test func suggestionsDoNotMatchMidPathSubstrings() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Music/Guitars/Electric"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.suggestions(matching: "Guitars").isEmpty)
    }

    @Test func emptyPrefixReturnsEveryPath() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Photography/Cameras"))
        context.insert(Item(categoryPath: "Music/Guitars"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.suggestions(matching: "").count == 2)
    }

    /// The whole point of canonicalization: retyping an existing path with
    /// different casing reuses whatever casing was already stored.
    @Test func canonicalizeReusesExistingCasing() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Photography/Cameras"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.canonicalize("photography/cameras") == "Photography/Cameras")
        #expect(try helper.canonicalize("PHOTOGRAPHY/CAMERAS") == "Photography/Cameras")
    }

    @Test func canonicalizeReturnsANewPathAsTyped() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Photography/Cameras"))
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.canonicalize("Music/Amps") == "Music/Amps")
    }

    /// First-used casing wins, permanently — even once a second, differently
    /// cased record using the same path exists.
    @Test func canonicalizeKeepsTheFirstCasingEvenAfterALaterRecordUsesDifferentCasing() throws {
        let context = try makeInMemoryContext()
        let first = Item(categoryPath: "Photography/Cameras")
        context.insert(first)
        try context.save()

        // Created after `first`, and with different casing.
        let second = Item(categoryPath: "photography/cameras")
        context.insert(second)
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.canonicalize("PHOTOGRAPHY/CAMERAS") == "Photography/Cameras")
    }

    /// The helper concatenates items before wishlist items before sorting, so
    /// dropping the sort would hand every casing contest to whichever entity
    /// comes first in that concatenation. Here the earlier record is the
    /// wishlist item, which loses unless creation time genuinely decides it.
    @Test func canonicalizeLetsAnEarlierWishlistItemBeatALaterItem() throws {
        let context = try makeInMemoryContext()

        let wishlistItem = WishlistItem(categoryPath: "Photography/Lenses")
        wishlistItem.createdAt = Date(timeIntervalSince1970: 1_000)
        context.insert(wishlistItem)

        let item = Item(categoryPath: "photography/lenses")
        item.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(item)
        try context.save()

        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.canonicalize("PHOTOGRAPHY/LENSES") == "Photography/Lenses")
    }

    @Test func emptyInputCanonicalizesToItself() throws {
        let context = try makeInMemoryContext()
        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.canonicalize("") == "")
    }
}

/// Chip labels: leaf-only where that's unambiguous, widened where it isn't.
/// Display only — filtering still matches the full path prefix.
@Suite("Category chip labels")
struct CategoryDisplayLabelTests {
    @Test func showsJustTheLeafWhenItIsUnique() {
        let labels = CategoryPathHelper.displayLabels(for: [
            "Photography/Cameras",
            "Photography/Lenses",
            "Music/Amps",
        ])

        #expect(labels["Photography/Cameras"] == "Cameras")
        #expect(labels["Photography/Lenses"] == "Lenses")
        #expect(labels["Music/Amps"] == "Amps")
    }

    /// The case the rule exists for.
    @Test func widensBothSidesOfALeafCollision() {
        let labels = CategoryPathHelper.displayLabels(for: ["Music/Amps", "Audio/Amps"])

        #expect(labels["Music/Amps"] == "Music/Amps")
        #expect(labels["Audio/Amps"] == "Audio/Amps")
    }

    /// Widening is per-path: a collision between two paths shouldn't lengthen
    /// the labels of paths that were never ambiguous.
    @Test func leavesUnaffectedPathsAtTheirLeaf() {
        let labels = CategoryPathHelper.displayLabels(for: [
            "Music/Amps",
            "Audio/Amps",
            "Photography/Cameras",
        ])

        #expect(labels["Photography/Cameras"] == "Cameras")
        #expect(labels["Music/Amps"] == "Music/Amps")
    }

    @Test func showsTheLeafOfADeepPath() {
        let labels = CategoryPathHelper.displayLabels(for: [
            "Music/Guitars/Electric",
            "Music/Guitars/Acoustic",
        ])

        #expect(labels["Music/Guitars/Electric"] == "Electric")
        #expect(labels["Music/Guitars/Acoustic"] == "Acoustic")
    }

    /// spec.md's own three-level example, colliding at the leaf: last two
    /// segments is enough to tell them apart without the full path.
    @Test func widensADeepPathToTwoSegments() {
        let labels = CategoryPathHelper.displayLabels(for: [
            "Music/Guitars/Acoustic",
            "Music/Basses/Acoustic",
        ])

        #expect(labels["Music/Guitars/Acoustic"] == "Guitars/Acoustic")
        #expect(labels["Music/Basses/Acoustic"] == "Basses/Acoustic")
    }

    /// Two segments isn't always enough. Rather than showing the same chip
    /// twice, these fall back to the full path, which is unique by definition.
    @Test func fallsBackToTheFullPathWhenTwoSegmentsStillCollide() {
        let labels = CategoryPathHelper.displayLabels(for: [
            "Studio/Music/Amps",
            "Home/Music/Amps",
        ])

        #expect(labels["Studio/Music/Amps"] == "Studio/Music/Amps")
        #expect(labels["Home/Music/Amps"] == "Home/Music/Amps")
    }

    @Test func labelsEveryPathExactlyOnce() {
        let paths = ["Photography/Cameras", "Music/Amps", "Audio/Amps", "Accessories"]
        let labels = CategoryPathHelper.displayLabels(for: paths)

        #expect(labels.count == paths.count)
        #expect(Set(labels.values).count == paths.count)
    }

    @Test func handlesASingleSegmentPath() {
        #expect(CategoryPathHelper.displayLabels(for: ["Accessories"])["Accessories"] == "Accessories")
    }

    @Test func handlesNoPaths() {
        #expect(CategoryPathHelper.displayLabels(for: []).isEmpty)
    }
}

/// Inline meta lines cap at the trailing segments, which is what stops a
/// three-level path truncating mid-word in a list row.
@Suite("Category meta-line segments")
struct CategoryTrailingSegmentTests {
    @Test func keepsAShortPathWhole() {
        #expect(CategoryPathHelper.trailingSegments(of: "Photography/Cameras") == ["Photography", "Cameras"])
        #expect(CategoryPathHelper.trailingSegments(of: "Accessories") == ["Accessories"])
    }

    /// The case that was truncating: "MUSIC · GUITARS · ELE…".
    @Test func dropsTheLeadingSegmentsOfADeepPath() {
        #expect(CategoryPathHelper.trailingSegments(of: "Music/Guitars/Electric") == ["Guitars", "Electric"])
    }

    @Test func keepsOnlyTheTrailingTwoOfAVeryDeepPath() {
        #expect(
            CategoryPathHelper.trailingSegments(of: "Home/Studio/Music/Guitars/Electric")
                == ["Guitars", "Electric"]
        )
    }

    @Test func handlesAnEmptyPath() {
        #expect(CategoryPathHelper.trailingSegments(of: "").isEmpty)
    }

    @Test func honoursACustomLimit() {
        #expect(CategoryPathHelper.trailingSegments(of: "Music/Guitars/Electric", limit: 1) == ["Electric"])
        #expect(
            CategoryPathHelper.trailingSegments(of: "Music/Guitars/Electric", limit: 5)
                == ["Music", "Guitars", "Electric"]
        )
    }
}

/// The ordering rule tested directly, where the input order is ours to choose.
/// Going through a `ModelContext` can't pin this down: `FetchDescriptor`
/// promises no ordering, so an integration test asserts against whatever
/// SwiftData happens to return rather than against the comparator.
@Suite("Earliest-casing-wins rule")
struct EarliestCasingRuleTests {
    private typealias Record = (path: String, createdAt: Date)

    private func record(_ path: String, at seconds: TimeInterval) -> Record {
        (path: path, createdAt: Date(timeIntervalSince1970: seconds))
    }

    /// The input is deliberately newest-first, so returning the earliest
    /// casing requires actually sorting rather than taking what arrives first.
    @Test func earliestCasingWinsWhenInputArrivesNewestFirst() {
        let result = CategoryPathHelper.distinctPathsPreferringEarliestCasing([
            record("photography/cameras", at: 2_000),
            record("Photography/Cameras", at: 1_000),
        ])

        #expect(result == ["Photography/Cameras"])
    }

    @Test func earliestCasingWinsWhenInputArrivesOldestFirst() {
        let result = CategoryPathHelper.distinctPathsPreferringEarliestCasing([
            record("Photography/Cameras", at: 1_000),
            record("photography/cameras", at: 2_000),
        ])

        #expect(result == ["Photography/Cameras"])
    }

    /// Three casings, shuffled, with the winner buried in the middle.
    @Test func earliestCasingWinsAmongSeveralCompetingCasings() {
        let result = CategoryPathHelper.distinctPathsPreferringEarliestCasing([
            record("PHOTOGRAPHY/CAMERAS", at: 3_000),
            record("Photography/Cameras", at: 1_000),
            record("photography/cameras", at: 2_000),
        ])

        #expect(result == ["Photography/Cameras"])
    }

    /// Distinct paths come back in creation order, not input order — that's
    /// what makes `allCategoryPaths()`'s alphabetical sort the only thing
    /// deciding display order.
    @Test func distinctPathsComeBackInCreationOrder() {
        let result = CategoryPathHelper.distinctPathsPreferringEarliestCasing([
            record("Music/Guitars", at: 3_000),
            record("Photography/Cameras", at: 1_000),
            record("Photography/Lenses", at: 2_000),
        ])

        #expect(result == ["Photography/Cameras", "Photography/Lenses", "Music/Guitars"])
    }

    @Test func emptyPathsAreDropped() {
        let result = CategoryPathHelper.distinctPathsPreferringEarliestCasing([
            record("", at: 1_000),
            record("Music/Guitars", at: 2_000),
            record("", at: 3_000),
        ])

        #expect(result == ["Music/Guitars"])
    }

    @Test func noRecordsYieldsNoPaths() {
        #expect(CategoryPathHelper.distinctPathsPreferringEarliestCasing([]).isEmpty)
    }
}

/// Two rules that used to be one. Autocomplete matches a fragment mid-word;
/// a filter matches whole categories. Conflating them meant selecting "Audio"
/// quietly swept in "Audiophile" — the list showing items from a category the
/// user hadn't picked, with nothing on screen to explain why.
@Suite("Category scoping vs autocomplete")
struct CategoryScopeTests {
    // MARK: - Filtering: whole segments only

    @Test func aPathIsWithinItsOwnCategory() {
        #expect(CategoryPathHelper.path("Photography/Cameras", isWithin: "Photography"))
        #expect(CategoryPathHelper.path("Photography/Cameras", isWithin: "Photography/Cameras"))
    }

    @Test func anEmptyScopeHoldsEverything() {
        #expect(CategoryPathHelper.path("Anything/At/All", isWithin: ""))
        #expect(CategoryPathHelper.path("Anything/At/All", isWithin: "   "))
    }

    @Test func scopingIgnoresCase() {
        #expect(CategoryPathHelper.path("Photography/Cameras", isWithin: "PHOTOGRAPHY"))
        #expect(CategoryPathHelper.path("photography/cameras", isWithin: "Photography"))
    }

    /// The bug this rule exists for, in both the shapes it takes.
    @Test(arguments: [
        ("Audiophile/Magazines", "Audio"),
        ("Music/Amplifiers", "Music/Amps"),
        ("Photography2/Cameras", "Photography"),
    ])
    func aScopeStopsAtASegmentBoundary(path: String, scope: String) {
        #expect(CategoryPathHelper.path(path, isWithin: scope) == false)
    }

    @Test func aSiblingCategoryIsNotWithinScope() {
        #expect(CategoryPathHelper.path("Music/Guitars", isWithin: "Photography") == false)
    }

    // MARK: - Autocomplete: fragments are the point

    /// The same inputs the filter rejects, which autocomplete must accept —
    /// this is why they can't be one function.
    @Test func typingAFragmentStillSuggestsTheFullPath() {
        #expect(CategoryPathHelper.path("Photography/Cameras", matchesPrefix: "Photo"))
        #expect(CategoryPathHelper.path("Audiophile/Magazines", matchesPrefix: "Audio"))
    }

    // MARK: - Grouping

    @Test func groupsByFirstSegmentAtTheTopLevel() {
        #expect(CategoryPathHelper.categoryGroupKey(for: "Photography/Cameras", under: "") == "Photography")
        #expect(CategoryPathHelper.categoryGroupKey(for: "Music/Guitars/Electric", under: "") == "Music")
    }

    @Test func groupsByTheNextSegmentDownWhenScoped() {
        #expect(
            CategoryPathHelper.categoryGroupKey(for: "Music/Guitars/Electric", under: "Music")
                == "Music/Guitars"
        )
        #expect(
            CategoryPathHelper.categoryGroupKey(for: "Music/Guitars/Electric", under: "Music/Guitars")
                == "Music/Guitars/Electric"
        )
    }

    /// An item filed straight at the scope's own level still needs a row.
    @Test func aPathWithNothingBelowTheScopeGroupsUnderItself() {
        #expect(CategoryPathHelper.categoryGroupKey(for: "Accessories", under: "") == "Accessories")
        #expect(CategoryPathHelper.categoryGroupKey(for: "Music", under: "Music") == "Music")
    }
}
