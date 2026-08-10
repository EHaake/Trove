import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("WishlistFormViewModel — validation")
struct WishlistFormValidationTests {
    @Test func rejectsAnEmptyForm() throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.nameMissing))
        #expect(viewModel.validationErrors.contains(.categoryMissing))
        #expect(viewModel.validationErrors.contains(.costMissing))
    }

    @Test func rejectsAWhitespaceOnlyName() throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())
        viewModel.name = "   "
        viewModel.categoryPath = "Photography/Lenses"
        viewModel.estimatedCost = 240

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.nameMissing))
    }

    /// The same trap the item form's purchase price had: an untouched field
    /// must not save as $0, but a deliberate zero is a real answer — something
    /// you expect to be given or to trade for.
    @Test func rejectsABlankCostButAcceptsATypedZero() throws {
        let context = try makeInMemoryContext()

        let blank = WishlistFormViewModel(modelContext: context)
        blank.name = "Summicron 35mm"
        blank.categoryPath = "Photography/Lenses"
        #expect(blank.save() == false)
        #expect(blank.validationErrors.contains(.costMissing))

        let zero = WishlistFormViewModel(modelContext: context)
        zero.name = "Hand-me-down"
        zero.categoryPath = "Photography/Lenses"
        zero.estimatedCost = 0
        #expect(zero.save())
    }

    @Test func rejectsANegativeCost() throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())
        viewModel.name = "Summicron 35mm"
        viewModel.categoryPath = "Photography/Lenses"
        viewModel.estimatedCost = -10

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.costNegative))
    }

    @Test func clearsEarlierErrorsOnASuccessfulSave() throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())
        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.isEmpty == false)

        viewModel.name = "Summicron 35mm"
        viewModel.categoryPath = "Photography/Lenses"
        viewModel.estimatedCost = 2_400

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)
    }
}

@Suite("WishlistFormViewModel — saving")
struct WishlistFormSaveTests {
    private func fetchAll(_ context: ModelContext) throws -> [WishlistItem] {
        try context.fetch(FetchDescriptor<WishlistItem>())
    }

    @Test func createsAWishlistItem() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "  Summicron 35mm f/2  "
        viewModel.categoryPath = "Photography/Lenses"
        viewModel.estimatedCost = Decimal(string: "2400.50")!
        viewModel.notes = "  v4 only  "

        #expect(viewModel.save())

        let saved = try #require(try fetchAll(context).first)
        #expect(saved.name == "Summicron 35mm f/2")
        #expect(saved.categoryPath == "Photography/Lenses")
        #expect(saved.estimatedCostCents == 240_050)
        #expect(saved.notes == "v4 only")
    }

    @Test func blankNotesArePersistedAsNilRatherThanEmpty() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "Vox AC15"
        viewModel.categoryPath = "Music/Amps"
        viewModel.estimatedCost = 1_050
        viewModel.notes = "   "

        #expect(viewModel.save())
        #expect(try fetchAll(context).first?.notes == nil)
    }

    @Test func editingUpdatesInPlaceRatherThanInserting() throws {
        let context = try makeInMemoryContext()
        let existing = WishlistItem(
            name: "Vox AC15",
            categoryPath: "Music/Amps",
            estimatedCostCents: 105_000
        )
        context.insert(existing)
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)
        #expect(viewModel.isEditing)
        #expect(viewModel.name == "Vox AC15")
        #expect(viewModel.estimatedCost == Decimal(1_050))

        viewModel.estimatedCost = 950
        #expect(viewModel.save())

        let all = try fetchAll(context)
        #expect(all.count == 1)
        #expect(all.first?.estimatedCostCents == 95_000)
    }

    /// Same rule as the item form: reuse the casing already in use rather than
    /// letting the taxonomy sprout near-duplicates.
    @Test func canonicalizesTheCategoryAgainstPathsAlreadyInUse() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "Summicron"
        viewModel.categoryPath = "photography/cameras"
        viewModel.estimatedCost = 2_400

        #expect(viewModel.save())
        #expect(try fetchAll(context).first?.categoryPath == "Photography/Cameras")
    }

    /// Autocomplete spans both entities, per spec.md's acceptance criteria.
    @Test func suggestsCategoriesFromOwnedItemsAndWishlistItemsAlike() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        context.insert(WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps"))
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.loadCategorySuggestions()

        #expect(viewModel.categorySuggestions == ["Music/Amps", "Photography/Cameras"])
    }

    // MARK: - Manual ordering

    /// New entries land at the end of the user's manual order rather than
    /// jumping to the top of a list they've deliberately ranked.
    @Test func newItemsAreAppendedToTheManualOrder() throws {
        let context = try makeInMemoryContext()

        for name in ["First", "Second", "Third"] {
            let viewModel = WishlistFormViewModel(modelContext: context)
            viewModel.name = name
            viewModel.categoryPath = "Music/Amps"
            viewModel.estimatedCost = 100
            #expect(viewModel.save())
        }

        let saved = try fetchAll(context).sorted { $0.sortOrder < $1.sortOrder }
        #expect(saved.map(\.name) == ["First", "Second", "Third"])
        #expect(saved.map(\.sortOrder) == [0, 1, 2])
    }

    /// Counting rows would reuse a position after a deletion and put two items
    /// on the same rung; taking the highest in use can't.
    @Test func appendingAfterADeletionDoesNotReuseAPosition() throws {
        let context = try makeInMemoryContext()
        let first = WishlistItem(name: "First", categoryPath: "A", sortOrder: 0)
        let second = WishlistItem(name: "Second", categoryPath: "A", sortOrder: 1)
        context.insert(first)
        context.insert(second)
        try context.save()

        context.delete(first)
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "Third"
        viewModel.categoryPath = "A"
        viewModel.estimatedCost = 100
        #expect(viewModel.save())

        let orders = try fetchAll(context).map(\.sortOrder).sorted()
        #expect(orders == [1, 2])
        #expect(Set(orders).count == orders.count)
    }

    @Test func editingDoesNotDisturbTheManualOrder() throws {
        let context = try makeInMemoryContext()
        let existing = WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps", sortOrder: 7)
        context.insert(existing)
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)
        viewModel.name = "Vox AC15 Custom"
        #expect(viewModel.save())

        #expect(existing.sortOrder == 7)
    }

    // MARK: - Cost presets

    @Test func aPresetReadsAsChosenWhenItMatchesTheTypedAmount() throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())

        #expect(WishlistFormViewModel.costPresets.allSatisfy { !viewModel.isSelected(preset: $0) })

        viewModel.estimatedCost = 500
        #expect(viewModel.isSelected(preset: 500))
        #expect(viewModel.isSelected(preset: 250) == false)
    }

    @Test func presetsAreDistinctAndAscending() {
        let presets = WishlistFormViewModel.costPresets
        #expect(Set(presets).count == presets.count)
        #expect(presets == presets.sorted())
    }
}
