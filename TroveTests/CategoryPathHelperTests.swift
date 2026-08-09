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
