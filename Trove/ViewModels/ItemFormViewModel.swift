import Foundation
import Observation
import SwiftData

/// Backs the shared add/edit item form.
///
/// Money is held as `Decimal` here rather than as the model's `Int` cents:
/// this is the boundary where a user types "1299.00", so the conversion —
/// and its rounding — belongs on this side of it.
@Observable
final class ItemFormViewModel {
    enum ValidationError: Hashable {
        case nameMissing
        case categoryMissing
        case priceNegative
        case currentValueNegative
    }

    static let desireToKeepRange = 1...5

    var name: String = ""
    var categoryPath: String = ""
    var purchasePrice: Decimal = 0
    var purchaseDate: Date = .now
    var serialNumber: String = ""
    var purchaseLocation: String = ""
    var currentValue: Decimal?
    var condition: Condition = .excellent
    var conditionNotes: String = ""
    var notes: String = ""
    var photos: [Photo] = []

    private var storedDesireToKeep = 3

    /// Clamped on assignment rather than at save time, so the invariant holds
    /// for anything reading it mid-edit — a stepper bound straight to this
    /// can't drive it out of range.
    var desireToKeep: Int {
        get { storedDesireToKeep }
        set {
            storedDesireToKeep = min(
                max(newValue, Self.desireToKeepRange.lowerBound),
                Self.desireToKeepRange.upperBound
            )
        }
    }

    private(set) var validationErrors: Set<ValidationError> = []
    private(set) var saveFailureMessage: String?

    private let modelContext: ModelContext
    private let editingItem: Item?

    var isEditing: Bool { editingItem != nil }

    init(modelContext: ModelContext, editing item: Item? = nil) {
        self.modelContext = modelContext
        self.editingItem = item
        if let item {
            populate(from: item)
        }
    }

    /// Validates, then creates or updates. Returns whether anything was
    /// written; on `false`, `validationErrors` or `saveFailureMessage` says why.
    @discardableResult
    func save() -> Bool {
        saveFailureMessage = nil
        validationErrors = validate()
        guard validationErrors.isEmpty else { return false }

        let item = editingItem ?? Item()
        item.name = Self.trimmed(name)
        item.categoryPath = canonicalCategoryPath()
        item.purchasePriceCents = Self.cents(from: purchasePrice)
        item.purchaseDate = purchaseDate
        item.serialNumber = Self.nilIfBlank(serialNumber)
        item.purchaseLocation = Self.nilIfBlank(purchaseLocation)
        item.currentValueCents = currentValue.map(Self.cents(from:))
        item.desireToKeep = desireToKeep
        item.condition = condition
        item.conditionNotes = Self.nilIfBlank(conditionNotes)
        item.notes = Self.nilIfBlank(notes)
        item.photos = photos
        item.updatedAt = .now

        if editingItem == nil {
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
            return true
        } catch {
            saveFailureMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Conversion

    /// Rounds to the nearest cent rather than truncating, so a stray third
    /// decimal doesn't quietly lose the user a penny.
    static func cents(from amount: Decimal) -> Int {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func amount(fromCents cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    // MARK: - Private

    private func validate() -> Set<ValidationError> {
        var errors: Set<ValidationError> = []
        if Self.trimmed(name).isEmpty { errors.insert(.nameMissing) }
        if Self.trimmed(categoryPath).isEmpty { errors.insert(.categoryMissing) }
        if purchasePrice < 0 { errors.insert(.priceNegative) }
        if let currentValue, currentValue < 0 { errors.insert(.currentValueNegative) }
        return errors
    }

    /// Canonicalized at save time, per plan.md — reusing an existing path's
    /// casing rather than correcting the user's typing as they go.
    private func canonicalCategoryPath() -> String {
        let typed = Self.trimmed(categoryPath)
        let helper = CategoryPathHelper(modelContext: modelContext)
        return (try? helper.canonicalize(typed)) ?? typed
    }

    private func populate(from item: Item) {
        name = item.name
        categoryPath = item.categoryPath
        purchasePrice = Self.amount(fromCents: item.purchasePriceCents)
        purchaseDate = item.purchaseDate
        serialNumber = item.serialNumber ?? ""
        purchaseLocation = item.purchaseLocation ?? ""
        currentValue = item.currentValueCents.map(Self.amount(fromCents:))
        desireToKeep = item.desireToKeep
        condition = item.condition
        conditionNotes = item.conditionNotes ?? ""
        notes = item.notes ?? ""
        photos = item.photos ?? []
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Optional-in-the-model fields are plain strings here so they can bind to
    /// text fields; blank means "not provided", not an empty value.
    private static func nilIfBlank(_ value: String) -> String? {
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
