import Foundation
import SwiftData
import Testing
@testable import Trove

// MARK: - 014: the Sold side's Sort By

/// A sold item, the `ItemListViewModelTests` shape: the four sale fields land
/// through `Item.sale`, the one writer that keeps a date and a price together.
@discardableResult
private func insertSold(
    _ name: String,
    category: String = "Music/Guitars",
    priceCents: Int = 0,
    valueCents: Int? = nil,
    order: Int = 0,
    soldAt seconds: TimeInterval,
    forCents salePriceCents: Int,
    into context: ModelContext
) -> Item {
    let item = Item(
        name: name,
        categoryPath: category,
        purchasePriceCents: priceCents,
        purchaseDate: Date(timeIntervalSince1970: 0),
        currentValueCents: valueCents,
        sortOrder: order
    )
    item.sale = Sale(
        date: Date(timeIntervalSince1970: seconds),
        priceCents: salePriceCents,
        location: nil,
        note: nil
    )
    context.insert(item)
    return item
}

private let day: TimeInterval = 86_400

/// Plan §2's fixture: four sales chosen so every order differs from the
/// standing order and from every other order, with a gain, a loss, an at-cost
/// sale, and one sale-price tie that falls the way the standing order says and
/// *not* the way name order would.
///
/// | Name  | Paid   | Sold for | Sold        | Outcome |
/// |-------|--------|----------|-------------|---------|
/// | Amp   | $500   | $650     | 3 days ago  | +$150   |
/// | Drum  | $1,250 | $1,250   | 3 days ago  | at cost |
/// | Bass  | $1,000 | $1,250   | 7 days ago  | +$250   |
/// | Cello | $850   | $600     | 12 days ago | −$250   |
///
/// Standing order (date, then name, then id): Amp, Drum, Bass, Cello.
private func insertFixture(into context: ModelContext) {
    insertSold("Amp", priceCents: 50_000, soldAt: 97 * day, forCents: 65_000, into: context)
    insertSold("Drum", priceCents: 125_000, soldAt: 97 * day, forCents: 125_000, into: context)
    insertSold("Bass", priceCents: 100_000, soldAt: 93 * day, forCents: 125_000, into: context)
    insertSold("Cello", priceCents: 85_000, soldAt: 88 * day, forCents: 60_000, into: context)
}

@Suite("SoldSortOrder — the Sold side's eight orders")
struct SoldSortOrderTests {

    // MARK: - G1: the menu itself

    /// Labels, case order and the default, each by literal — so a renamed
    /// label, a reordered menu or a changed default can't pass unnoticed.
    @Test func theMenuIsTheSpecsEightOptionsInOrder() {
        #expect(ItemListViewModel.SoldSortOrder.allCases.map(\.label) == [
            "Date sold",
            "Price ↓",
            "Price ↑",
            "Paid ↓",
            "Paid ↑",
            "Gain ↓",
            "Gain ↑",
            "Name",
        ])
        #expect(ItemListViewModel.SoldSortOrder.allCases == [
            .soldDate,
            .salePriceDescending,
            .salePriceAscending,
            .paidDescending,
            .paidAscending,
            .gainDescending,
            .gainAscending,
            .name,
        ])
    }

    @Test func theSoldSideDefaultsToDateSold() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context)

        #expect(viewModel.soldSortOrder == .soldDate)
    }

    // MARK: - G2: the eight orders over the fixture

    /// Every option's expected order over plan §2's fixture, through `load()`.
    /// Deleting any one comparator (falling to the standing order), reversing
    /// it, or reading the wrong field changes the case's expectation.
    @Test(arguments: [
        (ItemListViewModel.SoldSortOrder.soldDate, ["Amp", "Drum", "Bass", "Cello"]),
        (.salePriceDescending, ["Drum", "Bass", "Amp", "Cello"]),
        (.salePriceAscending, ["Cello", "Amp", "Drum", "Bass"]),
        (.paidDescending, ["Drum", "Bass", "Cello", "Amp"]),
        (.paidAscending, ["Amp", "Cello", "Bass", "Drum"]),
        (.gainDescending, ["Bass", "Amp", "Drum", "Cello"]),
        (.gainAscending, ["Cello", "Drum", "Amp", "Bass"]),
        (.name, ["Amp", "Bass", "Cello", "Drum"]),
    ])
    func eachOrderSortsTheFixtureItsOwnWay(
        order: ItemListViewModel.SoldSortOrder,
        expected: [String]
    ) throws {
        let context = try makeInMemoryContext()
        insertFixture(into: context)
        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.soldSortOrder = order

        viewModel.load()

        #expect(viewModel.soldItems.map(\.name) == expected)
    }

    // MARK: - G3: the tie

    /// Drum and Bass both sold for $1,250, so Price ↓ leaves the pair to the
    /// standing order, whose *date* puts Drum first — where name order would
    /// put Bass first.
    ///
    /// Asked of the static comparator directly, in both argument orders,
    /// rather than through `load()`: a fetch hands the pair back in an order
    /// this test does not control, so a tie-break asked through one can pass
    /// without the rule being there at all (`CLAUDE.md`'s tie-break lesson).
    @Test func aSalePriceTieFallsToTheStandingOrderNotToName() throws {
        let context = try makeInMemoryContext()
        let drum = insertSold(
            "Drum", priceCents: 125_000, soldAt: 97 * day, forCents: 125_000, into: context
        )
        let bass = insertSold(
            "Bass", priceCents: 100_000, soldAt: 93 * day, forCents: 125_000, into: context
        )

        #expect(
            ItemListViewModel.areInSoldOrder(drum, bass, under: .salePriceDescending) == true
        )
        #expect(
            ItemListViewModel.areInSoldOrder(bass, drum, under: .salePriceDescending) == false
        )
    }
}
