import Foundation
import Observation
import SwiftData

/// A single owned item, and deleting it.
///
/// Holds the item's `id` rather than the `Item` itself and re-fetches on
/// `load()`. Once sync is on, an item can disappear out from under this screen
/// because another device deleted it; looking it up by id means that surfaces
/// as `item == nil`, which the view can handle, instead of a stale reference.
@Observable
final class ItemDetailViewModel {
    private(set) var item: Item?
    private(set) var deleteFailureMessage: String?

    /// Distinguishes "not loaded yet" from "loaded, and it's gone".
    private(set) var hasLoaded = false

    private let modelContext: ModelContext
    private let itemID: UUID
    private let marketService: any MarketService
    private let photoService: any StockPhotoService
    private let noticeStore: any PhotoNoticeStore
    private let now: () -> Date

    init(
        modelContext: ModelContext,
        itemID: UUID,
        marketService: (any MarketService)? = nil,
        photoService: (any StockPhotoService)? = nil,
        noticeStore: (any PhotoNoticeStore)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.itemID = itemID
        self.marketService = marketService ?? ReverbMarketService()
        self.photoService = photoService ?? WikimediaPhotoService()
        self.noticeStore = noticeStore ?? UserDefaultsPhotoNoticeStore()
        self.now = now
    }

    func load() {
        let id = itemID
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        item = try? modelContext.fetch(descriptor).first
        hasLoaded = true
        loadMarket()
    }

    /// The item's photos in the user's own order.
    ///
    /// Sorted here rather than at the call site: the relationship comes back
    /// unordered from SwiftData, so this is a correctness rule rather than a
    /// layout choice, and CLAUDE.md keeps those out of views. `ItemDetailView`
    /// applied `PhotoSelection.inDisplayOrder` inline until
    /// `WishlistDetailViewModel` put the same rule in a view model — one job in
    /// two places, the shape of bug this build has hit more than once.
    var photos: [Photo] {
        PhotoSelection.inDisplayOrder(item?.photos ?? [])
    }

    /// Deletes the loaded item. Its photos go with it, by the cascade rule on
    /// `Item.photos`; any Sell Plan referencing it just drops the reference.
    @discardableResult
    func delete() -> Bool {
        deleteFailureMessage = nil
        guard let item else { return false }

        // 002: the device's market rows for this item go with it, in the
        // same save (plan §1, "who clears").
        modelContext.delete(item)
        do {
            try MarketLocalStore.clear(subjectID: item.id, in: modelContext)
            try modelContext.save()
            self.item = nil
            return true
        } catch {
            deleteFailureMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Market (002)

    /// What the Market section shows, derived from the device's own rows on
    /// every `load()` — never from a fetch (spec criterion 9).
    private(set) var marketState: MarketSectionState = .unmatched
    private(set) var marketActivity: MarketActivity?
    private(set) var marketNotice: MarketNotice?

    /// Only "Use as my value" reports its failure: it is the one market
    /// intent whose whole point is a number the person expects to see
    /// change. A match, a change of match and an unmatch re-derive from the
    /// store instead, so a refused save simply leaves the section as it was.
    private(set) var adoptFailureMessage: String?

    /// Which phase the match sheet is showing (spec Decisions 14, 33–34,
    /// plan Amendment B). Whether the notice stands in front of the picker
    /// is decided when the sheet opens, not while it is open, so continuing
    /// can't reshuffle the sheet under the person; the two phases after the
    /// pick are driven by `setMatch(_:)` and by `openValueStep()`.
    private(set) var sheetStep: MarketSheetStep = .pick

    /// Settable by the view: the sheet's `isPresented` binding writes false
    /// back on dismissal, the way `SettingsViewModel.stagedExport` does.
    var isFindingMatch = false

    /// **The generation rule** (plan Amendment B, T022's second review):
    /// every fetch this view model starts — a pick's and the section's own
    /// Refresh alike — takes the next value of this counter, and a landing
    /// may write the notice or clear the activity flag only while its token
    /// is still the current one. An older fetch landing after a newer one
    /// has begun re-derives the section and nothing else: it may neither
    /// paint a failure line over the match that replaced it nor re-enable
    /// Refresh and the adopt button while the newest fetch is still
    /// running. The newest fetch always lands, so the flag can't be left
    /// set by the rule.
    private var marketFetchGeneration = 0

    private func nextGeneration() -> Int {
        marketFetchGeneration += 1
        return marketFetchGeneration
    }

    /// Matched, idle, and nothing fetched here within the hour (spec P7,
    /// Q8) — the same window the refresher enforces, so a disabled button
    /// and a skipped fetch can't disagree.
    var canRefresh: Bool {
        guard case .matched = marketState, marketActivity == nil else { return false }
        guard let fetchedAt = marketState.lastFetchedAt else { return true }
        return now().timeIntervalSince(fetchedAt) >= MarketRefresher.freshnessWindow
    }

    /// A withheld or stale reading offers no figure to adopt (spec P6).
    var canAdopt: Bool {
        guard case .matched(let display) = marketState, marketActivity == nil else { return false }
        if case .current = display.reading { return true }
        return false
    }

    /// Find on Reverb… and Change match… — one intent, since the second is
    /// the first over an existing match.
    func findMatch() {
        sheetStep = MarketLocalStore.hasAcknowledgedNotice(in: modelContext) ? .pick : .notice
        isFindingMatch = true
    }

    /// Continue: the notice is done with on this device, and the picker
    /// takes over the sheet. A refused save only means it shows once more.
    func continueFromNotice() {
        do {
            try MarketLocalStore.acknowledgeNotice(at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `SettingsViewModel.confirmDeleteAll` uses. Here it costs no
            // more than the notice standing there once again.
            modelContext.rollback()
        }
        sheetStep = .pick
    }

    /// Not now: the sheet closes and the flag is left unacknowledged (Q5),
    /// so the notice comes back the next time Find on Reverb… is tapped.
    func declineNotice() {
        sheetStep = .pick
        isFindingMatch = false
    }

    /// The picker's view model, seeded with the item's **name** — the whole
    /// of what a search sends (spec criterion 3). Change match… seeds the
    /// same way, not from the matched product's title (Q10), so a bad match
    /// can't narrow the next search after itself.
    func makeMatchViewModel() -> MarketMatchViewModel {
        MarketMatchViewModel(seed: item?.name ?? "", service: marketService)
    }

    /// The pick, and the refresh it now runs (spec Decision 33, plan
    /// Amendment B). A *different* product's figure and history describe
    /// something else, so they go first (spec Decision 26); re-picking the
    /// same product keeps them.
    ///
    /// One `save()` covers the item and the local rows — but the two live in
    /// different stores (plan §1), so atomicity is not claimed: a failure
    /// between them could leave the match written with the old figure still
    /// present, or the rows cleared with the old match still on the item.
    /// Either way the next `loadMarket()` shows what is actually stored, and
    /// a refresh re-derives the figure from the match.
    ///
    /// Guarded so two quick taps on candidate cards produce one save and one
    /// request: a second pick while the first is fetching is dropped, and a
    /// pick can only come from the picker phase in the first place. The step
    /// alone is enough — everything up to `sheetStep = .fetching` runs
    /// synchronously on the MainActor — and it is deliberately *not* joined
    /// by `marketActivity == nil` (plan Amendment B), which would silently
    /// drop a pick made while the section's own Refresh is in flight; the
    /// refresher's supersede rule already drops the older fetch's result.
    func setMatch(_ candidate: MarketCandidate) async {
        guard let item, case .pick = sheetStep else { return }
        do {
            if item.reverbProductID != candidate.id {
                try MarketLocalStore.clear(subjectID: item.id, in: modelContext)
            }
            item.reverbProductID = candidate.id
            item.updatedAt = now()
            try MarketLocalStore.recordMatch(candidate, for: item.id, at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `SettingsViewModel.confirmDeleteAll` uses; `loadMarket()`
            // below then shows whatever is actually stored. Nothing is
            // fetched over a match that wasn't written (the T009 rule): the
            // sheet closes to the section as it did before Amendment B.
            // The notice is left exactly as it was: the match it describes
            // is still the item's, since this pick was never written (plan
            // Amendment B).
            modelContext.rollback()
            closeSheet()
            loadMarket()
            return
        }
        // The notice described the match this pick has just replaced, so it
        // goes with it (plan §6's deviation) — before the fetch, so the
        // section behind the sheet isn't standing under a dead failure line.
        marketNotice = nil
        // This fetch's place in line (the generation rule): the token names
        // the presentation as well as the landing, so the same product
        // picked again after a swipe-down is a second fetch and the first
        // has no claim on the second's sheet.
        let token = nextGeneration()
        sheetStep = .fetching(candidate, token: token)
        // `canRefresh` and `canAdopt` are false throughout, so a second
        // refresh can't start underneath the sheet.
        marketActivity = .refreshing

        let target = MarketRefreshTarget(
            key: MarketSubjectKey(subjectID: item.id, kind: .owned),
            productID: candidate.id,
            subject: .owned(condition: item.condition),
            year: item.year
        )
        let refresher = MarketRefresher(modelContext: modelContext, service: marketService, now: now)
        let outcome = await refresher.refresh(target)

        // Re-derived first, so the unreachable line dates itself by the
        // figure that is actually showing *after* the save — a changed
        // product's figure is cleared, and can never date this failure.
        loadMarket()
        // The generation rule: only the newest fetch speaks for the section.
        if token == marketFetchGeneration {
            marketActivity = nil
            marketNotice = MarketNotice.notice(for: outcome, lastFetchedAt: marketState.currentFigureFetchedAt)
        }

        // **The landing rule** (plan Amendment B), stated once: the outcome
        // may only move the sheet it is *this fetch's* presentation of —
        // `sheetStep` still `.fetching` carrying **this fetch's token**.
        // The token is what is compared, not the candidate: candidate
        // equality is not fetch identity, and the same product picked again
        // after a swipe-down is a second fetch whose sheet the first may
        // not move. The step is named as well as the flag because a bare
        // `isFindingMatch` cannot tell this presentation from a picker the
        // person re-opened after swiping this fetch away, and that picker
        // is theirs: an outcome must neither replace it with a value step
        // for a fetch they walked away from nor close it under them.
        //
        // Within this fetch's own sheet: a figure in hand and the sheet
        // still up is the value step; anything else — a withheld reading, a
        // failure, or a person who swiped the fetching sheet away — closes
        // to the section, which says what it says today. An outcome landing
        // after the dismissal never re-presents the sheet.
        if case .fetching(_, let inFlight) = sheetStep, inFlight == token {
            if isFindingMatch, let figure = currentFigure {
                sheetStep = .value(MarketValueStep(figure: figure))
            } else {
                closeSheet()
            }
        }
    }

    /// The section's adopt action from T024 on (spec Decision 34): the same
    /// value step, opened over a figure already in hand. A no-op when there
    /// is no current reading or a refresh is running — `canAdopt` gates the
    /// button, and this repeats the gate rather than trusting it.
    func openValueStep() {
        guard canAdopt, let figure = currentFigure else { return }
        sheetStep = .value(MarketValueStep(figure: figure))
        isFindingMatch = true
    }

    /// The slider's write, forwarded to the step the sheet is holding, so
    /// the view binds to this view model rather than to a copy of the step.
    /// Whole currency and the bounds are `MarketValueStep`'s own invariant.
    func setChosen(_ cents: Int) {
        guard case .value(var step) = sheetStep else { return }
        step.setChosen(cents)
        sheetStep = .value(step)
    }

    /// Not now, and the swipe-down: the sheet closes and nothing is written.
    func dismissValueStep() {
        closeSheet()
    }

    /// The figure the section is showing, when it is showing one — the one
    /// reading a value step may be built over (plan Amendment B, B4).
    private var currentFigure: MarketSnapshotValue? {
        guard case .matched(let display) = marketState, case .current(let figure) = display.reading else { return nil }
        return figure
    }

    private func closeSheet() {
        isFindingMatch = false
        sheetStep = .pick
    }

    /// One item's refresh. The refresher owns the hour budget, the writes
    /// and the save; this maps its outcome to the notice line and re-reads
    /// the section (spec P8: a failure leaves the last figure alone).
    func refresh() async {
        guard canRefresh, let item, let productID = item.reverbProductID else { return }
        // This refresh's place in line (the generation rule, plan Amendment
        // B): what it may write when it lands turns on whether a pick has
        // started a newer fetch in the meantime.
        let token = nextGeneration()
        marketActivity = .refreshing

        let target = MarketRefreshTarget(
            key: MarketSubjectKey(subjectID: item.id, kind: .owned),
            productID: productID,
            subject: .owned(condition: item.condition),
            year: item.year
        )
        // Only a `.current` reading shows a figure, and the unreachable
        // line dates the figure it is standing over (plan §6) — a stale or
        // withheld reading passes no date and reads "Couldn't reach Reverb."
        let lastFetchedAt = marketState.currentFigureFetchedAt
        let refresher = MarketRefresher(modelContext: modelContext, service: marketService, now: now)
        let outcome = await refresher.refresh(target)

        // The generation rule: an older refresh landing after a pick's
        // fetch has begun re-derives the section and nothing else.
        if token == marketFetchGeneration {
            marketActivity = nil
            marketNotice = MarketNotice.notice(for: outcome, lastFetchedAt: lastFetchedAt)
        }
        loadMarket()
    }

    /// The value step's one filled button (spec criterion 8, Decisions
    /// 34–35): the amount the person chose on the slider, written to their
    /// own value. No fetch, and no history point — the market's record of
    /// itself is the median whatever is adopted, so trending is untouched.
    ///
    /// The amount arrives whole: `MarketValueStep` rounds its default and
    /// every move through `MarketAdoption`. It is routed through the same
    /// rounding again here so the invariant holds for any caller, not only
    /// for the one path that happens to hold a step.
    @discardableResult
    func adopt(cents: Int) -> Bool {
        adoptFailureMessage = nil
        // The sheet closes on every path out of here (plan Amendment B):
        // the write, a refused save — the section then carries the message
        // over the value left as it was — and a gate that refuses the write
        // altogether, since a value step standing over a reading that has
        // gone stale or withheld under it has nothing left to offer.
        defer { closeSheet() }
        guard canAdopt, let item else { return false }

        item.currentValueCents = MarketAdoption.wholeCurrencyCents(from: cents)
        item.updatedAt = now()
        do {
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `SettingsViewModel.confirmDeleteAll` uses — so the person's
            // value is left exactly as it was stored, and the message says so.
            modelContext.rollback()
            adoptFailureMessage = error.localizedDescription
            return false
        }
        return true
    }

    /// Remove match: the match and everything the device knows about it go
    /// together — spec criterion 16, "unmatching clears the item's history
    /// and figure" — in one save, with the same two-store caveat `setMatch`
    /// describes. A single tap, no confirmation: re-matching costs one more.
    func removeMatch() {
        guard let item else { return }
        do {
            item.reverbProductID = nil
            item.updatedAt = now()
            try MarketLocalStore.clear(subjectID: item.id, in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `SettingsViewModel.confirmDeleteAll` uses; `loadMarket()`
            // then re-derives from the store, so the match survives.
            modelContext.rollback()
        }
        marketNotice = nil
        loadMarket()
    }

    private func loadMarket() {
        marketState = MarketSectionState.resolve(subjectID: itemID, productID: item?.reverbProductID, in: modelContext, now: now())
    }

    // MARK: - Stock photo (005)

    /// Settable by the view: the photo sheet's `isPresented` binding writes
    /// false back on dismissal, exactly as `isFindingMatch` does for the
    /// market sheet. A separate flag so the two sheets never fight over one.
    var isFindingPhoto = false

    /// Which phase the photo sheet is showing — the notice in front of the
    /// picker, or the picker itself (spec Decision 14). Decided when the sheet
    /// opens, not while it is open.
    private(set) var photoSheetStep: PhotoSheetStep = .pick

    /// Whether Find a photo… is offered: true until an owned (`.device`) photo
    /// exists, a stock-only set still qualifying so it can be replaced (spec
    /// Decision 6). Delegates to `PhotoSelection`, unit-tested at T005.
    var canFindPhoto: Bool { PhotoSelection.canFindPhoto(photos) }

    /// The picker's view model, seeded with the item's **name** and nothing
    /// else — the whole of what a search may send (spec P1) — mirroring how
    /// `makeMatchViewModel` seeds the market picker.
    func makePhotoFetchViewModel() -> PhotoFetchViewModel {
        PhotoFetchViewModel(seed: item?.name ?? "", service: photoService)
    }

    /// Find a photo…: the notice stands in front the first time on this
    /// device, the picker directly after. Unlike the market notice, the flag
    /// lives in `UserDefaults` via `PhotoNoticeStore`, not the model context.
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

    /// The pick's landing: the downloaded bytes become a `.fetched` photo,
    /// added through `PhotoSelection.addingFetched` so at most one stock photo
    /// is kept (spec P5) and it sits after the owned photos (Decision 4a). Any
    /// replaced stock photo is an orphan — dropped from the set but still in
    /// the store holding its external-storage blob — so it is deleted in the
    /// same save, the leaked-blob invariant `PhotoSelection.orphaned`
    /// documents. A refused save rolls back and stores nothing (spec P8).
    @discardableResult
    func store(_ download: StockPhotoDownload) -> Bool {
        guard let item else { return false }
        let existing = item.photos ?? []
        let photo = Photo.fetched(
            imageData: download.imageData,
            attribution: download.attribution,
            sortOrder: existing.count
        )
        let updated = PhotoSelection.addingFetched(photo, to: existing)
        let orphans = PhotoSelection.orphaned(previous: existing, current: updated)
        modelContext.insert(photo)
        item.photos = updated
        for orphan in orphans { modelContext.delete(orphan) }
        // OWNED ONLY: a new photo is an edit to the item (spec P6). The
        // wishlist mirror omits this line — `WishlistItem` has no `updatedAt`
        // (spec Decision 24), the one divergence between the two `store`s.
        item.updatedAt = now()
        do {
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared context
            // — the same recovery the market intents use — so a refused save
            // leaves the item's photos exactly as they were.
            modelContext.rollback()
            load()
            return false
        }
        closePhotoSheet()
        load()
        return true
    }

    private func closePhotoSheet() {
        isFindingPhoto = false
        photoSheetStep = .pick
    }
}
