import Foundation

/// The four sale fields on `Item`, read and written as one value.
///
/// `Item` stores them separately — four optional columns rather than a second
/// model, so the sale syncs with the item as one CloudKit record (plan Q1) —
/// but nothing outside `Item` should have to remember that a date without a
/// price is not a sale. `Item.sale` is the single place the pair is assembled.
nonisolated struct Sale: Sendable, Equatable {
    var date: Date
    var priceCents: Int
    var location: String?
    var note: String?
}

/// Gain or loss against what was paid — the one arithmetic this spec adds.
nonisolated struct SaleOutcome: Sendable, Equatable {
    let deltaCents: Int

    /// The colour rule, on the model rather than in each view (plan Q11):
    /// breaking even is not a loss, so the boundary is `< 0`, not `<= 0`.
    var isLoss: Bool { deltaCents < 0 }

    init(salePriceCents: Int, purchasePriceCents: Int) {
        self.deltaCents = salePriceCents - purchasePriceCents
    }
}

/// The three figures every "what was sold" surface shows, summed once.
/// `ItemListViewModel`, `DashboardViewModel` and the UI seed's expected
/// numbers all read this, so AC7's "the summary matches the card" is one sum,
/// not two hand-written ones agreeing.
nonisolated struct SaleTotals: Sendable, Equatable {
    let count: Int
    let proceedsCents: Int
    let realisedDeltaCents: Int
}

extension SaleOutcome {
    /// Over the sold items among `items` — an unsold item contributes nothing,
    /// not even to the count.
    @MainActor static func totals(over items: [Item]) -> SaleTotals {
        var count = 0
        var proceedsCents = 0
        var realisedDeltaCents = 0
        for item in items {
            guard let sale = item.sale, let outcome = item.saleOutcome else { continue }
            count += 1
            proceedsCents += sale.priceCents
            realisedDeltaCents += outcome.deltaCents
        }
        return SaleTotals(
            count: count,
            proceedsCents: proceedsCents,
            realisedDeltaCents: realisedDeltaCents
        )
    }
}

extension Item {
    /// The one sold predicate, in memory. Predicates and sort descriptors can
    /// only see the stored `soldDate`, so they spell out `soldDate == nil`
    /// themselves (plan Q2).
    var isSold: Bool { soldDate != nil }

    /// The sale as a pair, or nil while owned. Setting nil clears all four
    /// fields **and** `soldTowardWishlistItem` (Return to collection, P12);
    /// setting a value writes the four fields and leaves the link alone.
    ///
    /// The `get` requires `soldDate` only. A row carrying a date and no price
    /// — reachable only from a future version or a bug, never from this app's
    /// writers, which always write the two together — reads its price as 0
    /// rather than hiding the sale altogether. Defensive, and `ModelTests`
    /// records it as such.
    var sale: Sale? {
        get {
            guard let soldDate else { return nil }
            return Sale(
                date: soldDate,
                priceCents: salePriceCents ?? 0,
                location: saleLocation,
                note: saleNote
            )
        }
        set {
            guard let newValue else {
                soldDate = nil
                salePriceCents = nil
                saleLocation = nil
                saleNote = nil
                soldTowardWishlistItem = nil
                return
            }
            soldDate = newValue.date
            salePriceCents = newValue.priceCents
            saleLocation = newValue.location
            saleNote = newValue.note
        }
    }

    /// Gain or loss on this item's sale, or nil while it is owned.
    var saleOutcome: SaleOutcome? {
        guard let sale else { return nil }
        return SaleOutcome(
            salePriceCents: sale.priceCents,
            purchasePriceCents: purchasePriceCents
        )
    }
}
