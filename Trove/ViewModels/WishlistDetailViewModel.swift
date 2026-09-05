import Foundation
import Observation
import SwiftData

/// A single wishlist item, for the plain detail screen.
///
/// Holds the item's `id` and re-fetches on `load()`, the same as
/// `ItemDetailViewModel` and for the same reason: once sync is on, an entry can
/// disappear out from under this screen because another device deleted it.
/// Looking it up by id surfaces that as `item == nil`, which the view can
/// handle, rather than as a stale reference.
///
/// **No ranking or Sell Plan logic lives here.** `plannedSaleItems` belongs to
/// `SellPlanViewModel`, one screen further in — plan.md is explicit that the
/// plan is reached by a deliberate tap rather than shown alongside the item, and
/// a detail model that quietly computed candidates would undo that by making
/// them available to render here.
@Observable
final class WishlistDetailViewModel {
    private(set) var item: WishlistItem?
    private(set) var deleteFailureMessage: String?

    /// Distinguishes "not loaded yet" from "loaded, and it's gone".
    private(set) var hasLoaded = false

    private let modelContext: ModelContext
    private let itemID: UUID
    private let marketService: any MarketService
    private let now: () -> Date

    init(
        modelContext: ModelContext,
        itemID: UUID,
        marketService: (any MarketService)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.itemID = itemID
        self.marketService = marketService ?? ReverbMarketService()
        self.now = now
    }

    func load() {
        let id = itemID
        var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        item = try? modelContext.fetch(descriptor).first
        hasLoaded = true
        loadMarket()
    }

    /// Deletes the loaded item.
    ///
    /// Its photos go with it, by the cascade rule on `WishlistItem.photos`.
    /// Whatever sits on its Sell Plan does **not** — that's `.nullify`, and the
    /// distinction is the whole reason the two rules differ: abandoning
    /// something you wanted must never delete gear you own.
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

    // MARK: - Display

    /// The item's photos in the user's own order.
    ///
    /// Sorted here rather than at the call site: the relationship comes back
    /// unordered from SwiftData, so this is a correctness rule rather than a
    /// layout choice, and CLAUDE.md keeps those out of views. `ItemDetailViewModel`
    /// exposes the same property for the same reason — the two are checked
    /// against each other in `ItemDetailViewModelTests`.
    var photos: [Photo] {
        PhotoSelection.inDisplayOrder(item?.photos ?? [])
    }

    /// The full category path, split for display. The detail screen shows every
    /// segment, unlike list rows, which show only the trailing two.
    var categorySegments: [String] {
        item?.categoryPath.split(separator: "/").map(String.init) ?? []
    }

    /// Clamped on the way out, so a value stored before the view model's range
    /// rule — or by a future import — still renders as a real level.
    var desireLevel: DesireToOwnLevel? {
        item.map { DesireToOwnLevel(clamping: $0.desireToOwn) }
    }

    /// Whether there's anything to show under a "Notes" heading, so the view
    /// can drop the heading too rather than leaving a label over blank space.
    var hasNotes: Bool {
        item?.notes?.isEmpty == false
    }

    // MARK: - Market (002)

    /// What the Market section shows, derived from the device's own rows on
    /// every `load()` — never from a fetch (spec criterion 9).
    private(set) var marketState: MarketSectionState = .unmatched
    private(set) var marketActivity: MarketActivity?
    private(set) var marketNotice: MarketNotice?

    /// Only "Use as estimated cost" reports its failure: it is the one
    /// market intent whose whole point is a number the person expects to see
    /// change. A match, a change of match and an unmatch re-derive from the
    /// store instead, so a refused save simply leaves the section as it was.
    private(set) var adoptFailureMessage: String?

    /// Whether the one-time notice stands in front of the picker this time
    /// (spec Decision 14). Decided when the sheet opens, not while it is
    /// open, so continuing can't reshuffle the sheet under the person.
    private(set) var noticeIsPending = false

    /// Settable by the view: the sheet's `isPresented` binding writes false
    /// back on dismissal, the way `SettingsViewModel.stagedExport` does.
    var isFindingMatch = false

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
        noticeIsPending = !MarketLocalStore.hasAcknowledgedNotice(in: modelContext)
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
        noticeIsPending = false
    }

    /// Not now: the sheet closes and the flag is left unacknowledged (Q5),
    /// so the notice comes back the next time Find on Reverb… is tapped.
    func declineNotice() {
        noticeIsPending = false
        isFindingMatch = false
    }

    /// The pick. A *different* product's figure and history describe
    /// something else, so they go first (spec Decision 26); re-picking the
    /// same product keeps them.
    ///
    /// One `save()` covers the item and the local rows — but the two live in
    /// different stores (plan §1), so atomicity is not claimed: a failure
    /// between them could leave the match written with the old figure still
    /// present, or the rows cleared with the old match still on the item.
    /// Either way the next `loadMarket()` shows what is actually stored, and
    /// a refresh re-derives the figure from the match.
    func setMatch(_ candidate: MarketCandidate) {
        guard let item else { return }
        do {
            if item.reverbProductID != candidate.id {
                try MarketLocalStore.clear(subjectID: item.id, in: modelContext)
            }
            item.reverbProductID = candidate.id
            // No `updatedAt` to bump, unlike the owned mirror: `WishlistItem`
            // has no such field (spec Decision 24).
            try MarketLocalStore.recordMatch(candidate, for: item.id, at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `SettingsViewModel.confirmDeleteAll` uses; `loadMarket()`
            // below then shows whatever is actually stored.
            modelContext.rollback()
        }
        marketNotice = nil
        isFindingMatch = false
        loadMarket()
    }

    /// One item's refresh. The refresher owns the hour budget, the writes
    /// and the save; this maps its outcome to the notice line and re-reads
    /// the section (spec P8: a failure leaves the last figure alone).
    func refresh() async {
        guard canRefresh, let item, let productID = item.reverbProductID else { return }
        marketActivity = .refreshing
        defer { marketActivity = nil }

        let target = MarketRefreshTarget(
            key: MarketSubjectKey(subjectID: item.id, kind: .wanted),
            productID: productID,
            subject: .wanted,
            year: item.year
        )
        // Only a `.current` reading shows a figure, and the unreachable
        // line dates the figure it is standing over (plan §6) — a stale or
        // withheld reading passes no date and reads "Couldn't reach Reverb."
        let lastFetchedAt = marketState.currentFigureFetchedAt
        let refresher = MarketRefresher(modelContext: modelContext, service: marketService, now: now)
        let outcome = await refresher.refresh(target)

        marketNotice = MarketNotice.notice(for: outcome, lastFetchedAt: lastFetchedAt)
        loadMarket()
    }

    /// "Use as estimated cost" (spec criterion 8, Q15): the median as the
    /// display formatter rounds it, written to what this is expected to
    /// cost. No fetch, and no history point — the market's record of itself
    /// is untouched.
    ///
    /// No `updatedAt` to bump, unlike the owned side: `WishlistItem` has no
    /// such field (spec Decision 24), which is why the two adopt intents
    /// differ by that one line and nothing else.
    @discardableResult
    func adopt() -> Bool {
        adoptFailureMessage = nil
        guard canAdopt,
              let item,
              case .matched(let display) = marketState,
              case .current(let figure) = display.reading,
              let medianCents = figure.medianCents else { return false }

        item.estimatedCostCents = MarketAdoption.wholeCurrencyCents(from: medianCents)
        // No `updatedAt` to bump, unlike the owned mirror: `WishlistItem`
        // has no such field (spec Decision 24).
        do {
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `SettingsViewModel.confirmDeleteAll` uses — so the expected
            // cost is left exactly as it was stored, and the message says so.
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
            // No `updatedAt` to bump, unlike the owned mirror: `WishlistItem`
            // has no such field (spec Decision 24).
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

}
