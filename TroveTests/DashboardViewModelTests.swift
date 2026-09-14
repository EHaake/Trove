import Foundation
import SwiftData
import Testing
@testable import Trove

private func insertItem(
    _ name: String,
    category: String = "Music/Guitars",
    paidCents: Int = 10_000,
    valueCents: Int? = nil,
    createdOffset: TimeInterval = 0,
    into context: ModelContext
) {
    let item = Item(
        name: name,
        categoryPath: category,
        purchasePriceCents: paidCents,
        currentValueCents: valueCents
    )
    // `createdAt` decides which casing of a path wins, so tests that care
    // need to control it rather than race the clock.
    item.createdAt = Date(timeIntervalSince1970: createdOffset)
    context.insert(item)
}

@Suite("DashboardViewModel — headline figures")
struct DashboardHeadlineTests {
    @Test func startsEmptyBeforeLoading() throws {
        let viewModel = DashboardViewModel(modelContext: try makeInMemoryContext())

        #expect(viewModel.isEmpty)
        #expect(viewModel.totalCurrentValueCents == 0)
        #expect(viewModel.totalSpentCents == 0)
    }

    @Test func totalsValueAndSpendAcrossEveryItem() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica", paidCents: 290_000, valueCents: 345_000, into: context)
        insertItem("Nikon", paidCents: 24_000, valueCents: 31_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 376_000)
        #expect(viewModel.totalSpentCents == 314_000)
        #expect(viewModel.valueDeltaCents == 62_000)
    }

    @Test func reportsALossWhenTheCollectionIsWorthLessThanItCost() throws {
        let context = try makeInMemoryContext()
        insertItem("Amp", paidCents: 69_000, valueCents: 54_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.valueDeltaCents == -15_000)
    }

    // MARK: - The un-valued rule

    /// spec.md: un-valued items are excluded from the total but counted
    /// separately, so the figure reads as a floor.
    @Test func excludesUnvaluedItemsFromTheTotalAndCountsThemInstead() throws {
        let context = try makeInMemoryContext()
        insertItem("Valued", paidCents: 10_000, valueCents: 50_000, into: context)
        insertItem("Unvalued", paidCents: 40_000, valueCents: nil, into: context)
        insertItem("Also unvalued", paidCents: 30_000, valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 50_000)
        #expect(viewModel.unvaluedCount == 2)
        #expect(viewModel.valuedCount == 1)
        #expect(viewModel.totalItemCount == 3)
    }

    /// The half that's easy to get wrong. If spend counted all three items
    /// while value counted one, the gain would come out at 50,000 − 80,000 =
    /// −30,000: a collection that has doubled in value reporting a loss,
    /// purely because two items haven't been appraised yet.
    @Test func spendExcludesUnvaluedItemsToo() throws {
        let context = try makeInMemoryContext()
        insertItem("Valued", paidCents: 25_000, valueCents: 50_000, into: context)
        insertItem("Unvalued", paidCents: 40_000, valueCents: nil, into: context)
        insertItem("Also unvalued", paidCents: 30_000, valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.totalSpentCents == 25_000)
        #expect(viewModel.valueDeltaCents == 25_000)
    }

    /// The property that makes the screen readable: whatever the figures are,
    /// the two above always account for the third.
    ///
    /// Asserted against literals written out by hand from the fixture above,
    /// not against the view model's own arithmetic. The previous form —
    /// `totalCurrentValueCents - totalSpentCents == valueDeltaCents` — was a
    /// tautology, since `valueDeltaCents` *is* that subtraction: found at
    /// 002/T013, where a mutation making the value total read the market
    /// medians instead of the person's values left this test green.
    @Test func theThreeHeadlineFiguresAlwaysReconcile() throws {
        let context = try makeInMemoryContext()
        insertItem("A", paidCents: 12_345, valueCents: 20_000, into: context)
        insertItem("B", paidCents: 90_000, valueCents: 5_000, into: context)
        insertItem("C", paidCents: 7_777, valueCents: nil, into: context)
        insertItem("D", paidCents: 400, valueCents: 999, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        // A, B and D are valued; C is not, so neither its value nor its
        // 7,777 of spend belongs to any of the three.
        #expect(viewModel.totalCurrentValueCents == 20_000 + 5_000 + 999)
        #expect(viewModel.totalSpentCents == 12_345 + 90_000 + 400)
        #expect(viewModel.valueDeltaCents == (20_000 + 5_000 + 999) - (12_345 + 90_000 + 400))
    }

    @Test func everythingIsZeroWhenNoItemHasAValue() throws {
        let context = try makeInMemoryContext()
        insertItem("One", paidCents: 10_000, valueCents: nil, into: context)
        insertItem("Two", paidCents: 20_000, valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 0)
        #expect(viewModel.totalSpentCents == 0)
        #expect(viewModel.valueDeltaCents == 0)
        #expect(viewModel.unvaluedCount == 2)
        #expect(viewModel.isEmpty == false)
    }

    // MARK: - The ruler

    @Test func valuedShareIsFullWhenEveryItemHasAValue() throws {
        let context = try makeInMemoryContext()
        insertItem("A", valueCents: 1, into: context)
        insertItem("B", valueCents: 2, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.valuedShare == 1)
    }

    @Test func valuedShareTracksHowManyItemsAreAppraised() throws {
        let context = try makeInMemoryContext()
        insertItem("A", valueCents: 1, into: context)
        insertItem("B", valueCents: nil, into: context)
        insertItem("C", valueCents: nil, into: context)
        insertItem("D", valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.valuedShare == 0.25)
    }

    /// Guards the division, which would otherwise be 0/0 on a fresh install.
    @Test func valuedShareIsZeroWithNoItemsAtAll() throws {
        let viewModel = DashboardViewModel(modelContext: try makeInMemoryContext())
        viewModel.load()

        #expect(viewModel.valuedShare == 0)
    }
}

@Suite("DashboardViewModel — category breakdown")
struct DashboardBreakdownTests {
    @Test func groupsByTopLevelCategory() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica", category: "Photography/Cameras", valueCents: 300_000, into: context)
        insertItem("Nikon", category: "Photography/Lenses", valueCents: 30_000, into: context)
        insertItem("Amp", category: "Music/Amps", valueCents: 50_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.breakdown.map(\.path) == ["Photography", "Music"])
        #expect(viewModel.breakdown.map(\.itemCount) == [2, 1])
        #expect(viewModel.categoryCount == 2)
    }

    @Test func ordersByValueByDefault() throws {
        let context = try makeInMemoryContext()
        insertItem("Cheap", category: "Accessories", valueCents: 1_000, into: context)
        insertItem("Dear", category: "Photography", valueCents: 900_000, into: context)
        insertItem("Middling", category: "Music", valueCents: 50_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.breakdownOrder == .value)
        #expect(viewModel.breakdown.map(\.label) == ["Photography", "Music", "Accessories"])
    }

    @Test func reordersByItemCountOnRequest() throws {
        let context = try makeInMemoryContext()
        insertItem("Dear", category: "Photography", valueCents: 900_000, into: context)
        insertItem("A", category: "Music", valueCents: 1_000, into: context)
        insertItem("B", category: "Music", valueCents: 1_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.breakdownOrder = .count
        viewModel.load()

        #expect(viewModel.breakdown.map(\.label) == ["Music", "Photography"])
    }

    /// Same reasoning as the item list: equal keys must not leave the order to
    /// `FetchDescriptor`, which guarantees none.
    @Test func breaksTiesByLabelSoOrderIsDeterministic() throws {
        let context = try makeInMemoryContext()
        insertItem("A", category: "Charlie", valueCents: 5_000, into: context)
        insertItem("B", category: "alpha", valueCents: 5_000, into: context)
        insertItem("C", category: "Bravo", valueCents: 5_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.breakdown.map(\.label) == ["alpha", "Bravo", "Charlie"])
    }

    @Test func sharesAreProportionsOfValueNotOfItemCount() throws {
        let context = try makeInMemoryContext()
        insertItem("One big", category: "Photography", valueCents: 75_000, into: context)
        insertItem("Small", category: "Music", valueCents: 12_500, into: context)
        insertItem("Small too", category: "Music", valueCents: 12_500, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        let photography = try #require(viewModel.breakdown.first { $0.label == "Photography" })
        let music = try #require(viewModel.breakdown.first { $0.label == "Music" })

        // Photography is one item of three but three quarters of the value.
        #expect(viewModel.valueShare(of: photography) == 0.75)
        #expect(viewModel.valueShare(of: music) == 0.25)
    }

    /// The breakdown has to account for the whole total: the stacked bar's
    /// widths and the row percentages both come from `valueShare(of:)`, so a
    /// category quietly dropping out of the grouping would leave a bar that
    /// doesn't fill and percentages that don't add up, with no other symptom.
    @Test func everyCategorySliceTogetherAccountsForTheWholeTotal() throws {
        let context = try makeInMemoryContext()
        insertItem("A", category: "Photography/Cameras", valueCents: 345_000, into: context)
        insertItem("B", category: "Music/Guitars/Electric", valueCents: 38_000, into: context)
        insertItem("C", category: "Accessories", valueCents: 5_000, into: context)
        insertItem("D", category: "Audio/Headphones", valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        let summed = viewModel.breakdown.reduce(0) { $0 + $1.currentValueCents }
        #expect(summed == viewModel.totalCurrentValueCents)

        let shares = viewModel.breakdown.reduce(0.0) { $0 + viewModel.valueShare(of: $1) }
        #expect(abs(shares - 1) < 0.0001)

        // The un-valued item still belongs to a category, so the item counts
        // have to account for it even though its value can't.
        let counted = viewModel.breakdown.reduce(0) { $0 + $1.itemCount }
        #expect(counted == viewModel.totalItemCount)
    }

    @Test func sharesAreZeroRatherThanNaNWhenNothingIsValued() throws {
        let context = try makeInMemoryContext()
        insertItem("Unvalued", category: "Photography", valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        let slice = try #require(viewModel.breakdown.first)
        #expect(viewModel.valueShare(of: slice) == 0)
        #expect(viewModel.valueShare(of: slice).isNaN == false)
    }

    @Test func countsUnvaluedItemsPerCategory() throws {
        let context = try makeInMemoryContext()
        insertItem("Valued", category: "Audio/Headphones", valueCents: 20_000, into: context)
        insertItem("Not", category: "Audio/Amps", valueCents: nil, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        let audio = try #require(viewModel.breakdown.first)
        #expect(audio.itemCount == 2)
        #expect(audio.unvaluedCount == 1)
    }

    /// An item filed at the top level has nothing below it, so opening its row
    /// would show the same numbers again.
    @Test func rowsWithNothingUnderneathCannotBeDrilledInto() throws {
        let context = try makeInMemoryContext()
        insertItem("Bag", category: "Accessories", valueCents: 5_000, into: context)
        insertItem("Leica", category: "Photography/Cameras", valueCents: 300_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        let accessories = try #require(viewModel.breakdown.first { $0.label == "Accessories" })
        let photography = try #require(viewModel.breakdown.first { $0.label == "Photography" })

        #expect(accessories.canDrillIn == false)
        #expect(photography.canDrillIn)
    }

    /// Reuses the earliest-casing rule rather than whichever spelling the
    /// fetch happens to return first.
    @Test func onePathSpeltTwoWaysBecomesOneRowWithTheEarliestCasing() throws {
        let context = try makeInMemoryContext()
        insertItem("First", category: "Photography/Cameras", createdOffset: 100, into: context)
        insertItem("Second", category: "photography/lenses", createdOffset: 200, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.breakdown.count == 1)
        #expect(viewModel.breakdown.first?.label == "Photography")
        #expect(viewModel.breakdown.first?.itemCount == 2)
    }
}

@Suite("DashboardViewModel — category scope")
struct DashboardScopeTests {
    private func makeCollection() throws -> ModelContext {
        let context = try makeInMemoryContext()
        insertItem("Leica", category: "Photography/Cameras", paidCents: 290_000, valueCents: 345_000, into: context)
        insertItem("Hasselblad", category: "Photography/Cameras", paidCents: 125_000, valueCents: 178_000, into: context)
        insertItem("Nikon", category: "Photography/Lenses", paidCents: 24_000, valueCents: 31_000, into: context)
        insertItem("Amp", category: "Music/Amps", paidCents: 69_000, valueCents: 54_000, into: context)
        try context.save()
        return context
    }

    /// spec.md's "what have I spent on guitars specifically".
    @Test func scopesEveryFigureToTheChosenCategory() throws {
        let viewModel = DashboardViewModel(modelContext: try makeCollection(), scope: "Photography")
        viewModel.load()

        #expect(viewModel.totalItemCount == 3)
        #expect(viewModel.totalCurrentValueCents == 554_000)
        #expect(viewModel.totalSpentCents == 439_000)
        #expect(viewModel.valueDeltaCents == 115_000)
    }

    /// Inside a scope the breakdown moves down a level rather than repeating
    /// the top-level split.
    @Test func breaksDownByTheNextLevelWhenScoped() throws {
        let viewModel = DashboardViewModel(modelContext: try makeCollection(), scope: "Photography")
        viewModel.load()

        #expect(viewModel.breakdown.map(\.path) == ["Photography/Cameras", "Photography/Lenses"])
        #expect(viewModel.breakdown.map(\.label) == ["Cameras", "Lenses"])
    }

    @Test func scopingIsCaseInsensitive() throws {
        let viewModel = DashboardViewModel(modelContext: try makeCollection(), scope: "PHOTOGRAPHY")
        viewModel.load()

        #expect(viewModel.totalItemCount == 3)
    }

    @Test func anEmptyScopeIsTheWholeCollection() throws {
        let viewModel = DashboardViewModel(modelContext: try makeCollection())
        viewModel.load()

        #expect(viewModel.totalItemCount == 4)
    }

    @Test func aScopeMatchingNothingIsEmpty() throws {
        let viewModel = DashboardViewModel(modelContext: try makeCollection(), scope: "Woodwork")
        viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.breakdown.isEmpty)
    }

    /// The reason scoping can't reuse the autocomplete rule: `Audio` is not a
    /// parent of `Audiophile`, however much the string says otherwise.
    @Test func scopeDoesNotLeakIntoACategoryThatMerelyStartsTheSameWay() throws {
        let context = try makeInMemoryContext()
        insertItem("Headphones", category: "Audio/Headphones", valueCents: 20_000, into: context)
        insertItem("Magazine", category: "Audiophile/Magazines", valueCents: 5_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context, scope: "Audio")
        viewModel.load()

        #expect(viewModel.totalItemCount == 1)
        #expect(viewModel.totalCurrentValueCents == 20_000)
    }
}

/// Where the "Value →" callout goes, decided here rather than in the view so
/// the count-versus-destination rule is testable.
@Suite("Dashboard — the un-valued destination")
struct UnvaluedDestinationTests {
    @Test func thereIsNoDestinationWhenEverythingIsValued() throws {
        let context = try makeInMemoryContext()
        insertItem("Valued", valueCents: 20_000, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.unvaluedCount == 0)
        #expect(viewModel.unvaluedDestination == .none)
    }

    /// The refinement from the Phase 7 review: a filtered list holding one row
    /// costs a tap to get through and ends up where this goes directly.
    @Test func oneUnvaluedItemGoesStraightToThatItem() throws {
        let context = try makeInMemoryContext()
        insertItem("Valued", valueCents: 20_000, into: context)
        let unvalued = Item(name: "Not yet valued", categoryPath: "Music/Amps")
        context.insert(unvalued)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.unvaluedCount == 1)
        #expect(viewModel.unvaluedDestination == .item(unvalued.id))
    }

    @Test func twoOrMoreGoToTheFilteredList() throws {
        let context = try makeInMemoryContext()
        insertItem("First", into: context)
        insertItem("Second", into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.unvaluedDestination == .filteredList)
    }

    /// Scoped dashboards get the same treatment, and the id has to be the
    /// un-valued item *inside the scope* — not whichever one the whole
    /// collection happens to have.
    @Test func aScopedDashboardNamesItsOwnSoleUnvaluedItem() throws {
        let context = try makeInMemoryContext()
        let inScope = Item(name: "Un-valued lens", categoryPath: "Photography/Lenses")
        let elsewhere = Item(name: "Un-valued amp", categoryPath: "Music/Amps")
        context.insert(inScope)
        context.insert(elsewhere)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context, scope: "Photography")
        viewModel.load()

        #expect(viewModel.unvaluedCount == 1)
        #expect(viewModel.unvaluedDestination == .item(inScope.id))
    }

    /// Valuing the last one has to retire the destination, or the callout
    /// would keep pointing at an item that no longer belongs there.
    @Test func theDestinationFollowsTheDataOnReload() throws {
        let context = try makeInMemoryContext()
        let unvalued = Item(name: "Not yet valued", categoryPath: "Music/Amps")
        context.insert(unvalued)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.unvaluedDestination == .item(unvalued.id))

        unvalued.currentValueCents = 15_000
        try context.save()
        viewModel.load()

        #expect(viewModel.unvaluedDestination == .none)
    }
}

// MARK: - 002/T013: the market variant

/// The dashboard's asking-price line (002, criterion 15, Decisions 21–22).
///
/// Every figure here is written through `MarketLocalStore.record`, the app's
/// own writer, on the `ItemListViewModelMarketSortTests` pattern: the stale
/// and withheld cases only mean anything if they are the rows a real refresh
/// would have left behind.
@Suite("DashboardViewModel — the market line")
struct DashboardMarketTests {
    /// A fixed clock, so "thirty-one days old" is a fact about the fixture
    /// rather than about the day the suite runs.
    private let clock = Date(timeIntervalSince1970: 1_800_000_000)

    private var stale: Date { clock.addingTimeInterval(-31 * 24 * 60 * 60) }

    private func product(_ id: Int) -> MarketProduct {
        MarketProduct(
            id: id,
            slug: "fender-american-professional-ii-telecaster",
            title: "Fender American Professional II Telecaster",
            usedLowCents: 100_000,
            usedTotal: 108,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
        )
    }

    /// One recorded refresh: a figure, or — with no median — the withheld
    /// reading a thin catalog produces.
    private func record(
        _ medianCents: Int?,
        for id: UUID,
        kind: MarketSubjectKind = .owned,
        fetchedAt: Date,
        in context: ModelContext
    ) throws {
        let reading: MarketReading
        if let medianCents {
            reading = .figure(MarketFigure(
                medianCents: medianCents,
                lowCents: medianCents - 10_000,
                highCents: medianCents + 10_000,
                count: 12,
                fetchedAt: fetchedAt,
                isTruncated: false,
                yearScope: .any
            ))
        } else {
            reading = .withheld(count: 2, usedLowCents: 100_000, fetchedAt: fetchedAt, yearScope: .any)
        }
        try MarketLocalStore.record(
            reading,
            product: product(126_161),
            for: MarketSubjectKey(subjectID: id, kind: kind),
            in: context
        )
    }

    private func id(of name: String, in context: ModelContext) throws -> UUID {
        let items = try context.fetch(FetchDescriptor<Item>())
        return try #require(items.first(where: { $0.name == name })?.id, "\(name) wasn't inserted")
    }

    /// Five owned items in `Photography` and one outside it: two carry a
    /// current median, one is withheld, one went stale past thirty days
    /// (Decision 21), one was never matched.
    private func makeCollection() throws -> ModelContext {
        let context = try makeInMemoryContext()
        insertItem("Leica", category: "Photography/Cameras", paidCents: 290_000, valueCents: 345_000, into: context)
        insertItem("Nikon", category: "Photography/Lenses", paidCents: 24_000, valueCents: 31_000, into: context)
        insertItem("Withheld", category: "Photography/Cameras", paidCents: 10_000, valueCents: 12_000, into: context)
        insertItem("Stale", category: "Photography/Cameras", paidCents: 10_000, valueCents: 12_000, into: context)
        insertItem("Unmatched", category: "Photography/Lenses", paidCents: 10_000, valueCents: nil, into: context)
        insertItem("Amp", category: "Music/Amps", paidCents: 69_000, valueCents: 54_000, into: context)
        try context.save()
        return context
    }

    private func seedMarketRows(into context: ModelContext) throws {
        try record(400_000, for: try id(of: "Leica", in: context), fetchedAt: clock, in: context)
        try record(50_000, for: try id(of: "Nikon", in: context), fetchedAt: clock, in: context)
        try record(nil, for: try id(of: "Withheld", in: context), fetchedAt: clock, in: context)
        // The largest number in the fixture, so a sum that ignored freshness
        // could not come out right by accident.
        try record(900_000, for: try id(of: "Stale", in: context), fetchedAt: stale, in: context)
        try record(700_000, for: try id(of: "Amp", in: context), fetchedAt: clock, in: context)
        try context.save()
    }

    private func viewModel(over context: ModelContext, scope: String = "") -> DashboardViewModel {
        DashboardViewModel(modelContext: context, scope: scope, now: { self.clock })
    }

    /// Criterion 15: the sum is over *current* medians only, and it follows
    /// the scope the screen is showing. The out-of-scope item's figure is
    /// counted when the whole collection is on screen, so the exclusion is
    /// the scope's doing and not an unreadable row.
    @Test func theMarketTotalSumsCurrentMediansOnly() throws {
        let context = try makeCollection()
        try seedMarketRows(into: context)

        let scoped = viewModel(over: context, scope: "Photography")
        scoped.load()

        #expect(scoped.marketTotalCents == 450_000)
        #expect(scoped.marketFigureCount == 2)
        #expect(scoped.totalItemCount == 5)
        #expect(scoped.hasMarketFigures)

        let whole = viewModel(over: context)
        whole.load()

        #expect(whole.marketTotalCents == 1_150_000)
        #expect(whole.marketFigureCount == 3)
        #expect(whole.totalItemCount == 6)
    }

    /// Criterion 15: a wanted item's figure belongs to the wishlist, never
    /// to what the collection is worth — even though both kinds of row live
    /// in the same store.
    @Test func wishlistFiguresNeverReachTheTotal() throws {
        let context = try makeCollection()
        try seedMarketRows(into: context)
        let wanted = WishlistItem(name: "D-18", categoryPath: "Music/Guitars")
        context.insert(wanted)
        try record(1_500_000, for: wanted.id, kind: .wanted, fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.marketTotalCents == 1_150_000)
        #expect(viewModel.marketFigureCount == 3)
    }

    /// Decision 22, whole: the amount and the coverage are one string, so
    /// no surface can show the figure without saying what it covers.
    @Test func theMarketLineIsTheWholeString() throws {
        let context = try makeCollection()
        try seedMarketRows(into: context)

        let viewModel = viewModel(over: context, scope: "Photography")
        viewModel.load()

        #expect(
            viewModel.marketLine
                == MarketCopy.dashboardLine(totalCents: 450_000, count: 2, totalCount: 5)
        )
        // Written out once, so the line can't drift behind its own composer.
        #expect(viewModel.marketLine == "Market · $4,500 · 2 of 5 items")
    }

    /// The rule the whole variant rests on: the market figures are an
    /// addition, never an ingredient. Every other figure on the screen comes
    /// out identical over the same collection with and without market rows.
    @Test func marketFiguresLeaveEveryOtherFigureAlone() throws {
        let without = try makeCollection()
        let with = try makeCollection()
        try seedMarketRows(into: with)

        let bare = viewModel(over: without)
        bare.load()
        let market = viewModel(over: with)
        market.load()

        #expect(market.totalCurrentValueCents == bare.totalCurrentValueCents)
        #expect(market.totalSpentCents == bare.totalSpentCents)
        #expect(market.valueDeltaCents == bare.valueDeltaCents)
        #expect(market.valuedCount == bare.valuedCount)
        #expect(market.unvaluedCount == bare.unvaluedCount)
        #expect(market.totalItemCount == bare.totalItemCount)
        #expect(market.valuedShare == bare.valuedShare)
        #expect(market.breakdown == bare.breakdown)
        // And the market figures really were there to interfere.
        #expect(market.hasMarketFigures)
        #expect(!bare.hasMarketFigures)
    }

    /// No line at all rather than "Market · $0 · 0 of 6 items", which would
    /// report a collection as worthless on Reverb rather than un-matched.
    @Test func hasMarketFiguresIsFalseWithNothingMatched() throws {
        let context = try makeCollection()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(!viewModel.hasMarketFigures)
        #expect(viewModel.marketFigureCount == 0)
        #expect(viewModel.marketTotalCents == 0)
    }

    /// The same, with rows present but nothing readable in them: a withheld
    /// reading and one past thirty days are matched items with no current
    /// median, and neither may light the line.
    @Test func hasMarketFiguresIsFalseWhenEveryFigureIsWithheldOrStale() throws {
        let context = try makeCollection()
        try record(nil, for: try id(of: "Withheld", in: context), fetchedAt: clock, in: context)
        try record(900_000, for: try id(of: "Stale", in: context), fetchedAt: stale, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(!viewModel.hasMarketFigures)
        #expect(viewModel.marketTotalCents == 0)
    }
}

// MARK: - 006/T010: the sold figures

/// A sold item, on the `ItemSaleStoreTests` pattern: an ordinary `Item` with
/// `sale` set, which is the only writer of the four columns.
@discardableResult
private func insertSoldItem(
    _ name: String,
    category: String = "Music/Guitars",
    paidCents: Int = 10_000,
    valueCents: Int? = nil,
    soldAt seconds: TimeInterval,
    forCents salePriceCents: Int,
    into context: ModelContext
) -> Item {
    let item = Item(
        name: name,
        categoryPath: category,
        purchasePriceCents: paidCents,
        currentValueCents: valueCents
    )
    item.createdAt = Date(timeIntervalSince1970: 0)
    item.sale = Sale(
        date: Date(timeIntervalSince1970: seconds),
        priceCents: salePriceCents,
        location: nil,
        note: nil
    )
    context.insert(item)
    return item
}

/// AC4 and AC6: the Dashboard has two halves now. Everything the screen said
/// before covers the owned half only, and the Sold card is the one place a
/// sold item shows up at all.
@Suite("DashboardViewModel — the sold figures")
struct DashboardSoldFiguresTests {
    private let clock = Date(timeIntervalSince1970: 1_800_000_000)

    private func viewModel(over context: ModelContext, scope: String = "") -> DashboardViewModel {
        DashboardViewModel(modelContext: context, scope: scope, now: { self.clock })
    }

    /// One recorded median, through the app's own writer — so the market
    /// count this test pins is the count a real refresh would produce.
    private func recordMedian(_ medianCents: Int, for id: UUID, in context: ModelContext) throws {
        try MarketLocalStore.record(
            .figure(MarketFigure(
                medianCents: medianCents,
                lowCents: medianCents - 10_000,
                highCents: medianCents + 10_000,
                count: 12,
                fetchedAt: clock,
                isTruncated: false,
                yearScope: .any
            )),
            product: MarketProduct(
                id: 126_161,
                slug: "fender-american-professional-ii-telecaster",
                title: "Fender American Professional II Telecaster",
                usedLowCents: 100_000,
                usedTotal: 108,
                listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
            ),
            for: MarketSubjectKey(subjectID: id, kind: .owned),
            in: context
        )
    }

    /// Two owned items, both valued, and two sold ones — one valued, one not,
    /// so counting the sold half would move the un-valued figures as well as
    /// the money ones.
    private func makeCollection() throws -> (context: ModelContext, sold: Item, owned: Item) {
        let context = try makeInMemoryContext()
        let leica = Item(
            name: "Leica",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 290_000,
            currentValueCents: 345_000
        )
        leica.createdAt = Date(timeIntervalSince1970: 0)
        context.insert(leica)
        insertItem("Nikon", category: "Photography/Lenses", paidCents: 24_000, valueCents: 31_000, into: context)
        let soldBody = insertSoldItem(
            "Sold body", category: "Photography/Cameras",
            paidCents: 100_000, valueCents: 120_000,
            soldAt: 1_000, forCents: 150_000, into: context
        )
        insertSoldItem(
            "Sold strap", category: "Photography/Lenses",
            paidCents: 5_000, valueCents: nil,
            soldAt: 2_000, forCents: 4_000, into: context
        )
        try context.save()
        return (context, soldBody, leica)
    }

    /// G22. The three headline figures still reconcile with a sale in the
    /// collection, and the sold items are in none of value, paid, the counts,
    /// the breakdown, `unvaluedDestination` or the market count.
    ///
    /// Mutation: hand `apply` the whole scope rather than the owned half
    /// (`apply(scoped, marketSummaries:)`) → every expectation below moves.
    @Test func theCollectionFiguresExcludeSoldItemsAndStillReconcile() throws {
        let (context, sold, owned) = try makeCollection()
        // The sold item's market row: cleared on a real sale (T007), seeded
        // here so the exclusion is the split's doing and not an absent row.
        try recordMedian(400_000, for: owned.id, in: context)
        try recordMedian(900_000, for: sold.id, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 376_000)
        #expect(viewModel.totalSpentCents == 314_000)
        // No `total - spent == delta` line here: `valueDeltaCents` *is* that
        // subtraction, so it can't fail — the same tautology
        // `theThreeHeadlineFiguresAlwaysReconcile` records finding at 002/T013.
        // The three literals above, read off `makeCollection`'s fixture by
        // hand, are what makes the figures reconcile falsifiably.
        #expect(viewModel.valueDeltaCents == 62_000)

        #expect(viewModel.totalItemCount == 2)
        #expect(viewModel.valuedCount == 2)
        #expect(viewModel.unvaluedCount == 0)
        #expect(viewModel.unvaluedDestination == .none, "the un-valued item in this fixture is a sold one")

        // One top-level row at the root scope, over the owned half only.
        #expect(viewModel.breakdown.map(\.path) == ["Photography"])
        #expect(viewModel.breakdown.map(\.itemCount) == [2])
        #expect(viewModel.breakdown.map(\.unvaluedCount) == [0])
        #expect(viewModel.breakdown.map(\.currentValueCents) == [376_000])
        #expect(viewModel.breakdown.map(\.spentCents) == [314_000])

        #expect(viewModel.marketFigureCount == 1)
        #expect(viewModel.marketTotalCents == 400_000)

        // And the sale really was in the fetch the whole time.
        #expect(viewModel.soldTotals.count == 2)
    }

    /// The card's own arithmetic, straight off `SaleOutcome.totals`: two
    /// sales at $1,500 and $40 against $1,000 and $50 paid.
    @Test func theSoldTotalsSumTheSalesInScope() throws {
        let (context, _, _) = try makeCollection()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.soldTotals == SaleTotals(count: 2, proceedsCents: 154_000, realisedDeltaCents: 49_000))
        #expect(viewModel.hasSales)
    }

    /// The two lines are `SaleCopy` over those same numbers — composed there
    /// so the card and the Sold side's summary cannot word one sum two ways.
    @Test func theCardsLinesAreSaleCopyOverTheSameNumbers() throws {
        let (context, _, _) = try makeCollection()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.soldLine == SaleCopy.dashboardSummary(
            SaleTotals(count: 2, proceedsCents: 154_000, realisedDeltaCents: 49_000)
        ))
        #expect(viewModel.soldDeltaLine == SaleCopy.realised(deltaCents: 49_000))
    }

    /// G23. The card follows the scope like every other figure on the screen:
    /// a sale in another category is absent from a scoped copy, and a scope
    /// with no sales in it has no card at all rather than a card of zeroes.
    ///
    /// Mutation: split the unfiltered fetch rather than `scoped`
    /// (`all.filter(\.isSold)`) → the Music copy sees the Photography sale
    /// and `hasSales` goes true in `Audio` → red.
    @Test func theSoldFiguresFollowTheScope() throws {
        let context = try makeInMemoryContext()
        insertItem("Amp", category: "Music/Amps", paidCents: 69_000, valueCents: 54_000, into: context)
        insertItem("Headphones", category: "Audio/Headphones", paidCents: 20_000, valueCents: 22_000, into: context)
        insertSoldItem(
            "Guitar", category: "Music/Guitars",
            paidCents: 60_000, soldAt: 1_000, forCents: 70_000, into: context
        )
        insertSoldItem(
            "Leica", category: "Photography/Cameras",
            paidCents: 100_000, soldAt: 2_000, forCents: 150_000, into: context
        )
        try context.save()

        let music = viewModel(over: context, scope: "Music")
        music.load()
        #expect(music.soldTotals == SaleTotals(count: 1, proceedsCents: 70_000, realisedDeltaCents: 10_000))
        #expect(music.hasSales)

        let photography = viewModel(over: context, scope: "Photography")
        photography.load()
        #expect(photography.soldTotals == SaleTotals(count: 1, proceedsCents: 150_000, realisedDeltaCents: 50_000))

        let whole = viewModel(over: context)
        whole.load()
        #expect(whole.soldTotals == SaleTotals(count: 2, proceedsCents: 220_000, realisedDeltaCents: 60_000))

        let audio = viewModel(over: context, scope: "Audio")
        audio.load()
        #expect(!audio.hasSales, "a scope nothing was sold in shows no card, not a card of zeroes")
        #expect(audio.soldTotals == SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0))
        #expect(audio.totalItemCount == 1, "and the scope really did hold something")
    }

    /// Nothing sold at all: the card is hidden rather than reading "0 items ·
    /// $0", the same gating `hasMarketFigures` applies one line above it.
    @Test func hasSalesIsFalseWithNothingSold() throws {
        let context = try makeInMemoryContext()
        insertItem("Amp", paidCents: 69_000, valueCents: 54_000, into: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(!viewModel.hasSales)
        #expect(viewModel.soldTotals == SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0))
    }
}
