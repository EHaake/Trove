import Foundation
import SwiftData
import Testing
@testable import Trove

private func makeInMemoryContext() throws -> ModelContext {
    let configuration = ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: TroveSchema.schema, configurations: configuration)
    return ModelContext(container)
}

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

    @Test func emptyInputCanonicalizesToItself() throws {
        let context = try makeInMemoryContext()
        let helper = CategoryPathHelper(modelContext: context)

        #expect(try helper.canonicalize("") == "")
    }
}
