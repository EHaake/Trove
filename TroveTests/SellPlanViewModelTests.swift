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
