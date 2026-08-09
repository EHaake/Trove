import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("ItemFormViewModel — creating")
struct ItemFormViewModelCreateTests {
    @Test func savesAValidItem() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars/Electric"
        viewModel.purchasePrice = 1_299
        viewModel.purchaseDate = Date(timeIntervalSince1970: 1_000)

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)

        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.name == "Fender Telecaster")
        #expect(items.first?.categoryPath == "Music/Guitars/Electric")
        #expect(items.first?.purchasePriceCents == 129_900)
    }

    @Test func appliesModelDefaultsToFieldsLeftAlone() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"

        #expect(viewModel.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.desireToKeep == 3)
        #expect(item.currencyCode == "USD")
        #expect(item.condition == .excellent)
        #expect(item.currentValueCents == nil)
        #expect(item.purchasePriceCents == 0)
    }

    @Test func rejectsAMissingName() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.categoryPath = "Music/Guitars"

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.nameMissing))
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    /// Whitespace isn't a name.
    @Test func rejectsAWhitespaceOnlyName() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "   \n "
        viewModel.categoryPath = "Music/Guitars"

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.nameMissing))
    }

    @Test func rejectsAMissingCategory() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.categoryMissing))
    }

    @Test func rejectsANegativePrice() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"
        viewModel.purchasePrice = -1

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.priceNegative))
    }

    @Test func rejectsANegativeCurrentValue() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"
        viewModel.currentValue = -5

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.currentValueNegative))
    }

    /// A blank price field isn't "zero dollars typed" — it's untouched. It
    /// still saves as zero, but the field has to start empty or the digits the
    /// user types append to a pre-filled 0.
    @Test func startsWithNoPriceEntered() throws {
        let context = try makeInMemoryContext()
        #expect(ItemFormViewModel(modelContext: context).purchasePrice == nil)
    }

    @Test func savesABlankPriceAsZero() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Hand-me-down amp"
        viewModel.categoryPath = "Music/Amps"

        #expect(viewModel.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.purchasePriceCents == 0)
    }

    /// A gift or a hand-me-down is a real thing to own.
    @Test func acceptsAZeroPrice() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Hand-me-down amp"
        viewModel.categoryPath = "Music/Amps"
        viewModel.purchasePrice = 0

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)
    }

    @Test func reportsEveryValidationFailureAtOnce() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.purchasePrice = -1

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors == [.nameMissing, .categoryMissing, .priceNegative])
    }

    /// Fixing the problem and re-saving must clear the old complaints.
    @Test func clearsValidationErrorsOnASubsequentValidSave() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.isEmpty == false)

        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)
    }

    @Test func trimsWhitespaceFromTextFields() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "  Fender Telecaster  "
        viewModel.categoryPath = "  Music/Guitars  "

        #expect(viewModel.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.name == "Fender Telecaster")
        #expect(item.categoryPath == "Music/Guitars")
    }

    /// Blank optional fields are absent, not empty strings — the model uses
    /// `nil` to mean "not provided".
    @Test func storesBlankOptionalFieldsAsNil() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"
        viewModel.serialNumber = "   "
        viewModel.purchaseLocation = ""
        viewModel.conditionNotes = ""
        viewModel.notes = "  "

        #expect(viewModel.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.serialNumber == nil)
        #expect(item.purchaseLocation == nil)
        #expect(item.conditionNotes == nil)
        #expect(item.notes == nil)
    }

    /// The save-time canonicalization rule from plan.md, reaching through the
    /// form: typing an existing path in different casing reuses the stored one.
    @Test func canonicalizesTheCategoryPathOnSave() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Existing", categoryPath: "Photography/Cameras"))
        try context.save()

        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Leica M6"
        viewModel.categoryPath = "photography/cameras"

        #expect(viewModel.save())

        let saved = try #require(
            try context.fetch(FetchDescriptor<Item>()).first { $0.name == "Leica M6" }
        )
        #expect(saved.categoryPath == "Photography/Cameras")
    }
}

@Suite("ItemFormViewModel — category suggestions")
struct ItemFormViewModelSuggestionTests {
    @Test func startsWithNoSuggestions() throws {
        let context = try makeInMemoryContext()
        #expect(ItemFormViewModel(modelContext: context).categorySuggestions.isEmpty)
    }

    @Test func loadsPathsAlreadyInUseAcrossBothEntities() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(categoryPath: "Photography/Cameras"))
        context.insert(WishlistItem(categoryPath: "Music/Amps"))
        try context.save()

        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.loadCategorySuggestions()

        #expect(viewModel.categorySuggestions == ["Music/Amps", "Photography/Cameras"])
    }

    @Test func staysEmptyWhenNothingHasACategoryYet() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)

        viewModel.loadCategorySuggestions()

        #expect(viewModel.categorySuggestions.isEmpty)
    }
}

@Suite("ItemFormViewModel — desire-to-keep clamping")
struct ItemFormViewModelClampingTests {
    @Test func defaultsToNeutral() throws {
        let context = try makeInMemoryContext()
        #expect(ItemFormViewModel(modelContext: context).desireToKeep == 3)
    }

    @Test(arguments: [(0, 1), (-7, 1), (1, 1), (3, 3), (5, 5), (6, 5), (99, 5)])
    func clampsToTheValidRange(input: Int, expected: Int) throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)

        viewModel.desireToKeep = input

        #expect(viewModel.desireToKeep == expected)
    }

    @Test func persistsTheClampedValueRatherThanTheRawOne() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"
        viewModel.desireToKeep = 42

        #expect(viewModel.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.desireToKeep == 5)
    }
}

@Suite("ItemFormViewModel — editing")
struct ItemFormViewModelEditTests {
    private func existingItem(in context: ModelContext) throws -> Item {
        let item = Item(
            name: "Fender Telecaster",
            categoryPath: "Music/Guitars/Electric",
            purchasePriceCents: 129_900,
            purchaseDate: Date(timeIntervalSince1970: 1_000),
            serialNumber: "TL-1952",
            currentValueCents: 145_000,
            desireToKeep: 2,
            condition: .good,
            notes: "Neck needs a shim"
        )
        context.insert(item)
        try context.save()
        return item
    }

    @Test func populatesEveryFieldFromTheItem() throws {
        let context = try makeInMemoryContext()
        let item = try existingItem(in: context)

        let viewModel = ItemFormViewModel(modelContext: context, editing: item)

        #expect(viewModel.isEditing)
        #expect(viewModel.name == "Fender Telecaster")
        #expect(viewModel.categoryPath == "Music/Guitars/Electric")
        #expect(viewModel.purchasePrice == Decimal(string: "1299")!)
        #expect(viewModel.serialNumber == "TL-1952")
        #expect(viewModel.currentValue == Decimal(string: "1450")!)
        #expect(viewModel.desireToKeep == 2)
        #expect(viewModel.condition == .good)
        #expect(viewModel.notes == "Neck needs a shim")
    }

    @Test func createModeIsNotEditing() throws {
        let context = try makeInMemoryContext()
        #expect(ItemFormViewModel(modelContext: context).isEditing == false)
    }

    @Test func updatesInPlaceRatherThanInsertingACopy() throws {
        let context = try makeInMemoryContext()
        let item = try existingItem(in: context)

        let viewModel = ItemFormViewModel(modelContext: context, editing: item)
        viewModel.name = "Fender Telecaster '52 Reissue"
        #expect(viewModel.save())

        let items = try context.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.name == "Fender Telecaster '52 Reissue")
    }

    @Test func bumpsUpdatedAt() throws {
        let context = try makeInMemoryContext()
        let item = try existingItem(in: context)
        item.updatedAt = Date(timeIntervalSince1970: 1_000)
        try context.save()

        let viewModel = ItemFormViewModel(modelContext: context, editing: item)
        viewModel.name = "Renamed"
        #expect(viewModel.save())

        #expect(item.updatedAt > Date(timeIntervalSince1970: 1_000))
    }

    /// Editing must not rewrite when the item was originally acquired.
    @Test func leavesCreatedAtAlone() throws {
        let context = try makeInMemoryContext()
        let item = try existingItem(in: context)
        let originalCreatedAt = item.createdAt

        let viewModel = ItemFormViewModel(modelContext: context, editing: item)
        viewModel.name = "Renamed"
        #expect(viewModel.save())

        #expect(item.createdAt == originalCreatedAt)
    }

    @Test func canClearAnOptionalFieldByBlankingIt() throws {
        let context = try makeInMemoryContext()
        let item = try existingItem(in: context)

        let viewModel = ItemFormViewModel(modelContext: context, editing: item)
        viewModel.serialNumber = ""
        viewModel.currentValue = nil
        #expect(viewModel.save())

        #expect(item.serialNumber == nil)
        #expect(item.currentValueCents == nil)
    }
}

@Suite("ItemFormViewModel — money conversion")
struct ItemFormViewModelMoneyTests {
    @Test(arguments: [
        ("0", 0),
        ("0.01", 1),
        ("1299", 129_900),
        ("1299.99", 129_999),
        ("0.5", 50),
    ])
    func convertsDecimalAmountsToCents(input: String, expected: Int) {
        #expect(ItemFormViewModel.cents(from: Decimal(string: input)!) == expected)
    }

    /// A third decimal place rounds to the nearest cent rather than truncating.
    @Test(arguments: [("1.005", 101), ("1.004", 100), ("1.006", 101)])
    func roundsSubCentAmounts(input: String, expected: Int) {
        #expect(ItemFormViewModel.cents(from: Decimal(string: input)!) == expected)
    }

    @Test func centsRoundTripBackToTheSameAmount() {
        let amount = Decimal(string: "1299.99")!
        let cents = ItemFormViewModel.cents(from: amount)
        #expect(ItemFormViewModel.amount(fromCents: cents) == amount)
    }
}
