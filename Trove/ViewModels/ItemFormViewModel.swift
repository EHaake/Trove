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
        /// 002 Amendment A (P18): something was typed in the year field that
        /// isn't four digits between 1900 and next year. Blank is not this —
        /// the field is optional, and blank means "any year".
        case yearInvalid
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
    /// Held as text, not `Int?`, so a half-typed "19" is a state the field can
    /// be in and be told about, rather than something the binding silently
    /// discards. Parsed at save time into `Item.year`.
    var yearText: String = ""
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
    private let photoService: any StockPhotoService
    private let noticeStore: any PhotoNoticeStore

    var isEditing: Bool { editingItem != nil }

    /// The year field's upper bound, and the number the validation message
    /// names. Read from the calendar each time rather than captured at init,
    /// so a form left open across midnight on 31 December isn't stale.
    var maximumYear: Int { Calendar.current.component(.year, from: .now) + 1 }

    init(
        modelContext: ModelContext,
        editing item: Item? = nil,
        photoService: (any StockPhotoService)? = nil,
        noticeStore: (any PhotoNoticeStore)? = nil
    ) {
        self.modelContext = modelContext
        self.editingItem = item
        self.photoService = photoService ?? WikimediaPhotoService()
        self.noticeStore = noticeStore ?? UserDefaultsPhotoNoticeStore()
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
        item.year = parsedYear
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
            // New items go to the end of the manual order, same as the
            // wishlist form — see ManualOrderHelper.nextPosition for why the
            // end is max + 1 rather than a count. Editing never touches the
            // position the user arranged.
            item.sortOrder = ManualOrderHelper.nextPosition(
                after: (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
            )
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

    // MARK: - Stock photo (005)

    /// Settable by the view: the photo sheet's `isPresented` binding writes
    /// false back on dismissal, exactly as `ItemDetailViewModel.isFindingPhoto`
    /// does for the detail screen's sheet.
    var isFindingPhoto = false

    /// Which phase the photo sheet is showing — the notice in front of the
    /// picker, or the picker itself (plan §6). Decided when the sheet
    /// opens, not while it is open.
    private(set) var photoSheetStep: PhotoSheetStep = .pick

    /// Whether Find a photo… is offered: true until an owned (`.device`) photo
    /// exists, a stock-only set still qualifying so it can be replaced (spec
    /// Decision 6). Delegates to `PhotoSelection`, unit-tested at T005.
    var canFindPhoto: Bool { PhotoSelection.canFindPhoto(photos) }

    /// The picker's view model, seeded with the form's current **name** and
    /// nothing else — the whole of what a search may send (spec P1) — mirroring
    /// how `ItemDetailViewModel.makePhotoFetchViewModel` seeds it.
    func makePhotoFetchViewModel() -> PhotoFetchViewModel {
        PhotoFetchViewModel(seed: Self.trimmed(name), service: photoService)
    }

    /// Find a photo…: the notice stands in front the first time on this
    /// device, the picker directly after. The flag lives in `UserDefaults` via
    /// `PhotoNoticeStore`, shared with the detail screen's sheet.
    func findPhoto() {
        photoSheetStep = noticeStore.hasAcknowledged ? .pick : .notice
        isFindingPhoto = true
    }

    /// Continue: the notice is done with on this device, and the picker takes
    /// over the sheet. `acknowledge()` persists itself, so there is no save or
    /// rollback around it.
    func continuePhotoNotice() {
        noticeStore.acknowledge()
        photoSheetStep = .pick
    }

    /// Not now, and the swipe-down the view treats as Not now: the sheet
    /// closes and the flag is left unacknowledged, so the notice comes back
    /// next time Find a photo… is tapped.
    func declinePhotoNotice() {
        photoSheetStep = .pick
        isFindingPhoto = false
    }

    /// The pick's landing on the form — the in-memory variant of the detail
    /// screen's `store`. The downloaded bytes become a `.fetched` photo, added
    /// through `PhotoSelection.addingFetched` so at most one stock photo is
    /// kept (spec P5) and it sits after the owned photos (Decision 4a). Nothing
    /// is persisted or inserted here: the form's own `save()` writes `photos`
    /// into the item and runs `PhotoSelection.orphaned(...)` to delete any
    /// replaced fetched photo — device photos ride into the store the same way.
    func store(_ download: StockPhotoDownload) {
        let photo = Photo.fetched(
            imageData: download.imageData,
            attribution: download.attribution,
            sortOrder: photos.count
        )
        photos = PhotoSelection.addingFetched(photo, to: photos)
        isFindingPhoto = false
        photoSheetStep = .pick
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
        if !Self.trimmed(yearText).isEmpty, parsedYear == nil { errors.insert(.yearInvalid) }
        return errors
    }

    /// The typed year, or `nil` when the field is blank *or* unusable. Which
    /// of the two it is, `validate()` decides — a blank field is the "any
    /// year" answer, anything else that fails to parse is an error.
    private var parsedYear: Int? {
        let text = Self.trimmed(yearText)
        guard text.count == 4, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let value = Int(text),
              (FieldNormalization.earliestYear...maximumYear).contains(value) else { return nil }
        return value
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
        yearText = item.year.map(String.init) ?? ""
        purchaseLocation = item.purchaseLocation ?? ""
        currentValue = item.currentValueCents.map(Money.amount(fromCents:))
        desireToKeep = item.desireToKeep
        condition = item.condition
        conditionNotes = item.conditionNotes ?? ""
        notes = item.notes ?? ""
        photos = item.photos ?? []
    }

    // Delegating to the shared definition since 012/T005: the import
    // pipeline normalizes cells with the same rules, and two copies of
    // "what blank means" is exactly the drift the one-definition move
    // prevents. See FieldNormalization.
    private static func trimmed(_ value: String) -> String {
        FieldNormalization.trimmed(value)
    }

    /// Optional-in-the-model fields are plain strings here so they can bind to
    /// text fields; blank means "not provided", not an empty value.
    private static func nilIfBlank(_ value: String) -> String? {
        FieldNormalization.nilIfBlank(value)
    }
}
