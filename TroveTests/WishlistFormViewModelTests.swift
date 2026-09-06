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

    // MARK: - The year field (002 Amendment A, P18)

    /// P18's table again, over the same `YearCase` rows the item form uses —
    /// the two fields validate identically, so they share the table rather
    /// than each carrying a copy to drift.
    @Test(arguments: YearCase.all)
    func validatesTheYearField(yearCase: YearCase) throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "Martin D-18"
        viewModel.categoryPath = "Music/Guitars"
        viewModel.estimatedCost = 2_400
        viewModel.yearText = yearCase.typed

        let saved = viewModel.save()
        #expect(saved == yearCase.isAccepted)
        #expect(viewModel.validationErrors.contains(.yearInvalid) == !yearCase.isAccepted)

        let items = try context.fetch(FetchDescriptor<WishlistItem>())
        if yearCase.isAccepted {
            #expect(items.count == 1)
            #expect(items.first?.year == yearCase.expected)
        } else {
            #expect(items.isEmpty)
        }
    }

    /// The message the form shows, pinned whole — the sentence and the bound
    /// it names.
    @Test func pinsTheYearValidationMessage() throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())
        let nextYear = Calendar.current.component(.year, from: .now) + 1

        #expect(viewModel.maximumYear == nextYear)
        #expect(
            MarketCopy.yearValidationError(nextYear: viewModel.maximumYear)
                == "Year should be four digits, 1900 to \(nextYear)."
        )
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
    /// The year survives the store, not just the object graph: read back on a
    /// *second* context over the same container, which sees only what `save()`
    /// actually wrote.
    @Test func roundTripsTheYearThroughTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let existing = WishlistItem(name: "Martin D-18", categoryPath: "Music/Guitars")
        context.insert(existing)
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)
        viewModel.yearText = "1975"
        #expect(viewModel.save())

        let reader = ModelContext(container)
        let stored = try #require(try reader.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(stored.year == 1975)

        // And back out again: an existing year loads into the field, and
        // blanking it clears the model.
        let reopened = WishlistFormViewModel(modelContext: context, editing: existing)
        #expect(reopened.yearText == "1975")
        reopened.yearText = ""
        #expect(reopened.save())

        let after = ModelContext(container)
        let cleared = try #require(try after.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(cleared.year == nil)
    }

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

    // MARK: - Photos

    /// Reopening an item for edit has to bring its photos back, or saving any
    /// other field would silently clear them — `save()` assigns the whole set.
    @Test func editingLoadsTheExistingPhotosAndKeepsThemOnSave() throws {
        let context = try makeInMemoryContext()
        let existing = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(existing)
        existing.photos = PhotoSelection.appending([Data([0x01]), Data([0x02])], to: [])
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)
        #expect(viewModel.photos.count == 2)

        viewModel.estimatedCost = 2_400
        #expect(viewModel.save())

        #expect(existing.photos?.count == 2)
    }

    @Test func removingEveryPhotoInTheFormEmptiesTheItem() throws {
        let context = try makeInMemoryContext()
        let existing = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(existing)
        existing.photos = PhotoSelection.appending([Data([0x01])], to: [])
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)
        viewModel.photos = []
        #expect(viewModel.save())

        #expect(existing.photos?.isEmpty == true)
    }

    /// Photos are optional, matching owned items — spec.md's entity list says
    /// "multiple photos supported", not "at least one", and the acceptance
    /// criteria agree.
    @Test func aWishlistItemSavesWithNoPhotosAtAll() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "Vox AC15 Custom"
        viewModel.categoryPath = "Music/Amps"
        viewModel.estimatedCost = 1_050

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)

        let saved = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(saved.photos?.isEmpty == true)
    }

    // MARK: - Desire to own

    /// "Soon", not "Someday": an entry someone bothered to type is already
    /// past someday, and starting everything at the top would make the rating
    /// useless for telling entries apart.
    @Test func newItemsDefaultToTheMiddleOfTheScale() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistFormViewModel(modelContext: context)
        #expect(viewModel.desireToOwn == 2)

        viewModel.name = "Vox AC15 Custom"
        viewModel.categoryPath = "Music/Amps"
        viewModel.estimatedCost = 1_050
        #expect(viewModel.save())

        let saved = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(saved.desireToOwn == 2)
        #expect(DesireToOwnLevel(clamping: saved.desireToOwn) == .soon)
    }

    /// Clamped on assignment, not at save time, so a control bound straight to
    /// this can't drive it out of range mid-edit — same as the item form's
    /// `desireToKeep`.
    @Test(arguments: [(-40, 1), (0, 1), (1, 1), (2, 2), (3, 3), (4, 3), (99, 3)])
    func clampsOnAssignmentRatherThanOnSave(assigned: Int, expected: Int) throws {
        let viewModel = WishlistFormViewModel(modelContext: try makeInMemoryContext())
        viewModel.desireToOwn = assigned

        #expect(viewModel.desireToOwn == expected)
    }

    @Test func roundTripsThroughAnEdit() throws {
        let context = try makeInMemoryContext()
        let existing = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(existing)
        existing.desireToOwn = 3
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)
        #expect(viewModel.desireToOwn == 3)

        viewModel.desireToOwn = 1
        #expect(viewModel.save())
        #expect(existing.desireToOwn == 1)
    }

    /// A value stored outside the range — by an import, or a build that
    /// predates the clamp — has to come back into it when the form loads.
    @Test func loadingAnOutOfRangeStoredValueClampsIt() throws {
        let context = try makeInMemoryContext()
        let existing = WishlistItem(name: "Vox AC15 Custom", categoryPath: "Music/Amps")
        context.insert(existing)
        existing.desireToOwn = 9
        try context.save()

        let viewModel = WishlistFormViewModel(modelContext: context, editing: existing)

        #expect(viewModel.desireToOwn == 3)
    }
}
