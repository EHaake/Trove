import Foundation
import SwiftData
import Testing
@testable import Trove

/// The empty states as the view models actually derive them, against a real
/// store — `ListEmptyReasonTests` covers the rule in isolation, this covers the
/// wiring into it.
///
/// The wiring is where a correct rule still goes wrong: `totalCount` counting
/// the filtered set instead of the whole fetch would make every filtered-empty
/// list claim the collection is empty, and the rule would be blameless.
@Suite("Empty states")
struct EmptyStateTests {
    // MARK: - Items

    @Test func aFreshStoreSaysNothingHasBeenAdded() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = ItemListViewModel(modelContext: context)

        viewModel.load()

        #expect(viewModel.emptyReason == .nothingAdded)
    }

    /// The wiring test. With items present and a filter excluding them all,
    /// `totalCount` has to be the unfiltered count or this reports an empty
    /// collection.
    @Test func aFilterThatExcludesEverythingIsNotAnEmptyCollection() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        context.insert(Item(name: "Blues Junior", categoryPath: "Music/Amps"))

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Audio"
        viewModel.load()

        #expect(viewModel.emptyReason == .categoryMatchedNothing)
    }

    @Test func aSearchWithNoMatchesQuotesTheQuery() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "hasselblad"
        viewModel.load()

        #expect(viewModel.emptyReason == .searchMatchedNothing(query: "hasselblad"))
    }

    /// End to end for the case the dashboard callout creates: one un-valued
    /// item, filter on, then the item gets a value.
    @Test func valuingTheLastItemTurnsTheUnvaluedFilterIntoASuccessState() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let item = Item(name: "Sennheiser HD 600", categoryPath: "Audio/Headphones")
        context.insert(item)

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.load()
        #expect(viewModel.emptyReason == nil, "The un-valued item should still be listed")

        item.currentValueCents = 32_000
        viewModel.load()

        #expect(viewModel.emptyReason == .everythingIsValued)
    }

    @Test func aListWithRowsHasNoEmptyState() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.emptyReason == nil)
    }

    // MARK: - Wishlist

    @Test func anEmptyWishlistSaysNothingHasBeenAdded() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = WishlistViewModel(modelContext: context)

        viewModel.load()

        #expect(viewModel.emptyReason == .nothingAdded)
    }

    /// The case T046 called out as never having been exercised.
    @Test func aWishlistCategoryThatHoldsNothing() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps"))

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(viewModel.emptyReason == .categoryMatchedNothing)
    }

    @Test func aWishlistSearchWithNoMatches() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps"))

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.searchText = "summicron"
        viewModel.load()

        #expect(viewModel.emptyReason == .searchMatchedNothing(query: "summicron"))
    }

    // MARK: - Dashboard

    /// `isEmpty` is about rows; `hasAnyValues` is about money. Conflating them
    /// is what left the screen reporting a collection as worth $0.
    @Test func itemsWithNoValuesAreNotAnEmptyDashboard() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        context.insert(Item(name: "Blues Junior", categoryPath: "Music/Amps"))

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(!viewModel.isEmpty, "Two items is not an empty dashboard")
        #expect(!viewModel.hasAnyValues, "Neither item has a value")
    }

    @Test func oneValuedItemIsEnoughToShowTheFigures() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras",
                            currentValueCents: 345_000))
        context.insert(Item(name: "Blues Junior", categoryPath: "Music/Amps"))

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.hasAnyValues)
    }

    @Test func anEmptyDashboardHasNoValuesEither() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = DashboardViewModel(modelContext: context)

        viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(!viewModel.hasAnyValues)
    }

    /// Per-row, not per-screen: a category with nothing priced shows no figure
    /// even when the dashboard around it has plenty.
    @Test func aCategoryWithNothingPricedReportsNoValue() throws {
        let context = ModelContext(try makeInMemoryContainer())
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras",
                            currentValueCents: 345_000))
        context.insert(Item(name: "Blues Junior", categoryPath: "Music/Amps"))

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        let music = try #require(viewModel.breakdown.first { $0.label == "Music" })
        let photography = try #require(viewModel.breakdown.first { $0.label == "Photography" })

        #expect(!music.hasAnyValues)
        #expect(photography.hasAnyValues)
    }

    // MARK: - Sell plan

    @Test func aSellPlanWithNoOwnedGear() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let wanted = WishlistItem(name: "Summicron 35mm", categoryPath: "Photography/Lenses")
        context.insert(wanted)

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wanted.id)
        viewModel.load()

        #expect(viewModel.emptyReason == .nothingOwned)
    }

    /// Owned gear, all of it valued, none of it rated low enough.
    @Test func everythingRatedAKeeper() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let wanted = WishlistItem(name: "Summicron 35mm", categoryPath: "Photography/Lenses")
        context.insert(wanted)
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras",
                            currentValueCents: 345_000, desireToKeep: 5))
        context.insert(Item(name: "Hasselblad", categoryPath: "Photography/Cameras",
                            currentValueCents: 178_000, desireToKeep: 4))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wanted.id)
        viewModel.load()

        #expect(viewModel.emptyReason == .everythingIsAKeeper)
    }

    /// Willing to part with something, but it has no value — the other half of
    /// the rule, and the distinction `SellPlanView` promised in prose before
    /// T047a made it real.
    @Test func willingToSellButNothingIsValued() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let wanted = WishlistItem(name: "Summicron 35mm", categoryPath: "Photography/Lenses")
        context.insert(wanted)
        context.insert(Item(name: "Squier CV50s", categoryPath: "Music/Guitars", desireToKeep: 1))
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras",
                            currentValueCents: 345_000, desireToKeep: 5))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wanted.id)
        viewModel.load()

        #expect(viewModel.emptyReason == .nothingValued)
    }

    @Test func aPoolWithCandidatesHasNoEmptyState() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let wanted = WishlistItem(name: "Summicron 35mm", categoryPath: "Photography/Lenses")
        context.insert(wanted)
        context.insert(Item(name: "Squier CV50s", categoryPath: "Music/Guitars",
                            currentValueCents: 38_000, desireToKeep: 1))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wanted.id)
        viewModel.load()

        #expect(viewModel.emptyReason == nil)
    }
}
