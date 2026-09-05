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
            item.updatedAt = now()
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

        marketNotice = MarketNotice.notice(for: outcome, lastFetchedAt: lastFetchedAt)
        loadMarket()
    }

    /// "Use as my value" (spec criterion 8, Q15): the median as the display
    /// formatter rounds it, written to the person's own value. No fetch, and
    /// no history point — the market's record of itself is untouched.
    @discardableResult
    func adopt() -> Bool {
        adoptFailureMessage = nil
        guard canAdopt,
              let item,
              case .matched(let display) = marketState,
              case .current(let figure) = display.reading,
              let medianCents = figure.medianCents else { return false }

        item.currentValueCents = MarketAdoption.wholeCurrencyCents(from: medianCents)
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
}
