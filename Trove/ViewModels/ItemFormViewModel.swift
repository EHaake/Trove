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
        /// Left blank. Distinct from `priceNegative`, and distinct from a
        /// deliberate zero — price is a required field, so "untouched" has to
        /// be rejected even though "free" is a legitimate answer.
        case priceMissing
        case priceNegative
        case currentValueNegative
    }

    static let desireToKeepRange = 1...5

    var name: String = ""
    var categoryPath: String = ""
    /// Optional so a new form starts blank rather than pre-filled with `0`.
    /// A pre-filled zero can't be typed over — the digits append to it, so
    /// every new item began "$0…" until the user deleted the zero, which is at
    /// odds with the quick-add bar the spec sets.
    ///
    /// Blank is rejected rather than quietly saved as zero: price is required
    /// alongside name, category and date. A typed `0` still saves, because a
    /// gift is a real thing to own — the difference is deliberate zero versus
    /// untouched field.
    var purchasePrice: Decimal?
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

    /// Category paths already in use, for the picker's autocomplete. Fetched
    /// here rather than by the field so the view stays free of store access.
    private(set) var categorySuggestions: [String] = []

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

    func loadCategorySuggestions() {
        let helper = CategoryPathHelper(modelContext: modelContext)
        categorySuggestions = (try? helper.allCategoryPaths()) ?? []
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
        item.purchasePriceCents = Money.cents(from: purchasePrice ?? 0)
        item.purchaseDate = purchaseDate
        item.serialNumber = Self.nilIfBlank(serialNumber)
        item.purchaseLocation = Self.nilIfBlank(purchaseLocation)
        item.currentValueCents = currentValue.map(Money.cents(from:))
        item.desireToKeep = desireToKeep
        item.condition = condition
        item.conditionNotes = Self.nilIfBlank(conditionNotes)
        item.notes = Self.nilIfBlank(notes)
        // Dropped photos are deleted, not just unlinked — see
        // PhotoSelection.orphaned. Captured before the reassignment,
        // which is what replaces the old set.
        for orphan in PhotoSelection.orphaned(previous: item.photos ?? [], current: photos) {
            modelContext.delete(orphan)
        }
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

    // MARK: - Private

    private func validate() -> Set<ValidationError> {
        var errors: Set<ValidationError> = []
        if Self.trimmed(name).isEmpty { errors.insert(.nameMissing) }
        if Self.trimmed(categoryPath).isEmpty { errors.insert(.categoryMissing) }
        if let purchasePrice {
            if purchasePrice < 0 { errors.insert(.priceNegative) }
        } else {
            errors.insert(.priceMissing)
        }
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
        purchasePrice = Money.amount(fromCents: item.purchasePriceCents)
        purchaseDate = item.purchaseDate
        serialNumber = item.serialNumber ?? ""
        purchaseLocation = item.purchaseLocation ?? ""
        currentValue = item.currentValueCents.map(Money.amount(fromCents:))
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
