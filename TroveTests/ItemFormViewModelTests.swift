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
        viewModel.purchasePrice = 0

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
        viewModel.purchasePrice = 0
        viewModel.currentValue = -5

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.currentValueNegative))
    }

    /// The field starts empty rather than pre-filled with 0, or the digits the
    /// user types append to that zero. See `rejectsABlankPrice` for what
    /// leaving it empty then means.
    @Test func startsWithNoPriceEntered() throws {
        let context = try makeInMemoryContext()
        #expect(ItemFormViewModel(modelContext: context).purchasePrice == nil)
    }

    /// Price is required, so an untouched field is rejected rather than
    /// quietly stored as zero. That's the whole reason a deliberate zero and a
    /// blank field are different states.
    @Test func rejectsABlankPrice() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Hand-me-down amp"
        viewModel.categoryPath = "Music/Amps"

        #expect(viewModel.save() == false)
        #expect(viewModel.validationErrors.contains(.priceMissing))
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    /// Blank and zero must not collapse into each other: one is an unanswered
    /// required field, the other is an answer.
    @Test func distinguishesABlankPriceFromADeliberateZero() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Hand-me-down amp"
        viewModel.categoryPath = "Music/Amps"

        #expect(viewModel.save() == false)

        viewModel.purchasePrice = 0

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)
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
        viewModel.purchasePrice = 0

        #expect(viewModel.save())
        #expect(viewModel.validationErrors.isEmpty)
    }

    @Test func trimsWhitespaceFromTextFields() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "  Fender Telecaster  "
        viewModel.categoryPath = "  Music/Guitars  "
        viewModel.purchasePrice = 0

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
        viewModel.purchasePrice = 0
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
    // MARK: - The year field (002 Amendment A, P18)

    /// P18's table. `nil` expects a save with no year; a non-`nil` expects a
    /// save with that year; `.rejected` expects no save at all and the year
    /// error. The bounds are computed from the calendar rather than written
    /// down, so this suite doesn't expire on New Year's Day.
    @Test(arguments: YearCase.all)
    func validatesTheYearField(yearCase: YearCase) throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Fender Telecaster"
        viewModel.categoryPath = "Music/Guitars"
        viewModel.purchasePrice = 1_299
        viewModel.yearText = yearCase.typed

        let saved = viewModel.save()
        #expect(saved == yearCase.isAccepted)
        #expect(viewModel.validationErrors.contains(.yearInvalid) == !yearCase.isAccepted)

        let items = try context.fetch(FetchDescriptor<Item>())
        if yearCase.isAccepted {
            #expect(items.count == 1)
            #expect(items.first?.year == yearCase.expected)
        } else {
            #expect(items.isEmpty)
        }
    }

    /// The message the form shows, pinned whole — the sentence and the bound
    /// it names, not just "some error".
    @Test func pinsTheYearValidationMessage() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        let nextYear = Calendar.current.component(.year, from: .now) + 1

        #expect(viewModel.maximumYear == nextYear)
        #expect(
            MarketCopy.yearValidationError(nextYear: viewModel.maximumYear)
                == "Year should be four digits, 1900 to \(nextYear)."
        )
    }

    @Test func canonicalizesTheCategoryPathOnSave() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Existing", categoryPath: "Photography/Cameras"))
        try context.save()

        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Leica M6"
        viewModel.categoryPath = "photography/cameras"
        viewModel.purchasePrice = 0

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
        viewModel.purchasePrice = 0
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

    /// The year survives the store, not just the object graph: read back on a
    /// *second* context over the same container, which sees only what `save()`
    /// actually wrote.
    @Test func roundTripsTheYearThroughTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Martin D-18", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemFormViewModel(modelContext: context, editing: item)
        viewModel.yearText = "1975"
        #expect(viewModel.save())

        let reader = ModelContext(container)
        let stored = try #require(try reader.fetch(FetchDescriptor<Item>()).first)
        #expect(stored.year == 1975)

        // And back out again: an existing year loads into the field, and
        // blanking it clears the model.
        let reopened = ItemFormViewModel(modelContext: context, editing: item)
        #expect(reopened.yearText == "1975")
        reopened.yearText = ""
        #expect(reopened.save())

        let after = ModelContext(container)
        let cleared = try #require(try after.fetch(FetchDescriptor<Item>()).first)
        #expect(cleared.year == nil)
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
        #expect(Money.cents(from: Decimal(string: input)!) == expected)
    }

    /// A third decimal place rounds to the nearest cent rather than truncating.
    @Test(arguments: [("1.005", 101), ("1.004", 100), ("1.006", 101)])
    func roundsSubCentAmounts(input: String, expected: Int) {
        #expect(Money.cents(from: Decimal(string: input)!) == expected)
    }

    @Test func centsRoundTripBackToTheSameAmount() {
        let amount = Decimal(string: "1299.99")!
        let cents = Money.cents(from: amount)
        #expect(Money.amount(fromCents: cents) == amount)
    }
}

/// One row of P18's table, shared by the item and wishlist form suites: the
/// two fields validate the year identically, and a second copy of the table
/// is a second thing to keep in step.
/// `nonisolated` because `@Test(arguments:)` evaluates its arguments outside
/// the main actor, and this target's default isolation is `MainActor` — the
/// same reason `MarketCopy` is declared that way.
nonisolated struct YearCase: CustomStringConvertible, Sendable {
    let typed: String
    /// The year expected in the store, or `nil` for "saves with no year".
    let expected: Int?
    let isAccepted: Bool

    static var all: [YearCase] {
        let nextYear = Calendar.current.component(.year, from: .now) + 1
        return [
            YearCase(typed: "", expected: nil, isAccepted: true),
            YearCase(typed: "  ", expected: nil, isAccepted: true),
            YearCase(typed: "1975", expected: 1975, isAccepted: true),
            YearCase(typed: "1900", expected: 1900, isAccepted: true),
            YearCase(typed: String(nextYear), expected: nextYear, isAccepted: true),
            YearCase(typed: "75", expected: nil, isAccepted: false),
            YearCase(typed: "abc", expected: nil, isAccepted: false),
            YearCase(typed: "1899", expected: nil, isAccepted: false),
            // Five digits, and in range once parsed — the row that makes the
            // four-digit rule falsifiable on its own. "75" is caught by the
            // lower bound, so it can't stand in for this.
            YearCase(typed: "01975", expected: nil, isAccepted: false),
            YearCase(typed: String(nextYear + 1), expected: nil, isAccepted: false),
        ]
    }

    var description: String { typed.isEmpty ? "(blank)" : typed }
}
