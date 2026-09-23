import Foundation

/// One derivation of a sell plan's facts and the words built from them
/// (plan §2, Q5): how many items are set aside, how many were sold toward it,
/// and whether the sales alone have covered the estimate — read by the Plans
/// rows, the wanted item's page and the Sell Plan screen alike.
///
/// Carries a Bool for covered, never the sum (plan Q8): no row on the Plans
/// screen shows a money figure (criterion 8).
///
/// Main-actor by default, because it reads `@Model`s.
struct SellPlanSummary: Equatable {
    let setAsideCount: Int
    let soldTowardCount: Int
    let isCovered: Bool

    init(_ wanted: WishlistItem) {
        let sold = wanted.itemsSoldToward ?? []
        setAsideCount = (wanted.plannedSaleItems ?? []).count
        soldTowardCount = sold.count
        isCovered = Self.isCovered(
            soldCents: Self.soldCents(of: sold),
            estimatedCostCents: wanted.estimatedCostCents
        )
    }

    /// A row's lines, each present only when its count is non-zero
    /// (criterion 7). A nil `boughtDate` is the active side: set aside, sold
    /// toward, covered. A bought date is the completed side: the date first,
    /// then what was sold toward it, then covered.
    func rowLines(boughtDate: Date?) -> [String] {
        var lines: [String] = []
        if let boughtDate {
            lines.append(SellPlanCopy.bought(on: boughtDate))
            if soldTowardCount > 0 { lines.append(SellPlanCopy.soldTowardPast(soldTowardCount)) }
        } else {
            if setAsideCount > 0 { lines.append(SellPlanCopy.setAside(setAsideCount)) }
            if soldTowardCount > 0 { lines.append(SellPlanCopy.soldToward(soldTowardCount)) }
        }
        if isCovered { lines.append(SellPlanCopy.covered) }
        return lines
    }

    /// The wanted item's page's second line for a plan that exists (P9): what
    /// is set aside, else what was sold toward it, else that nothing is set
    /// aside yet.
    var entrySubtitle: String {
        if setAsideCount > 0 { return SellPlanCopy.setAside(setAsideCount) }
        if soldTowardCount > 0 { return SellPlanCopy.soldToward(soldTowardCount) }
        return SellPlanCopy.nothingSetAside
    }

    /// What the sales brought in: the price recorded at each sale, never a
    /// current value — the sale is settled and the market has nothing left to
    /// say about it. `SellPlanViewModel.soldValueCents` reads this too, so the
    /// Sell Plan screen's Sold figure and the covered rule cannot read
    /// different sums.
    static func soldCents(of sold: [Item]) -> Int {
        sold.compactMap { $0.sale?.priceCents }.reduce(0, +)
    }

    /// Covered is the sales alone against the estimate (plan Q6, Decision
    /// 10) — deliberately not `SellPlanViewModel.selectedValueMeetsCost`,
    /// which adds the selection. An estimate of 0 means "none", and nothing
    /// covers no estimate.
    static func isCovered(soldCents: Int, estimatedCostCents: Int) -> Bool {
        estimatedCostCents > 0 && soldCents >= estimatedCostCents
    }
}
