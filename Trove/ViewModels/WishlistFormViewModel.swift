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
        /// 002 Amendment A (P18), as on the item form: something was typed in
        /// the year field that isn't four digits between 1900 and next year.
        /// Blank is not this — the field is optional.
        case yearInvalid
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
    /// Held as text rather than `Int?` for the reason the item form's does — a
    /// half-typed year is a state the field can be in. Parsed at save time
    /// into `WishlistItem.year`.
    var yearText: String = ""
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
    private let photoService: any StockPhotoService
    private let noticeStore: any PhotoNoticeStore

    var isEditing: Bool { editingItem != nil }

    /// The year field's upper bound, and the number the validation message
    /// names — read from the calendar each time, as on the item form.
    var maximumYear: Int { Calendar.current.component(.year, from: .now) + 1 }

    init(
        modelContext: ModelContext,
        editing item: WishlistItem? = nil,
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
        item.year = parsedYear
        item.notes = Self.nilIfBlank(notes)
        item.desireToOwn = desireToOwn
        // Assigning the whole set, not appending: SwiftData sets each photo's
        // `wishlistItem` inverse from this side, and anything the user removed
        // in the picker drops out of the relationship here.
        // Dropped photos are deleted, not just unlinked — see
        // PhotoSelection.orphaned. Captured before the reassignment,
        // which is what replaces the old set.
        for orphan in PhotoSelection.orphaned(previous: item.photos ?? [], current: photos) {
            modelContext.delete(orphan)
        }
        item.photos = photos

        if editingItem == nil {
            // New entries go to the end of the manual order — see
            // ManualOrderHelper.nextPosition for why the end is max + 1
            // rather than a count.
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

    // MARK: - Stock photo (005)

    /// Settable by the view: the photo sheet's `isPresented` binding writes
    /// false back on dismissal, exactly as the item form's does. Kept parallel
    /// with `ItemFormViewModel` — same names, same shapes.
    var isFindingPhoto = false

    /// Which phase the photo sheet is showing — the notice in front of the
    /// picker, or the picker itself (spec Decision 14). Decided when the sheet
    /// opens, not while it is open.
    private(set) var photoSheetStep: PhotoSheetStep = .pick

    /// Whether Find a photo… is offered: true until an owned (`.device`) photo
    /// exists, a stock-only set still qualifying so it can be replaced (spec
    /// Decision 6). Delegates to `PhotoSelection`, unit-tested at T005.
    var canFindPhoto: Bool { PhotoSelection.canFindPhoto(photos) }

    /// The picker's view model, seeded with the form's current **name** and
    /// nothing else — the whole of what a search may send (spec P1).
    func makePhotoFetchViewModel() -> PhotoFetchViewModel {
        PhotoFetchViewModel(seed: Self.trimmed(name), service: photoService)
    }

    /// Find a photo…: the notice stands in front the first time on this
    /// device, the picker directly after. The flag lives in `UserDefaults` via
    /// `PhotoNoticeStore`, shared across every stock-photo entry point.
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
    /// replaced fetched photo. `WishlistItem` has no `updatedAt`, so — unlike
    /// the owned detail's `store` — there is nothing to bump either.
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
        if let estimatedCost {
            if estimatedCost < 0 { errors.insert(.costNegative) }
        } else {
            errors.insert(.costMissing)
        }
        if !Self.trimmed(yearText).isEmpty, parsedYear == nil { errors.insert(.yearInvalid) }
        return errors
    }

    /// The typed year, or `nil` when the field is blank *or* unusable —
    /// `validate()` tells the two apart. Mirrors the item form exactly.
    private var parsedYear: Int? {
        let text = Self.trimmed(yearText)
        guard text.count == 4, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let value = Int(text),
              (FieldNormalization.earliestYear...maximumYear).contains(value) else { return nil }
        return value
    }

    private func nextSortOrder() -> Int {
        let existing = (try? modelContext.fetch(FetchDescriptor<WishlistItem>())) ?? []
        return ManualOrderHelper.nextPosition(after: existing)
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
        yearText = item.year.map(String.init) ?? ""
        notes = item.notes ?? ""
        photos = item.photos ?? []
        desireToOwn = item.desireToOwn
    }

    // Delegating to the shared definition since 012/T005 — see the note in
    // ItemFormViewModel and FieldNormalization itself.
    private static func trimmed(_ value: String) -> String {
        FieldNormalization.trimmed(value)
    }

    private static func nilIfBlank(_ value: String) -> String? {
        FieldNormalization.nilIfBlank(value)
    }
}
