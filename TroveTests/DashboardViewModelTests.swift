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
    @Test func theThreeHeadlineFiguresAlwaysReconcile() throws {
        let context = try makeInMemoryContext()
        insertItem("A", paidCents: 12_345, valueCents: 20_000, into: context)
        insertItem("B", paidCents: 90_000, valueCents: 5_000, into: context)
        insertItem("C", paidCents: 7_777, valueCents: nil, into: context)
        insertItem("D", paidCents: 400, valueCents: 999, into: context)
        try context.save()

        let viewModel = DashboardViewModel(modelContext: context)
        viewModel.load()

        #expect(
            viewModel.totalCurrentValueCents - viewModel.totalSpentCents == viewModel.valueDeltaCents
        )
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
