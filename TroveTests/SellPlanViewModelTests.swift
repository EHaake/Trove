import Foundation
import SwiftData
import Testing
@testable import Trove

private func owned(
    _ name: String,
    desire: Int,
    valueCents: Int?,
    into context: ModelContext
) -> Item {
    let item = Item(
        name: name,
        categoryPath: "Music/Guitars",
        purchasePriceCents: 100_000,
        currentValueCents: valueCents,
        desireToKeep: desire
    )
    context.insert(item)
    return item
}

private func wanted(costCents: Int = 240_000, into context: ModelContext) -> WishlistItem {
    let item = WishlistItem(
        name: "Summicron 35mm f/2",
        categoryPath: "Photography/Lenses",
        estimatedCostCents: costCents
    )
    context.insert(item)
    return item
}

@Suite("SellPlanViewModel — the candidate pool")
struct SellPlanCandidateTests {
    @Test func offersOnlyGearTheUserIsRelaxedAbout() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        _ = owned("Would let it go", desire: 2, valueCents: 50_000, into: context)
        _ = owned("Undecided", desire: 3, valueCents: 50_000, into: context)
        _ = owned("Keeping for now", desire: 4, valueCents: 50_000, into: context)
        _ = owned("Absolutely keeping", desire: 5, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.candidates.map(\.name) == ["Ready to sell", "Would let it go", "Undecided"])
    }

    /// The threshold lives in `DesireLevel.isSellCandidate` so the item screens
    /// and this filter can't drift. If that property moves, this pool moves
    /// with it — which is the entire point of it existing.
    @Test func theThresholdIsTheSharedOneNotACopy() throws {
        for level in DesireLevel.allCases {
            let context = try makeInMemoryContext()
            let plan = wanted(into: context)
            _ = owned("Candidate", desire: level.rawValue, valueCents: 50_000, into: context)
            try context.save()

            let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
            viewModel.load()

            #expect(
                viewModel.candidates.isEmpty == !level.isSellCandidate,
                "level \(level.rawValue): pool disagreed with isSellCandidate"
            )
        }
    }

    /// Same rule as the dashboard total: an un-valued item isn't worth zero,
    /// it's unknown, and there's nothing to rank it by.
    @Test func leavesOutItemsWithNoValueEntered() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Valued", desire: 1, valueCents: 50_000, into: context)
        _ = owned("Not yet valued", desire: 1, valueCents: nil, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.candidates.map(\.name) == ["Valued"])
    }

    @Test func ranksLeastWantedFirst() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Undecided", desire: 3, valueCents: 50_000, into: context)
        _ = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        _ = owned("Would let it go", desire: 2, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.candidates.map(\.desireToKeep) == [1, 2, 3])
    }

    /// Between two items you feel the same about, the one that raises more is
    /// the better suggestion.
    @Test func breaksTiesByHigherValueFirst() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Cheap", desire: 2, valueCents: 20_000, into: context)
        _ = owned("Dear", desire: 2, valueCents: 90_000, into: context)
        _ = owned("Middling", desire: 2, valueCents: 55_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.candidates.map(\.name) == ["Dear", "Middling", "Cheap"])
    }

    /// `FetchDescriptor` promises no ordering, so items equal on both ranking
    /// keys still have to come back the same way every time.
    @Test func fullyDeterminesTheOrderForItemsEqualOnBothKeys() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Charlie", desire: 2, valueCents: 50_000, into: context)
        _ = owned("alpha", desire: 2, valueCents: 50_000, into: context)
        _ = owned("Bravo", desire: 2, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        let first = viewModel.candidates.map(\.name)
        viewModel.load()

        #expect(first == ["alpha", "Bravo", "Charlie"])
        #expect(viewModel.candidates.map(\.name) == first)
    }

    @Test func anEmptyCollectionOffersNothing() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.candidates.isEmpty)
        #expect(viewModel.isEmpty)
        #expect(viewModel.hasLoaded)
        #expect(viewModel.selectedValueCents == 0)
    }

    /// Nothing qualifies, so there's nothing to offer — distinct from having no
    /// gear at all, but it lands in the same place.
    @Test func aCollectionOfKeepersOffersNothing() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Keeper", desire: 5, valueCents: 50_000, into: context)
        _ = owned("Also a keeper", desire: 4, valueCents: 90_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.isEmpty)
    }
}

@Suite("SellPlanViewModel — selection")
struct SellPlanSelectionTests {
    /// The plan is advisory. It starts empty and stays that way until the user
    /// picks something — auto-selecting toward the cost is the completion-target
    /// behaviour this feature is explicitly not.
    @Test func startsWithNothingSelected() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        _ = owned("Ready to sell", desire: 1, valueCents: 300_000, into: context)
        _ = owned("Would let it go", desire: 2, valueCents: 300_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.selectedIDs.isEmpty)
        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.selectedValueCents == 0)
        #expect(viewModel.candidates.allSatisfy { !viewModel.isSelected($0) })
    }

    /// Even when one item alone would cover the cost several times over —
    /// the tempting case for a "helpful" pre-selection.
    @Test func doesNotPreselectEvenWhenOneItemWouldCoverTheCost() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(costCents: 10_000, into: context)
        _ = owned("Ready to sell", desire: 1, valueCents: 900_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.selectedCount == 0)
        #expect(viewModel.selectedValueMeetsCost == false)
    }

    @Test func togglingSelectsAndDeselects() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        viewModel.toggle(item)
        #expect(viewModel.isSelected(item))
        #expect(viewModel.selectedValueCents == 50_000)

        viewModel.toggle(item)
        #expect(viewModel.isSelected(item) == false)
        #expect(viewModel.selectedValueCents == 0)
    }

    /// Checked through a *second* context, not by refetching on the same one.
    ///
    /// `ModelContext.fetch` hands back objects carrying unsaved changes, so a
    /// same-context refetch passes whether or not `save()` ran — this test
    /// looked like a persistence check and wasn't until mutation testing
    /// removed the save and nothing went red. A second context over the same
    /// container sees only what actually reached the store.
    @Test func eachToggleIsPersistedWithoutASeparateSaveStep() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let plan = wanted(into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)

        #expect(context.hasChanges == false, "The toggle left unsaved changes behind.")

        let elsewhere = ModelContext(container)
        let stored = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(stored.plannedSaleItems?.map(\.id) == [item.id])
        #expect(viewModel.saveFailureMessage == nil)
    }

    /// The other direction, also through a second context: switching something
    /// off has to reach the store too, not just the in-memory object.
    @Test func deselectingReachesTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let plan = wanted(into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)
        viewModel.toggle(item)

        #expect(context.hasChanges == false)

        let elsewhere = ModelContext(container)
        let stored = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(stored.plannedSaleItems?.isEmpty == true)
    }

    /// Coming back to the screen shows what was chosen, not a fresh
    /// computation — the plan is a real persisted thing.
    @Test func reloadingReflectsThePersistedSelection() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        let first = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        _ = owned("Would let it go", desire: 2, valueCents: 30_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(first)

        let reopened = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        reopened.load()

        #expect(reopened.selectedIDs == [first.id])
        #expect(reopened.selectedValueCents == 50_000)
    }

    @Test func deselectingIsPersistedToo() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)
        viewModel.toggle(item)

        let reopened = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        reopened.load()

        #expect(reopened.selectedIDs.isEmpty)
        #expect(reopened.selectedValueCents == 0)
    }

    @Test func selectingSeveralAddsTheirValuesUp() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        let first = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        let second = owned("Would let it go", desire: 2, valueCents: 30_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(first)
        viewModel.toggle(second)

        #expect(viewModel.selectedCount == 2)
        #expect(viewModel.selectedValueCents == 80_000)
    }

    /// An item can be weighed against more than one purchase at once — the
    /// relationship is many-to-many, and choosing it here mustn't unpick it
    /// somewhere else.
    @Test func selectingForOnePlanLeavesAnotherPlanAlone() throws {
        let context = try makeInMemoryContext()
        let first = wanted(into: context)
        let second = WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps")
        context.insert(second)
        let item = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let firstPlan = SellPlanViewModel(modelContext: context, wishlistItemID: first.id)
        firstPlan.load()
        firstPlan.toggle(item)

        let secondPlan = SellPlanViewModel(modelContext: context, wishlistItemID: second.id)
        secondPlan.load()
        secondPlan.toggle(item)

        #expect(firstPlan.selectedIDs == [item.id])
        #expect(secondPlan.selectedIDs == [item.id])
        #expect(item.plannedForWishlistItems?.count == 2)
    }

    /// plan.md doesn't say what happens when a selected item drifts out of the
    /// pool — raise its desire-to-keep and it stops qualifying while staying on
    /// the plan. Dropping it from the list would strand it: still counted, with
    /// no row to switch it off from.
    @Test func aSelectedItemStaysVisibleAfterItStopsQualifying() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        let item = owned("Was a candidate", desire: 2, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)

        item.desireToKeep = 5
        try context.save()
        viewModel.load()

        #expect(viewModel.candidates.map(\.id) == [item.id])
        #expect(viewModel.isSelected(item))

        // And it can still be switched off.
        viewModel.toggle(item)
        viewModel.load()
        #expect(viewModel.candidates.isEmpty)
    }

    /// The same drift, on the value side. It stays selectable, and contributes
    /// nothing to the total rather than counting as zero.
    @Test func aSelectedItemThatLosesItsValueContributesNothing() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(into: context)
        let valued = owned("Still valued", desire: 1, valueCents: 20_000, into: context)
        let losesValue = owned("Loses its value", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(valued)
        viewModel.toggle(losesValue)
        #expect(viewModel.selectedValueCents == 70_000)

        losesValue.currentValueCents = nil
        try context.save()
        viewModel.load()

        #expect(viewModel.selectedCount == 2)
        #expect(viewModel.selectedValueCents == 20_000)
    }

    @Test func togglingWithoutALoadedWishlistItemDoesNothing() throws {
        let context = try makeInMemoryContext()
        let item = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: UUID())
        viewModel.load()
        viewModel.toggle(item)

        #expect(viewModel.selectedIDs.isEmpty)
    }
}

@Suite("SellPlanViewModel — the two figures")
struct SellPlanFiguresTests {
    @Test func theCostIsTheWishlistItemsOwnEstimate() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(costCents: 240_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.estimatedCostCents == 240_000)
    }

    /// The two figures move independently — that's what makes them a
    /// comparison the user reads rather than a score the app keeps.
    @Test func theTwoFiguresAreReportedSeparately() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(costCents: 240_000, into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 90_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)

        #expect(viewModel.selectedValueCents == 90_000)
        #expect(viewModel.estimatedCostCents == 240_000)
    }

    @Test(arguments: [(90_000, false), (239_999, false), (240_000, true), (500_000, true)])
    func theColourCueTurnsOverAtTheEstimate(valueCents: Int, meets: Bool) throws {
        let context = try makeInMemoryContext()
        let plan = wanted(costCents: 240_000, into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: valueCents, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)

        #expect(viewModel.selectedValueMeetsCost == meets)
    }

    /// Nothing selected is not "meets the cost", even for a free wishlist item
    /// — an empty plan has made no claim either way.
    @Test func anEmptySelectionNeverReadsAsMeetingTheCost() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(costCents: 0, into: context)
        _ = owned("Ready to sell", desire: 1, valueCents: 50_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()

        #expect(viewModel.selectedValueMeetsCost == false)
    }
}

/// The framing decision, guarded at the source rather than in prose.
///
/// spec.md was corrected once already for this: an earlier revision auto-selected
/// candidates until they covered the cost and displayed the result as "surplus
/// or shortfall", which told the user they were supposed to close a gap. The
/// fix was two separate figures with no third number between them, and the way
/// that decision gets quietly undone is someone adding a computed property
/// because it reads tidier at the call site.
///
/// Same technique as `NoHardcodedColorsTests`: scan the source. A behavioural
/// test can prove what the type does, but only this can prove what it declines
/// to offer.
@Suite("Sell Plan framing")
struct SellPlanFramingTests {
    /// Words that would each be a figure or caption framing the comparison as a
    /// gap to close.
    private static let framingTerms = [
        "surplus", "shortfall", "shortFall", "deficit", "remaining", "toGo",
        "stillNeed", "covers", "coverage", "gap", "progress", "percentFunded",
    ]

    private var viewModelSource: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove/ViewModels/SellPlanViewModel.swift")
    }

    /// The other half, and the half spec.md actually describes: it forbids
    /// "text urging the user toward covering the gap", which is copy on a
    /// screen, not a property on a type. Scanning string literals rather than
    /// whole source because `sectionGap` and `listRowGap` contain "gap" and
    /// would fire on every layout constant.
    @Test func theScreenShowsNoCopyFramingItAsAGapToClose() throws {
        let source = try SourceScan.production("Trove/Views/Wishlist/SellPlanView.swift")
        let literals = SourceScan.stringLiterals(in: source)

        #expect(!literals.isEmpty, "Found no copy on SellPlanView — this would pass over nothing.")

        let offending = literals.filter { literal in
            Self.framingTerms.contains { literal.localizedCaseInsensitiveContains($0) }
        }

        #expect(
            offending.isEmpty,
            """
            Copy on the Sell Plan frames the comparison as a gap to close, which \
            spec.md forbids: \(offending.joined(separator: " | "))
            """
        )
    }

    @Test func theViewModelOffersNoSurplusOrShortfallFigure() throws {
        let path = viewModelSource
        #expect(
            FileManager.default.fileExists(atPath: path.path()),
            "Can't reach \(path.path()) — this test would pass over nothing."
        )
        let source = try String(contentsOf: path, encoding: .utf8)

        // Comments are where the decision is explained, so they legitimately
        // name the thing being avoided. Only code is scanned.
        let code = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let comment = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<comment.lowerBound])
            }

        var violations: [String] = []
        for (offset, line) in code.enumerated() {
            for term in Self.framingTerms where line.localizedCaseInsensitiveContains(term) {
                violations.append("SellPlanViewModel.swift:\(offset + 1): \(term) — \(line.trimmingCharacters(in: .whitespaces))")
            }
        }

        #expect(
            violations.isEmpty,
            """
            The Sell Plan exposes two separate figures and no third one framing \
            the difference. See spec.md's "advisory, not a target to hit":
            \(violations.joined(separator: "\n"))
            """
        )
    }

    /// The other half: the two figures really are separate properties, so the
    /// scan above is guarding something that exists rather than passing
    /// vacuously over a type that has neither.
    @Test func bothFiguresExistIndependently() throws {
        let context = try makeInMemoryContext()
        let plan = wanted(costCents: 240_000, into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 90_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id)
        viewModel.load()
        viewModel.toggle(item)

        #expect(viewModel.estimatedCostCents != viewModel.selectedValueCents)
        #expect(viewModel.estimatedCostCents == 240_000)
        #expect(viewModel.selectedValueCents == 90_000)
    }
}

/// The trend key in the order (003 plan Q1, criteria 1–4), over the pure
/// function with a dictionary standing in for the store.
@Suite("Sell Plan ranking — the trend key")
struct SellPlanRankingTests {
    private func order(_ items: [Item], _ trends: [UUID: MarketTrend]) -> [String] {
        SellPlanViewModel
            .candidates(from: items, alreadySelected: [], trend: { trends[$0] })
            .map(\.name)
    }

    /// Criterion 1, both ways round the value: the rising item leads whether
    /// it's the cheaper of the pair or the dearer.
    @Test func aRisingCandidateLeadsAFlatOneAtTheSameDesire() throws {
        let context = try makeInMemoryContext()
        let cheapRise = owned("Cheap rise", desire: 2, valueCents: 10_000, into: context)
        let dearFlat = owned("Dear flat", desire: 2, valueCents: 900_000, into: context)
        #expect(order([dearFlat, cheapRise], [cheapRise.id: .up, dearFlat.id: .flat]) == ["Cheap rise", "Dear flat"])

        let dearRise = owned("Dear rise", desire: 2, valueCents: 900_000, into: context)
        let cheapFlat = owned("Cheap flat", desire: 2, valueCents: 10_000, into: context)
        #expect(order([cheapFlat, dearRise], [dearRise.id: .up, cheapFlat.id: .flat]) == ["Dear rise", "Cheap flat"])
    }

    /// Criterion 2, likewise: falling is last whatever it's worth.
    @Test func aFallingCandidateTrailsAFlatOneAtTheSameDesire() throws {
        let context = try makeInMemoryContext()
        let dearFall = owned("Dear fall", desire: 2, valueCents: 900_000, into: context)
        let cheapFlat = owned("Cheap flat", desire: 2, valueCents: 10_000, into: context)
        #expect(order([dearFall, cheapFlat], [dearFall.id: .down, cheapFlat.id: .flat]) == ["Cheap flat", "Dear fall"])

        let cheapFall = owned("Cheap fall", desire: 2, valueCents: 10_000, into: context)
        let dearFlat = owned("Dear flat", desire: 2, valueCents: 900_000, into: context)
        #expect(order([cheapFall, dearFlat], [cheapFall.id: .down, dearFlat.id: .flat]) == ["Dear flat", "Cheap fall"])
    }

    /// Criterion 3, and the reason the group key sits *behind* desire: what the
    /// market is doing never promotes something the user is less willing to
    /// part with.
    @Test func aRisingLessWillingItemStaysBelowAWillingOne() throws {
        let context = try makeInMemoryContext()
        let rising = owned("Rising but wanted", desire: 3, valueCents: 900_000, into: context)
        let willing = owned("Willing, flat", desire: 1, valueCents: 10_000, into: context)
        #expect(order([rising, willing], [rising.id: .up, willing.id: .flat]) == ["Willing, flat", "Rising but wanted"])
    }

    /// Criterion 4: inside one desire level and one trend group the 001 order
    /// is untouched — value, then name.
    @Test func withinOneGroupTheValueThenTheNameDecides() throws {
        let context = try makeInMemoryContext()
        let dear = owned("Bass", desire: 2, valueCents: 900_000, into: context)
        let sameA = owned("Amp", desire: 2, valueCents: 10_000, into: context)
        let sameB = owned("Zither", desire: 2, valueCents: 10_000, into: context)
        let trends = [dear.id: MarketTrend.up, sameA.id: .up, sameB.id: .up]
        #expect(order([sameB, sameA, dear], trends) == ["Bass", "Amp", "Zither"])
    }

    /// No trend and a flat one are one group, checked in **both** directions so
    /// separating them either way goes red: whichever of the pair is worth more
    /// leads, regardless of which one has the trend.
    @Test func noTrendRanksExactlyWhereFlatDoes() throws {
        let context = try makeInMemoryContext()
        let dearUnknown = owned("Dear unknown", desire: 2, valueCents: 900_000, into: context)
        let cheapFlat = owned("Cheap flat", desire: 2, valueCents: 10_000, into: context)
        #expect(order([cheapFlat, dearUnknown], [cheapFlat.id: .flat]) == ["Dear unknown", "Cheap flat"])

        let dearFlat = owned("Dear flat", desire: 2, valueCents: 900_000, into: context)
        let cheapUnknown = owned("Cheap unknown", desire: 2, valueCents: 10_000, into: context)
        #expect(order([cheapUnknown, dearFlat], [dearFlat.id: .flat]) == ["Dear flat", "Cheap unknown"])
    }
}

/// The same order and the row's readers through `load()`, with real figure
/// rows in the device-local store — the integration the pure suite can't give.
@Suite("SellPlanViewModel — the market readers")
struct SellPlanMarketReaderTests {
    private let day: TimeInterval = 24 * 60 * 60
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private let product = MarketProduct(
        id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    private func figure(_ median: Int, at: Date) -> MarketReading {
        .figure(MarketFigure(
            medianCents: median, lowCents: median - 1_000, highCents: median + 1_000,
            p10Cents: median - 500, p90Cents: median + 500,
            count: 5, fetchedAt: at, isTruncated: false, yearScope: .any
        ))
    }

    private func withheld(at: Date) -> MarketReading {
        .withheld(count: 1, usedLowCents: 100_000, fetchedAt: at, yearScope: .any)
    }

    /// The readings in order, through the store's own write path — so the
    /// stored trend is the one a real refresh would have left behind rather
    /// than one the test asserted into place.
    private func record(_ readings: [MarketReading], for id: UUID, in context: ModelContext) throws {
        for reading in readings {
            try MarketLocalStore.record(reading, product: product, for: MarketSubjectKey(subjectID: id, kind: .owned), in: context)
        }
    }

    @Test func aRisingCandidateOutranksAFlatOneOfHigherValueThroughLoad() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let plan = wanted(into: context)
        let rising = owned("Rising", desire: 2, valueCents: 50_000, into: context)
        let flat = owned("Flat", desire: 2, valueCents: 900_000, into: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(112_000, at: t0)], for: rising.id, in: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(101_000, at: t0)], for: flat.id, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.t0 })
        viewModel.load()

        #expect(viewModel.currentTrend(for: rising.id) == .up)
        #expect(viewModel.currentTrend(for: flat.id) == .flat)
        #expect(viewModel.candidates.map(\.name) == ["Rising", "Flat"])
    }

    @Test func theReasonNumbersBelongToTheRisingCandidateAlone() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let plan = wanted(into: context)
        let rising = owned("Rising", desire: 2, valueCents: 50_000, into: context)
        let falling = owned("Falling", desire: 2, valueCents: 50_000, into: context)
        let unmatched = owned("Unmatched", desire: 2, valueCents: 50_000, into: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(112_000, at: t0)], for: rising.id, in: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(80_000, at: t0)], for: falling.id, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.t0 })
        viewModel.load()

        let rise = try #require(viewModel.rise(for: rising.id))
        #expect(rise.percent == 12)
        #expect(rise.since == t0 - 8 * day, "the date is the earlier reading's, not the latest fetch's")
        #expect(viewModel.currentTrend(for: falling.id) == .down)
        #expect(viewModel.rise(for: falling.id) == nil)
        #expect(viewModel.rise(for: unmatched.id) == nil)
        #expect(viewModel.summary(for: unmatched.id) == nil)
    }

    /// Criterion 6, the stale half: the figure is older than thirty days, so
    /// the stored `.up` says nothing here — no median, no reason, and a
    /// neutral rank behind a rising item worth far less.
    @Test func aFigureOlderThanThirtyDaysRanksNeutralAndSaysNothing() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let plan = wanted(into: context)
        let stale = owned("Stale", desire: 2, valueCents: 900_000, into: context)
        let rising = owned("Rising", desire: 2, valueCents: 50_000, into: context)
        try record([figure(100_000, at: t0 - 40 * day), figure(112_000, at: t0 - 31 * day)], for: stale.id, in: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(112_000, at: t0)], for: rising.id, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.t0 })
        viewModel.load()

        #expect(viewModel.summary(for: stale.id)?.trend == .up, "the classification is still stored")
        #expect(viewModel.currentTrend(for: stale.id) == nil)
        #expect(viewModel.summary(for: stale.id)?.medianCents == nil)
        #expect(viewModel.rise(for: stale.id) == nil)
        #expect(viewModel.candidates.map(\.name) == ["Rising", "Stale"])
    }

    /// Criterion 6, the withheld half: fetched today, and still nothing to say
    /// — too few listings to publish a median means no arrow and no rank of
    /// its own.
    @Test func aWithheldFigureRanksNeutralAndSaysNothing() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let plan = wanted(into: context)
        let quiet = owned("Withheld", desire: 2, valueCents: 900_000, into: context)
        let rising = owned("Rising", desire: 2, valueCents: 50_000, into: context)
        try record([figure(100_000, at: t0 - 40 * day), figure(112_000, at: t0 - 8 * day), withheld(at: t0)], for: quiet.id, in: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(112_000, at: t0)], for: rising.id, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.t0 })
        viewModel.load()

        #expect(viewModel.summary(for: quiet.id)?.trend == .up, "the classification is still stored")
        #expect(viewModel.currentTrend(for: quiet.id) == nil)
        #expect(viewModel.summary(for: quiet.id)?.medianCents == nil)
        #expect(viewModel.rise(for: quiet.id) == nil)
        #expect(viewModel.candidates.map(\.name) == ["Rising", "Withheld"])
    }

    /// A history read that fails costs a sentence, never a candidate: the plan
    /// still lists everything, in the ranked order the figures already gave,
    /// and the screen reports no failure.
    @Test func aHistoryReadThatThrowsLosesTheReasonAndNothingElse() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let plan = wanted(into: context)
        let rising = owned("Rising", desire: 2, valueCents: 50_000, into: context)
        let flat = owned("Flat", desire: 2, valueCents: 900_000, into: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(112_000, at: t0)], for: rising.id, in: context)
        try record([figure(100_000, at: t0 - 8 * day), figure(101_000, at: t0)], for: flat.id, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(
            modelContext: context, wishlistItemID: plan.id, now: { self.t0 },
            history: { _, _ in throw TestFailure("the local store is unreadable") }
        )
        viewModel.load()

        #expect(viewModel.rises.isEmpty)
        #expect(viewModel.rise(for: rising.id) == nil)
        #expect(viewModel.candidates.map(\.name) == ["Rising", "Flat"])
        #expect(viewModel.currentTrend(for: rising.id) == .up, "the ranking reads the figures, not the history")
        #expect(viewModel.loadFailureMessage == nil)
    }

    /// Criterion 7: the combined figure is the person's values and only those.
    /// The median is right there in the summary and takes no part in it.
    @Test func theCombinedValueIsThePersonsFigureNotTheMarketsOne() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let plan = wanted(into: context)
        let item = owned("Ready to sell", desire: 1, valueCents: 60_000, into: context)
        try record([figure(140_000, at: t0)], for: item.id, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.t0 })
        viewModel.load()
        viewModel.toggle(item)

        #expect(viewModel.summary(for: item.id)?.medianCents == 140_000, "the median is present to be summed — and isn't")
        #expect(viewModel.selectedValueCents == 60_000)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
