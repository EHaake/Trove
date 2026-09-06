import Foundation
import SwiftData

/// The collection one UI test needs and no device can have yet (spec 003,
/// Decision 9): a Sell Plan whose candidates are one rising, one flat, one
/// neutral and one falling, so the ranking, the arrow and the reason line can
/// be exercised on screen before any real device has accrued a week of market
/// history.
///
/// This is the constitution's sanctioned test-only branch, on the two
/// conditions its 2026-09-06 amendment adds:
///
/// - The in-memory bound is **structural**. `shouldSeed` is gated on the mode
///   of the store the app actually built, not on a second read of
///   `-uiTesting` — so a persistent store refuses the seed even with every
///   flag set, and a test can show it refusing rather than trusting the
///   launch argument to have been read the same way twice.
/// - It takes its **own** argument. `-uiTesting` alone still starts from an
///   empty collection, so every UI test written before this one keeps the
///   starting state it was written against.
///
/// The only thing it can do is add rows to one launch's in-memory stores.
enum UITestSeed {
    /// The second launch argument, spelled exactly once in the project — the
    /// app never names it, it asks `shouldSeed`.
    static let argument = "-seedSellPlan"

    /// Whether this launch should be seeded: the store that was actually
    /// built is the in-memory one, **and** the argument is present.
    static func shouldSeed(mode: StorageMode, arguments: [String]) -> Bool {
        mode == .ephemeral && arguments.contains(argument)
    }

    /// One wishlist item and the four owned candidates its Sell Plan offers.
    ///
    /// The person's own values are chosen so the trend order disagrees with
    /// the value order at *both* ends: by value alone the list would read
    /// Blues Junior, Telecaster, NT1-A, Squier, and only the trend key gives
    /// Telecaster, Blues Junior, Squier, NT1-A. A seed the ranking's group key
    /// didn't change would prove nothing about the ranking.
    ///
    /// Every market row is written through `MarketLocalStore.record`, twice
    /// per matched item — the older reading, then the current one — so the
    /// figure, both history points, the stored trend and the match snapshot
    /// are exactly what two refreshes would have left behind, rather than
    /// values asserted into place beside each other.
    static func sellPlan(into context: ModelContext, now: Date) throws {
        let fortnightAgo = now.addingTimeInterval(-14 * 24 * 60 * 60)

        context.insert(WishlistItem(
            name: "Summicron 35mm f/2",
            categoryPath: "Photography/Lenses",
            estimatedCostCents: 240_000
        ))

        // Rising: $1,250 a fortnight ago against $1,400 now, +12 %.
        try seed(
            owned("Telecaster", categoryPath: "Music/Guitars", purchasePriceCents: 90_000, valueCents: 60_000, product: telecaster, into: context),
            product: telecaster,
            medians: [(125_000, fortnightAgo), (140_000, now)],
            in: context
        )
        // Flat: unchanged across the same fortnight.
        try seed(
            owned("Blues Junior", categoryPath: "Music/Amps", purchasePriceCents: 70_000, valueCents: 64_000, product: bluesJunior, into: context),
            product: bluesJunior,
            medians: [(60_000, fortnightAgo), (60_000, now)],
            in: context
        )
        // Neutral: unmatched, so it has no market line at all — the same rank
        // as flat, and nothing to say.
        _ = owned("Squier Classic Vibe", categoryPath: "Music/Guitars", purchasePriceCents: 45_000, valueCents: 38_000, product: nil, into: context)
        // Falling: $200 to $170, −15 %.
        try seed(
            owned("NT1-A", categoryPath: "Music/Microphones", purchasePriceCents: 30_000, valueCents: 40_000, product: nt1a, into: context),
            product: nt1a,
            medians: [(20_000, fortnightAgo), (17_000, now)],
            in: context
        )

        try context.save()
    }

    // MARK: - Private

    private static func owned(
        _ name: String,
        categoryPath: String,
        purchasePriceCents: Int,
        valueCents: Int,
        product: MarketProduct?,
        into context: ModelContext
    ) -> Item {
        let item = Item(
            name: name,
            categoryPath: categoryPath,
            purchasePriceCents: purchasePriceCents,
            currentValueCents: valueCents,
            // "Would let it go" — inside the candidate pool, and the same for
            // all four, so the trend is what decides between them.
            desireToKeep: 2,
            reverbProductID: product?.id
        )
        context.insert(item)
        return item
    }

    /// The readings in order, each through the writer a refresh uses.
    private static func seed(
        _ item: Item,
        product: MarketProduct,
        medians: [(cents: Int, fetchedAt: Date)],
        in context: ModelContext
    ) throws {
        for median in medians {
            let reading = MarketReading.figure(MarketFigure(
                medianCents: median.cents,
                lowCents: median.cents * 4 / 5,
                highCents: median.cents * 6 / 5,
                p10Cents: median.cents * 9 / 10,
                p90Cents: median.cents * 11 / 10,
                count: 12,
                fetchedAt: median.fetchedAt,
                isTruncated: false,
                yearScope: .any
            ))
            try MarketLocalStore.record(reading, product: product, for: MarketSubjectKey(subjectID: item.id, kind: .owned), in: context)
        }
    }

    private static let telecaster = product(
        id: 126_161,
        slug: "fender-american-professional-ii-telecaster",
        title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000
    )

    private static let bluesJunior = product(
        id: 61_927,
        slug: "fender-blues-junior-iv",
        title: "Fender Blues Junior IV",
        usedLowCents: 45_000
    )

    private static let nt1a = product(
        id: 40_318,
        slug: "rode-nt1-a",
        title: "Rode NT1-A",
        usedLowCents: 12_000
    )

    private static func product(id: Int, slug: String, title: String, usedLowCents: Int) -> MarketProduct {
        MarketProduct(
            id: id, slug: slug, title: title,
            usedLowCents: usedLowCents, usedTotal: 24,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=\(id)")!
        )
    }
}
