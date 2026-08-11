import Foundation
import Observation
import SwiftData

/// Backs the shared add/edit wishlist form, per
/// `design/screens/Trove Wishlist Form.png`: name, category, estimated cost,
/// notes.
///
/// Deliberately parallel to `ItemFormViewModel` — same `Decimal`-to-cents
/// boundary through `Money`, same canonicalize-on-save, same blank-versus-zero
/// rule — because the two forms sit one tab apart and behaving differently
/// would read as one of them being broken.
@Observable
final class WishlistFormViewModel {
    enum ValidationError: Hashable {
        case nameMissing
        case categoryMissing
        /// Left blank, as opposed to a deliberate zero. Same distinction the
        /// item form draws for purchase price: an estimate of nothing is a
        /// real answer for something you expect to be given, an untouched
        /// field is not.
        case costMissing
        case costNegative
    }

    /// Design's row of quick-pick amounts under the cost field. Fixed rather
    /// than derived from the user's history: the point is to fill the field in
    /// one tap while the price is still a guess, and a shifting set of
    /// suggestions would be harder to hit than a stable one.
    static let costPresets: [Decimal] = [250, 500, 1_000, 2_500]

    static let desireToOwnRange = 1...3

    var name: String = ""
    var categoryPath: String = ""
    var estimatedCost: Decimal?
    var notes: String = ""

    /// Same `PhotoPickerField` binding the item form uses. A wanted item's
    /// photo is usually a listing shot or a reference image rather than a
    /// picture of something owned, which changes nothing about how it's stored.
    var photos: [Photo] = []

    private var storedDesireToOwn = 2

    /// Clamped on assignment rather than at save time, the same as the item
    /// form's `desireToKeep`: the invariant then holds for anything reading it
    /// mid-edit, and a control bound straight to this can't drive it out of
    /// range.
    var desireToOwn: Int {
        get { storedDesireToOwn }
        set {
            storedDesireToOwn = min(
                max(newValue, Self.desireToOwnRange.lowerBound),
                Self.desireToOwnRange.upperBound
            )
        }
    }

    private(set) var validationErrors: Set<ValidationError> = []
    private(set) var saveFailureMessage: String?
    private(set) var categorySuggestions: [String] = []

    private let modelContext: ModelContext
    private let editingItem: WishlistItem?

    var isEditing: Bool { editingItem != nil }

    init(modelContext: ModelContext, editing item: WishlistItem? = nil) {
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

    /// Whether a preset should read as chosen. Compares the amount rather than
    /// tracking which chip was tapped, so typing 500 by hand lights the $500
    /// chip too — the chip reflects the value, it doesn't own it.
    func isSelected(preset: Decimal) -> Bool {
        estimatedCost == preset
    }

    @discardableResult
    func save() -> Bool {
        saveFailureMessage = nil
        validationErrors = validate()
        guard validationErrors.isEmpty else { return false }

        let item = editingItem ?? WishlistItem()
        item.name = Self.trimmed(name)
        item.categoryPath = canonicalCategoryPath()
        item.estimatedCostCents = Money.cents(from: estimatedCost ?? 0)
        item.notes = Self.nilIfBlank(notes)
        item.desireToOwn = desireToOwn
        // Assigning the whole set, not appending: SwiftData sets each photo's
        // `wishlistItem` inverse from this side, and anything the user removed
        // in the picker drops out of the relationship here.
        item.photos = photos

        if editingItem == nil {
            // New entries go to the end of the manual order. Fetching the max
            // rather than counting, so a gap left by a deletion can't put two
            // items on the same rung.
            item.sortOrder = nextSortOrder()
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
        if let estimatedCost {
            if estimatedCost < 0 { errors.insert(.costNegative) }
        } else {
            errors.insert(.costMissing)
        }
        return errors
    }

    private func nextSortOrder() -> Int {
        let existing = (try? modelContext.fetch(FetchDescriptor<WishlistItem>())) ?? []
        return (existing.map(\.sortOrder).max() ?? -1) + 1
    }

    private func canonicalCategoryPath() -> String {
        let typed = Self.trimmed(categoryPath)
        let helper = CategoryPathHelper(modelContext: modelContext)
        return (try? helper.canonicalize(typed)) ?? typed
    }

    private func populate(from item: WishlistItem) {
        name = item.name
        categoryPath = item.categoryPath
        estimatedCost = Money.amount(fromCents: item.estimatedCostCents)
        notes = item.notes ?? ""
        photos = item.photos ?? []
        desireToOwn = item.desireToOwn
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nilIfBlank(_ value: String) -> String? {
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
