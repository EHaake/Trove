import Foundation
import Observation
import SwiftData

/// Browse, filter, search and sort owned items.
///
/// `categoryFilter`, `searchText` and `sortOrder` are settable properties the
/// view binds controls straight to; nothing recomputes until `load()` is
/// called.
/// That keeps the reload point explicit and the type trivially testable,
/// rather than hiding fetches inside property observers.
///
/// Since 006 it owns both halves of the Items tab: one fetch per `load()`,
/// split into the owned rows every existing member derives from and the sold
/// rows the Sold side shows (006 plan §4). `show(_:)` is still the only way
/// the side changes, but since 014 it clears nothing: each side keeps its own
/// narrowing and its own sort while the other is on screen (014 Decision 4,
/// replacing 006 Q15's clearing rule). The three narrowing properties are
/// computed over the side on screen's `Narrowing`, so nothing outside can
/// read or write the hidden side's — "what the controls show is always the
/// side on screen" is true by construction rather than by discipline.
@Observable
final class ItemListViewModel {
    /// Most orders have one sensible direction — keepers and most recent
    /// lead, full stop — but Value carries both, as a labeled pair rather
    /// than a toggle: a direction switch hidden behind re-selecting the
    /// active option is exactly the kind of control that gets lost.
    /// (The pair reverses this enum's original "one direction each" rule —
    /// requested by the person steering the project during Phase 6 review;
    /// `tasks.md`'s T033a records it.)
    ///
    /// "Custom" leads the menu the way the wishlist's manual option does —
    /// same convention on both lists (010) — but the *default* stays Date:
    /// unlike the wishlist, whose manual order has been its single ordering
    /// since 001, an item collection's most recent purchase leading is the
    /// shipped behavior this spec doesn't change.
    enum SortOrder: String, CaseIterable, Identifiable {
        case custom
        case purchaseDate
        case currentValue
        case currentValueAscending
        case marketFigure
        case marketFigureAscending
        case desireToKeep

        var id: String { rawValue }

        /// What the sort control calls this. Here rather than in the view so
        /// the list and any future control can't disagree.
        var label: String {
            switch self {
            case .custom: "Custom"
            case .purchaseDate: "Date"
            case .currentValue: "Value ↓"
            case .currentValueAscending: "Value ↑"
            // The Market pair sits straight after the Value pair, same
            // order (002 Q11), and reads its labels from `MarketCopy` —
            // "Market", never "value", is what the figure is called.
            case .marketFigure: MarketCopy.sortDescending
            case .marketFigureAscending: MarketCopy.sortAscending
            case .desireToKeep: "Desire"
            }
        }
    }

    /// What the Sold side's Sort By offers (014, plan Q4). Eight cases in
    /// menu order, and no Custom, Market or Desire: a sold item has no
    /// manual order, its market figures are cleared on the device (006
    /// Decision 7), and its desire rating no longer applies.
    ///
    /// The arrow convention is the Owned side's — `↓` is largest first, as
    /// `Value ↓` already reads — which is what carries the spec's one fixed
    /// rule for the Gain pair: `Gain ↓` puts the largest gain first and the
    /// largest loss last, and `Gain ↑` the reverse, told by the glyph and
    /// never by colour. "Name" rather than the wishlist's "Alphabetical",
    /// for the badge's width and because it is the spec's word.
    enum SoldSortOrder: String, CaseIterable, Identifiable {
        case soldDate
        case salePriceDescending
        case salePriceAscending
        case paidDescending
        case paidAscending
        case gainDescending
        case gainAscending
        case name

        var id: String { rawValue }

        /// What the sort control calls this — here rather than in the view,
        /// the same rule as `SortOrder.label`.
        var label: String {
            switch self {
            case .soldDate: "Date sold"
            case .salePriceDescending: "Price ↓"
            case .salePriceAscending: "Price ↑"
            case .paidDescending: "Paid ↓"
            case .paidAscending: "Paid ↑"
            case .gainDescending: "Gain ↓"
            case .gainAscending: "Gain ↑"
            case .name: "Name"
            }
        }
    }

    /// Which half of the Items tab is on screen (006, plan Q4). Plain
    /// `@Observable` state with no store behind it, so the tab opens on Owned
    /// at every launch by construction and keeps its side across tab switches
    /// within one.
    enum Side: Hashable {
        case owned
        case sold
    }

    /// Read-only from outside: `show(_:)` is the only way it changes, because
    /// changing side also reloads the rows under that side's own narrowing,
    /// and a plain setter would let a binding skip that.
    private(set) var side: Side = .owned

    /// One side's narrowing, kept while the other side is on screen (014
    /// Decision 4, replacing 006 Q15's clearing). Plain state, never stored:
    /// both sides start clean at every launch (014 P8).
    struct Narrowing: Equatable {
        var categoryFilter = ""
        var searchText = ""
        /// Owned only — the Sold copy never holds `true` (014 plan Q2).
        var showsOnlyUnvalued = false
    }

    private var ownedNarrowing = Narrowing()
    private var soldNarrowing = Narrowing()

    /// The side on screen's narrowing: what the controls show, and what a file
    /// exported from here follows (014 P11). Private, so the hidden side's
    /// copy is unreachable from outside this type.
    private var narrowing: Narrowing {
        get { side == .owned ? ownedNarrowing : soldNarrowing }
        set {
            if side == .owned {
                ownedNarrowing = newValue
            } else {
                soldNarrowing = newValue
            }
        }
    }

    var categoryFilter: String {
        get { narrowing.categoryFilter }
        set { narrowing.categoryFilter = newValue }
    }

    /// Free text over name and serial number. Narrows the same set the
    /// category filter narrows rather than replacing it — spec.md is explicit
    /// that the two combine, so a category chip stays in force while typing.
    var searchText: String {
        get { narrowing.searchText }
        set { narrowing.searchText = newValue }
    }

    /// Narrows to items with no value entered — the destination of the
    /// dashboard's "Value →" callout.
    ///
    /// Combines with the category filter and search the same way they combine
    /// with each other: every active narrowing applies to the same set. Set
    /// from outside via `AppRouter`, and the only filter with no control of its
    /// own in the header, so the chip row grows a dismissible chip while it's on
    /// — a filter the user can't see or clear is worse than one they can't set.
    ///
    /// Owned-only *structurally* since 014 (plan Q2): a write while the Sold
    /// side is on screen is refused rather than trapped, so the Sold copy can
    /// never hold `true`, the shared chip row never renders the chip there, and
    /// `narrowed(_:by:)` needs no side check. A sold item's current value is no
    /// longer something the app has an opinion about (006, `SoldItemRow`), so
    /// "un-valued" is not a way to narrow that side — and no legitimate writer
    /// exists on it: the chip renders only while the filter is on, and the
    /// router's `.unvalued` request crosses to Owned first. A refusal, not a
    /// trap, for exactly that reason.
    var showsOnlyUnvalued: Bool {
        get { narrowing.showsOnlyUnvalued }
        set {
            guard side == .owned else { return }
            ownedNarrowing.showsOnlyUnvalued = newValue
        }
    }

    var sortOrder: SortOrder = .purchaseDate

    /// The Sold side's own sort selection, separate from `sortOrder` the way
    /// each side keeps its own narrowing (014, plan Q4). Defaults to the
    /// order the side has had since `006`: most recent sale first.
    var soldSortOrder: SoldSortOrder = .soldDate

    private(set) var items: [Item] = []
    private(set) var loadFailureMessage: String?

    /// This device's market figures for the items on screen, rebuilt on
    /// every `load()` from one fetch of the figure rows (plan §5) — never
    /// the history. What the rows' arrows and the Market sort read, and the
    /// only place either of them gets a figure, so the two can't disagree.
    private(set) var marketSummaries: [UUID: MarketSummary] = [:]

    /// The last fetch's two halves, unnarrowed (006 plan §4). Held so the
    /// chips, the counts and the exports read one split rather than deriving a
    /// second one that has to agree with it.
    private var owned: [Item] = []
    private var sold: [Item] = []

    /// Every category path in use on the side on screen, for the filter chips.
    /// Includes paths whose items the current filter or search excludes —
    /// otherwise choosing one filter would hide the means of choosing another,
    /// and typing a query would dissolve the chip row underneath the field.
    ///
    /// Two stored pairs behind one name since 014 (plan Q5) — Owned's from the
    /// owned half as before, Sold's from the sold half — so the Sold side never
    /// offers a category nothing sold sits in, and `categoryChips` and
    /// `exportCoverageLabel` change no spelling.
    var categoryOptions: [String] { side == .owned ? ownedCategoryOptions : soldCategoryOptions }

    /// Short chip labels keyed by path — leaf-only where unambiguous. Computed
    /// once per load rather than per render, per side.
    var categoryLabels: [String: String] { side == .owned ? ownedCategoryLabels : soldCategoryLabels }

    private var ownedCategoryOptions: [String] = []
    private var ownedCategoryLabels: [String: String] = [:]
    private var soldCategoryOptions: [String] = []
    private var soldCategoryLabels: [String: String] = [:]

    /// Owned items before any narrowing. Held so an empty list can tell an
    /// empty collection apart from a filter that excluded everything — the two
    /// need opposite invitations.
    private(set) var totalCount = 0

    /// Sold items before any narrowing — the Sold side's `totalCount` (014 plan
    /// Q6). Never `soldItems.count`: that is the *narrowed* sold half now, and
    /// the two readers of this count — the controls gate and the Owned side's
    /// Everything-sold guard — must not move because a query was left on the
    /// other side.
    private(set) var soldTotalCount = 0

    /// "Controls need a list to narrow" — one gate, both sides (014 plan Q6),
    /// so the search field, the chips and Sort By appear on the Sold side under
    /// the same rule the Owned side has used since 001.
    var offersNarrowingControls: Bool { side == .owned ? totalCount > 0 : soldTotalCount > 0 }

    /// What the sort badge shows for the side on screen — each side carries its
    /// own selection (014 plan Q4), and the badge reads whichever is visible.
    var visibleSortLabel: String { side == .owned ? sortOrder.label : soldSortOrder.label }

    /// The Sold side's rows: the sold half under the Sold side's *own*
    /// narrowing (014 plan Q1), in the order its own Sort By selects (014 plan
    /// §2). Since 014 this can be narrower than every sale — `soldTotalCount`
    /// is the count before narrowing.
    private(set) var soldItems: [Item] = []

    /// Count, proceeds and realised gain over `soldItems`, summed by
    /// `SaleOutcome.totals` rather than here — the Dashboard card reads the
    /// same function, which is what makes "the summary matches the card" one
    /// sum instead of two that agree (006 plan §4).
    ///
    /// Over the *narrowed* rows since 014 (P4): the summary line follows what
    /// is on screen, the way the Owned side's header total does. The
    /// Dashboard's Sold card keeps showing the whole side, through its own
    /// load.
    private(set) var soldTotals = SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0)

    /// The line above the Sold rows — "3 sold · $2,400 · +$350 vs paid", and
    /// "0 sold · $0" when nothing has been sold, or when the Sold side's
    /// narrowing matches nothing (006 Decision 13, replacing Decision 11's
    /// hide-at-zero; 014 P4 for the narrowed reading).
    ///
    /// Non-optional on purpose: the header renders this in the same slot the
    /// Owned side's item stats occupy, and the reason Decision 13 exists is
    /// that an absent line let the `SideSwitch` above it jump as the sides
    /// changed. A `String?` here would put that jump one `if let` away; the
    /// type is what rules it out. The zero wording itself lives in
    /// `SaleCopy`, not here.
    var soldSummaryLine: String {
        SaleCopy.soldSideSummary(soldTotals)
    }

    var isEmpty: Bool { items.isEmpty }

    /// Which empty state applies, or `nil` when there's something to show.
    ///
    /// Both sides go through `ListEmptyReason.reason` since 014 (plan Q7): the
    /// Sold side carries a narrowing of its own now, so it needs the same
    /// precedence the Owned side has always had — a Sold side narrowed to
    /// nothing says so rather than claiming nothing was ever sold (P5).
    var emptyReason: ListEmptyReason? {
        switch side {
        case .owned:
            ownedEmptyReason
        case .sold:
            soldEmptyReason
        }
    }

    /// The Owned side's reason, with spec Decision 12 layered on top of the
    /// shared rule rather than inside it.
    ///
    /// `reason(...)` decides everything first — which is what keeps
    /// `stillSyncing` winning while the collection may still be arriving, and
    /// what leaves a narrowed-to-nothing side with its filter copy. Only the
    /// `.nothingAdded` it hands back is reconsidered here, and only when
    /// something has been sold: an Owned side emptied by selling is not a
    /// first launch, so it says so (plan §4, "The emptied Owned side").
    private var ownedEmptyReason: ListEmptyReason? {
        let reason = ListEmptyReason.reason(
            totalCount: totalCount,
            visibleCount: items.count,
            // The Owned narrowing by name, not the computed properties: this
            // is the Owned side's reason whichever side is on screen.
            searchText: ownedNarrowing.searchText,
            categoryFilter: ownedNarrowing.categoryFilter,
            showsOnlyUnvalued: ownedNarrowing.showsOnlyUnvalued,
            mayStillBeImporting: syncMonitor.mayStillBeImporting
        )
        // `soldTotalCount`, never `!soldItems.isEmpty` (014 plan §1):
        // `soldItems` is the narrowed sold half now, so a no-match query left
        // on the Sold side would otherwise turn an emptied Owned side back into
        // a first launch — the hidden side leaking into the visible one that
        // Decision 4 forbids and 006 Decision 12 answered.
        guard reason == .nothingAdded, soldTotalCount > 0 else { return reason }
        return .everythingSold
    }

    /// The Sold side's reason, through the shared rule with the Sold
    /// narrowing's own fields (014 plan Q7).
    ///
    /// `.nothingAdded` is mapped to `.nothingSold` afterwards — the exact shape
    /// `ownedEmptyReason` uses for `.everythingSold`, so `reason(...)`'s
    /// precedence is untouched: `stillSyncing` still wins over an empty side
    /// and still yields to a typed query (P5). `showsOnlyUnvalued` is `false`
    /// by construction here (Q2), so it is passed as the literal rather than
    /// read.
    private var soldEmptyReason: ListEmptyReason? {
        let reason = ListEmptyReason.reason(
            totalCount: soldTotalCount,
            visibleCount: soldItems.count,
            searchText: soldNarrowing.searchText,
            categoryFilter: soldNarrowing.categoryFilter,
            showsOnlyUnvalued: false,
            mayStillBeImporting: syncMonitor.mayStillBeImporting
        )
        return reason == .nothingAdded ? .nothingSold : reason
    }

    /// Combined current value of the items on screen, so the header total
    /// tracks the filter. Un-valued items contribute nothing rather than
    /// counting as zero — the same floor-not-total rule as the dashboard.
    var totalCurrentValueCents: Int { Self.figures(over: items).currentValueCents }

    /// How many of the items on screen have no value entered, so the header
    /// can be honest that the total above is a floor.
    var unvaluedCount: Int { Self.figures(over: items).unvaluedCount }

    /// The three owned-side figures over one set of rows. The header reads
    /// them over `items`; the PDF's cover reads them over
    /// `exportableOwnedItems`, which from the Sold side is a different set
    /// (014 plan §4). One home for the arithmetic, so a cover can't total
    /// its rows by a rule the header doesn't use.
    private static func figures(over items: [Item]) -> Figures {
        Figures(
            currentValueCents: items.compactMap(\.currentValueCents).reduce(0, +),
            paidCents: items.reduce(0) { $0 + $1.purchasePriceCents },
            unvaluedCount: items.count { $0.currentValueCents == nil }
        )
    }

    /// What `figures(over:)` hands back: the header's two totals and the
    /// cover's three, named rather than a tuple so a caller can't swap two
    /// `Int`s silently.
    private struct Figures {
        var currentValueCents: Int
        var paidCents: Int
        var unvaluedCount: Int
    }

    private let modelContext: ModelContext

    private let syncMonitor: SyncMonitor

    private let exportService: any ExportService

    private let importService: any ImportService

    private let now: () -> Date

    /// - Parameters:
    ///   - syncMonitor: defaults to a store with no mirror, so tests and
    ///     previews get the settled behaviour unless they ask otherwise.
    ///   - exportService: defaults to the live file-staging service over this
    ///     context's container; tests inject a fake and assert on what the
    ///     intents hand over (plan.md's Architecture section).
    ///   - importService: same injection rule, 012's side of the boundary.
    ///   - now: the clock the market figures' freshness is measured
    ///     against (002/T012), injected so a test can age a figure past the
    ///     thirty-day window without waiting a month.
    init(
        modelContext: ModelContext,
        syncMonitor: SyncMonitor = .notSyncing,
        exportService: (any ExportService)? = nil,
        importService: (any ImportService)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
        self.exportService = exportService ?? FileExportService(container: modelContext.container)
        self.importService = importService ?? FileImportService()
        self.now = now
    }

    /// Dragging only makes sense against the real, whole list in its own
    /// order — same rule as `WishlistViewModel.canReorder`, with this
    /// screen's third narrowing included: the un-valued filter hides rows
    /// exactly the way a category or query does, so it blocks reordering
    /// for the same reason.
    var canReorder: Bool {
        side == .owned
            && sortOrder == .custom
            && categoryFilter.isEmpty
            && SearchMatching.normalized(searchText).isEmpty
            && !showsOnlyUnvalued
    }

    /// Whether this device might still be receiving the collection. Read by
    /// the empty states, and by the note appended to the ones that survive
    /// mid-import.
    var mayStillBeImporting: Bool { syncMonitor.mayStillBeImporting }

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }

    /// The one way the side changes: it sets `side` and reloads. That is all
    /// — it clears nothing (014 Decision 4, replacing 006 Q15).
    ///
    /// Each side keeps its own search, chip and sort while the other is
    /// visited, in both directions, so coming back finds the side exactly as it
    /// was left; the controls always show the side on screen's, because the
    /// three narrowing properties are computed over it. Asking for the side
    /// already on screen is the same call: it reloads and leaves the narrowing
    /// alone, which is what lets the router's `.category`/`.unvalued` requests
    /// cross to Owned first and then write the narrowing they came to set.
    ///
    /// The visible query changes value on a side change, so a
    /// `.onChange(of: viewModel.searchText)` in the view fires once here —
    /// one extra `load()`, not a defect.
    func show(_ side: Side) {
        self.side = side
        load()
    }

    func load() {
        loadFailureMessage = nil
        do {
            // One fetch, split once (plan §4): every Owned-side figure below
            // derives from `owned`, so a sold item can't reach `items`,
            // `totalCount`, the chips, the header totals or the market
            // summaries by being missed at one of six call sites.
            let all = try modelContext.fetch(FetchDescriptor<Item>())
            owned = all.filter { !$0.isSold }
            sold = all.filter(\.isSold)

            totalCount = owned.count
            soldTotalCount = sold.count
            // Before the sort, not after: the Market orders read these.
            marketSummaries = Self.summaries(for: owned, in: modelContext, now: now())
            // Each side under its own narrowing, passed explicitly so no call
            // can read the other side's (014 plan Q1).
            items = narrowed(owned, by: ownedNarrowing).sorted(by: isOrderedBefore)
            // Built from the unfiltered fetch, so the chips stay put as the
            // filter changes — and each pair from its own half, so neither row
            // offers categories that only wishlist entries sit in, ones nothing
            // owned is left in, or ones nothing was sold from.
            ownedCategoryOptions = CategoryPathHelper.sortedDistinctPaths(
                owned.map { (path: $0.categoryPath, createdAt: $0.createdAt) }
            )
            ownedCategoryLabels = CategoryPathHelper.displayLabels(for: ownedCategoryOptions)
            soldCategoryOptions = CategoryPathHelper.sortedDistinctPaths(
                sold.map { (path: $0.categoryPath, createdAt: $0.createdAt) }
            )
            soldCategoryLabels = CategoryPathHelper.displayLabels(for: soldCategoryOptions)

            soldItems = narrowed(sold, by: soldNarrowing).sorted(by: isInSoldOrder)
            soldTotals = SaleOutcome.totals(over: soldItems)
        } catch {
            loadFailureMessage = error.localizedDescription
            owned = []
            sold = []
            totalCount = 0
            soldTotalCount = 0
            items = []
            ownedCategoryOptions = []
            ownedCategoryLabels = [:]
            soldCategoryOptions = []
            soldCategoryLabels = [:]
            marketSummaries = [:]
            soldItems = []
            soldTotals = SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0)
        }
    }

    /// The three narrowings, in one place so the two sides can't drift: a
    /// narrowing is about *which gear*, and sold gear still has a category, a
    /// name and a value field (006 plan Q5). `items` is this over the owned
    /// half under `ownedNarrowing`, `soldItems` this over the sold half under
    /// `soldNarrowing`.
    ///
    /// The narrowing is an argument rather than read from the properties (014
    /// plan Q1) so no call site can reach the side that isn't on screen — the
    /// leak Decision 4 forbids is a compile-time impossibility here, not a
    /// convention.
    private func narrowed(_ candidates: [Item], by narrowing: Narrowing) -> [Item] {
        candidates
            // `isWithin`, not `matchesPrefix`: a chip is a category that
            // exists, so "Music/Amps" must not also match
            // "Music/Amplifiers". The typing rule stays in the picker.
            .filter { CategoryPathHelper.path($0.categoryPath, isWithin: narrowing.categoryFilter) }
            // Design's field says "name, brand, serial"; there is no brand
            // in the schema, same gap `ItemRow`'s meta line works around.
            .filter { SearchMatching.matches(query: narrowing.searchText, in: [$0.name, $0.serialNumber]) }
            .filter { !narrowing.showsOnlyUnvalued || $0.currentValueCents == nil }
    }

    /// One fetch of the figure rows, narrowed to the items just fetched.
    ///
    /// The derivation itself lives on `MarketSummary` (002/T013), so the
    /// dashboard's totals read the store through the same step this list
    /// does rather than a second copy of it — including its rule that a
    /// read which throws reads as "nothing stored".
    private static func summaries(for items: [Item], in context: ModelContext, now: Date) -> [UUID: MarketSummary] {
        MarketSummary.summaries(forSubjects: items.map(\.id), in: context, now: now)
    }

    /// The trend the row's arrow draws, or nil for an unmatched item, one
    /// with no figure fetched here, one whose history can't say yet, or one
    /// whose figure is no longer current.
    ///
    /// `currentTrend`, not the stored `trend`: the row draws the arrow beside
    /// a figure the same load already withheld for age, so reading the stored
    /// classification here would have the list assert a direction the Sell
    /// Plan and the Market section had both gone quiet about (003 Decision
    /// 12 — the arrow outlived its figure by however long the person left
    /// the item unrefreshed).
    func trend(for id: UUID) -> MarketTrend? {
        marketSummaries[id]?.currentTrend
    }

    /// Deletes an owned item by id, on the same shape as
    /// `WishlistViewModel.delete(id:)` — the list's swipe (T015) routes here
    /// rather than touching the store itself, per `DeletionGuardTests`'
    /// structural rule, and this new path is inside that rule from day one.
    ///
    /// Photos cascade with it; any sell plan that selected it drops it, the
    /// wishlist entries themselves untouched — the same consequences
    /// `ItemDeleteCopy.message` promises before this runs.
    func delete(id: UUID) {
        // Both arrays: the Sold side has the same trailing swipe the Owned
        // side does (P16), and it deletes through this one path.
        guard let item = items.first(where: { $0.id == id })
            ?? soldItems.first(where: { $0.id == id })
        else { return }

        modelContext.delete(item)
        do {
            // 002: the device's market rows for this item go with it.
            try MarketLocalStore.clear(subjectID: id, in: modelContext)
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
        load()
    }

    /// Applies a drag through `ManualOrderHelper`, exactly as
    /// `WishlistViewModel.move` does — one renumbering rule, both lists.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard canReorder else { return }

        items = ManualOrderHelper.reorder(items, fromOffsets: source, toOffset: destination)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
    }

    /// Whether a row can move one step toward the top. False at the top of
    /// the list, and false whenever the drag itself wouldn't be offered, so
    /// the two reorder mechanisms can't disagree about when reordering is
    /// available. Since T029b the views no longer read this to gate the
    /// VoiceOver actions (position-conditional AX content breaks a settling
    /// drag) — it survives as the boundary guard inside `moveUp`/`moveDown`,
    /// which is what makes the always-offered actions safe to call anywhere.
    func canMoveUp(id: UUID) -> Bool {
        guard canReorder, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return index > 0
    }

    /// See `canMoveUp(id:)`. False at the bottom of the list.
    func canMoveDown(id: UUID) -> Bool {
        guard canReorder, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return index < items.count - 1
    }

    /// One step toward the top: VoiceOver's equivalent of a short drag,
    /// routed through the same `move(fromOffsets:toOffset:)` as the gesture
    /// so there is one reorder path to keep correct, not two.
    func moveUp(id: UUID) {
        guard canMoveUp(id: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
    }

    /// See `moveUp(id:)`. The `+ 2` is `onMove`'s convention: the destination
    /// indexes the array *before* removal, so one step down from `index`
    /// means inserting ahead of the element two positions along.
    func moveDown(id: UUID) {
        guard canMoveDown(id: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
    }

    /// Creates a copy per spec.md's duplicate flow, immediately and without
    /// confirmation: every field as-is except the serial number, which is
    /// cleared — it identifies one physical unit, and carrying it over would
    /// have two rows claiming the same one. Photos become genuinely new
    /// `Photo` rows with duplicated `.externalStorage` data; the
    /// one-photo-one-parent rule (`PhotoOwnershipTests`) allows no sharing,
    /// so the storage cost is real and spec.md accepts it explicitly. Sell
    /// Plan membership is not inherited. The copy lands immediately after
    /// the original in manual order.
    func duplicate(id: UUID) {
        guard let original = items.first(where: { $0.id == id }) else { return }

        let copy = Item(
            name: original.name,
            categoryPath: original.categoryPath,
            purchasePriceCents: original.purchasePriceCents,
            purchaseDate: original.purchaseDate,
            currencyCode: original.currencyCode,
            serialNumber: nil,
            purchaseLocation: original.purchaseLocation,
            currentValueCents: original.currentValueCents,
            desireToKeep: original.desireToKeep,
            condition: original.condition,
            conditionNotes: original.conditionNotes,
            notes: original.notes,
            photos: (original.photos ?? []).map {
                Photo(imageData: $0.imageData, source: $0.source, sortOrder: $0.sortOrder)
            }
        )
        modelContext.insert(copy)

        // Placement runs against the whole collection in manual order, not
        // this screen's filtered slice — see ManualOrderHelper.insert.
        let ordered = (try? modelContext.fetch(
            FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        ManualOrderHelper.insert(copy, after: original, in: ordered)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
        load()
    }

    // MARK: - Mark as sold (014)

    /// The swipe's sheet, seeded exactly as the detail screen's `.mark` sheet
    /// and a Sell Plan row's are (006 plan P1): mode `.mark`, nothing
    /// pre-filled, the price from the item's own current value when it has one
    /// and blank when it doesn't, the date from this screen's injected clock.
    /// One seeding rule for all three hosts — a tested equality (G17) rather
    /// than three factories agreeing by inspection.
    func makeSaleFormViewModel(for item: Item) -> SaleFormViewModel {
        SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: item.currentValueCents, now: now)
    }

    /// Mark as sold… from the Owned side's swipe: the sale points at **no
    /// plan** (006 plan P5) — the swipe is opened from the collection, not
    /// from a plan, so there is nothing for it to be sold toward.
    ///
    /// `ItemSaleStore` is the one writer and callers save, so the item's write
    /// and the device's market rows commit in one `save()`. The `store(_:)`
    /// shape on refusal: roll back, report, re-read.
    ///
    /// Returns false on a refused save.
    @discardableResult
    func markSold(_ item: Item, sale: Sale) -> Bool {
        do {
            try ItemSaleStore.markSold(item, sale: sale, toward: nil, at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery `duplicate`
            // and the detail screen's intents use. The reload below then shows
            // what is actually stored: the row still owned, on the Owned side.
            modelContext.rollback()
            load()
            // After the reload, not before: `load()` clears
            // `loadFailureMessage` on entry, so a message set ahead of it
            // would never reach the screen.
            loadFailureMessage = error.localizedDescription
            return false
        }
        load()
        return true
    }

    // MARK: - Export (011)

    /// The staged file the view offers through the share sheet, or nil.
    /// Settable by the view deliberately: `.sheet(item:)` writes nil back on
    /// dismissal — view mechanics, not business logic.
    var stagedExport: StagedExport?

    /// Set when generation fails (spec criterion 2a); the view presents it
    /// as a plain alert and writes nil back on dismissal.
    var exportFailureMessage: String?

    /// True while a file is generating — the export badge swaps to a spinner
    /// and disables (criterion 11's progress affordance).
    private(set) var isExporting = false

    /// Which items a file from this list carries (014 Decision 7, plan Q14),
    /// in the order the chooser lists them. Chosen independently of the side
    /// on screen — the side decides which *narrowing* is in force (Decision
    /// 4), never which half the file holds.
    enum ExportScope: String, CaseIterable, Identifiable {
        case owned
        case sold
        case both

        var id: String { rawValue }

        /// What the chooser's row calls this — here rather than in the view,
        /// the `SoldSortOrder.label` rule.
        var label: String {
            switch self {
            case .owned: "Owned items"
            case .sold: "Sold items"
            case .both: "Owned and sold"
            }
        }
    }

    /// The rows one scope would carry, under the side on screen's narrowing
    /// (P11). One place the scopes are defined, so a gate can never disagree
    /// with the file it gates — `canExport(_:)` and `exportCSV(scope:)` both
    /// read this and nothing else.
    private func rows(for scope: ExportScope) -> [Item] {
        switch scope {
        case .owned: exportableOwnedItems
        case .sold: exportableSoldItems
        case .both: exportableOwnedItems + exportableSoldItems
        }
    }

    /// Whether a scope has anything to put in a file (criterion 2: an empty
    /// file is never produced) — the chooser's per-row gate.
    func canExport(_ scope: ExportScope) -> Bool { !rows(for: scope).isEmpty }

    /// Whether the menu's CSV row is enabled: it opens the chooser, so it is
    /// enabled when *any* chooser row is (plan Q14). Either side counts,
    /// because the widest scope carries both (plan Q5) — with only sold items
    /// in the collection, the Owned side is empty and the file is still worth
    /// writing. Both halves are counted *narrowed*, so a chip that excludes
    /// everything on both sides still disables the row rather than opening a
    /// chooser with nothing in it.
    var canExportCSV: Bool { canExport(.both) }

    /// Whether the menu's PDF row is enabled. Since 014's chooser (plan Q14)
    /// this reads the same widest scope the CSV row does: the row opens the
    /// chooser rather than exporting, so it is enabled when *any* chooser row
    /// is. The PDF is no longer the owned collection alone — an all-sold
    /// collection, or a Sold chip no owned row is in, has a sold document
    /// worth writing (P13/P14), and it is `canExport(.owned)` that stays
    /// false there and disables that one row.
    var canExportPDF: Bool { canExport(.both) }

    /// The owned rows a file exported from here carries: the **side on
    /// screen's** narrowing over the owned half (014 P11 — a file is never
    /// narrowed by something not on screen), in visible order on the Owned
    /// side and in Custom order from the Sold side, where no owned row is
    /// visible and "visible order" names nothing (014 plan R1).
    ///
    /// On the Owned side this *is* `items` — the array as loaded, not a
    /// second computation of it — so `exportCSV`'s standing claim about
    /// records built from the rows on screen as-is stays literally true, and
    /// `006`'s two-halves guards hold row for row.
    private var exportableOwnedItems: [Item] {
        switch side {
        case .owned: items
        case .sold: narrowed(owned, by: narrowing).sorted(by: ManualOrderHelper.areInCustomOrder)
        }
    }

    /// The sold rows a CSV exported from here would carry: the side on
    /// screen's narrowing over the sold half, **always** in the standing
    /// Sold-side order (014 P10).
    ///
    /// Reads the unnarrowed `sold` half rather than `soldItems`, and sorts
    /// with `areInSoldOrder` rather than the side's current selection: the
    /// Sold sort is the view's reading aid, the file's order is the record's,
    /// which is what keeps `013`'s byte-identity with Settings' CSV true
    /// whatever sort either side happens to show.
    private var exportableSoldItems: [Item] {
        narrowed(sold, by: narrowing).sorted(by: Self.areInSoldOrder)
    }

    /// Combined purchase price of the items on screen — the cover's "total
    /// paid", tracking the filter like `totalCurrentValueCents` does.
    var totalPaidCents: Int { Self.figures(over: items).paidCents }

    /// What the export covers, in the chips' own words — "All items",
    /// "Category: Guitars", with the un-valued filter and any search query
    /// named too, so the document never claims more than the screen showed.
    var exportCoverageLabel: String {
        var parts: [String] = []
        if !categoryFilter.isEmpty {
            parts.append("Category: \(categoryLabels[categoryFilter] ?? categoryFilter)")
        }
        if showsOnlyUnvalued { parts.append("Not yet valued") }
        let query = SearchMatching.normalized(searchText)
        if !query.isEmpty { parts.append("Search: \u{201C}\(query)\u{201D}") }
        return parts.isEmpty ? Self.wholeCoverageLabel : parts.joined(separator: " · ")
    }

    /// The document title and the unfiltered coverage label, named once so
    /// export-everything (`SettingsViewModel`, 013) and this list's own
    /// export can't drift — criterion 5's byte-identity rests on it.
    static let documentTitle = "Owned Items"
    static let wholeCoverageLabel = "All items"

    /// The sold document's title (014 P14, plan Q15). Beside `documentTitle`
    /// for its reason: the sold PDF is a document of its own, in its own file
    /// (`ExportFilename.soldItems`), and its cover must say so rather than
    /// repeating the owned document's words.
    static let soldDocumentTitle = "Sold Items"

    /// The Sold side's order (plan Q9): most recent sale first, then name
    /// case-insensitively, then id — fully determined by the data, the
    /// `SellPlanRanking` tie-break rule, so two sales on the same day can't
    /// reshuffle between visits. Static for `documentTitle`'s reason:
    /// Settings' export-everything sorts its sold rows with this very
    /// function (Q5), so the CSV it writes and the Sold side the person
    /// reads are one order, not two that happen to agree.
    ///
    /// An item with no sale sorts last rather than crashing or landing
    /// somewhere plausible — it has no place on this side at all, and the
    /// callers filter before sorting.
    static func areInSoldOrder(_ lhs: Item, _ rhs: Item) -> Bool {
        if lhs.soldDate != rhs.soldDate {
            guard let left = lhs.soldDate else { return false }
            guard let right = rhs.soldDate else { return true }
            return left > right
        }
        let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if byName != .orderedSame {
            return byName == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// The Sold side's sort under one option (014, plan §2): the option's own
    /// comparison, and the standing order above on any tie (P7), so every
    /// order is total and the same two rows never swap between loads.
    ///
    /// Static, with the option as an argument, for a reason the `CLAUDE.md`
    /// tie-break lesson names: a test can hand it two items directly and
    /// choose their argument order, where a tie asked through a fetch is
    /// asked in an order the test does not control.
    static func areInSoldOrder(_ lhs: Item, _ rhs: Item, under order: SoldSortOrder) -> Bool {
        soldAttributeOrder(lhs, rhs, under: order) ?? areInSoldOrder(lhs, rhs)
    }

    /// What `load()` sorts `soldItems` with — the static comparator under the
    /// side's current selection.
    private func isInSoldOrder(_ lhs: Item, _ rhs: Item) -> Bool {
        Self.areInSoldOrder(lhs, rhs, under: soldSortOrder)
    }

    /// The chosen order's own comparison, `nil` on a tie — the shape
    /// `attributeOrder` uses on the Owned side, so the standing order steps in
    /// exactly where the attribute can't decide.
    private static func soldAttributeOrder(
        _ lhs: Item,
        _ rhs: Item,
        under order: SoldSortOrder
    ) -> Bool? {
        switch order {
        case .soldDate:
            // The standing order *is* this sort: date, then name, then id.
            return nil
        case .salePriceDescending, .salePriceAscending:
            // The Value pair's nil-last block. `salePriceCents` is nil only
            // for an unsold item, which every caller filters before sorting,
            // so this arm is defensive — `SoldSortOrderTests` records it as
            // such rather than pinning it.
            guard lhs.salePriceCents != rhs.salePriceCents else { return nil }
            guard let left = lhs.salePriceCents else { return false }
            guard let right = rhs.salePriceCents else { return true }
            return order == .salePriceDescending ? left > right : left < right
        case .paidDescending, .paidAscending:
            // What was paid is non-optional, so no nil arm here.
            guard lhs.purchasePriceCents != rhs.purchasePriceCents else { return nil }
            return order == .paidDescending
                ? lhs.purchasePriceCents > rhs.purchasePriceCents
                : lhs.purchasePriceCents < rhs.purchasePriceCents
        case .gainDescending, .gainAscending:
            // The sale's outcome against what was paid, signed: `Gain ↓` puts
            // the largest gain first and the largest loss last. Same nil-last
            // block, same defensive reason.
            let leftDelta = lhs.saleOutcome?.deltaCents
            let rightDelta = rhs.saleOutcome?.deltaCents
            guard leftDelta != rightDelta else { return nil }
            guard let left = leftDelta else { return false }
            guard let right = rightDelta else { return true }
            return order == .gainDescending ? left > right : left < right
        case .name:
            let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            guard byName != .orderedSame else { return nil }
            return byName == .orderedAscending
        }
    }

    /// Exports the chosen scope's rows, under what the side on screen covers,
    /// as the canonical CSV. Owned records are built from
    /// `exportableOwnedItems` — on the Owned side `items` as-is — never a
    /// refetch: visible order comes from `isOrderedBefore` over live
    /// filter/sort state and is not reproducible from any `FetchDescriptor`
    /// (criteria 3–4). From the Sold side that half is the record's own
    /// Custom order instead (014 plan R1).
    ///
    /// The scope has **no default** (014 plan Q14): every call site says
    /// which items it means, so `.both` — owned first, then the sold rows in
    /// Sold-side order (plan Q5) — stays exactly the file 011 and 013 pinned,
    /// the same two orderings Settings' export-everything writes, which is
    /// what keeps 013's byte-identity true with a sale present, and since 014
    /// whichever side is on screen (Q8).
    ///
    /// `!isBusy` since 012: one operation at a time across export *and*
    /// import, so their presentations can't race.
    func exportCSV(scope: ExportScope) async {
        guard canExport(scope), !isBusy else { return }
        isExporting = true
        defer { isExporting = false }

        let table = ExportSchema.itemsTable(rows(for: scope).map { ItemExportRecord(item: $0) })
        // A sold-only file is named for what it holds (014 P15); owned and
        // owned-and-sold keep `Trove-Items`, the name Settings ships the very
        // same document under.
        let filename = scope == .sold
            ? ExportFilename.soldItems(fileExtension: "csv")
            : ExportFilename.items(fileExtension: "csv")
        do {
            let url = try await exportService.exportCSV(table, filename: filename)
            stagedExport = StagedExport(url: url, filename: filename)
        } catch {
            exportFailureMessage = ExportCopy.failureMessage
        }
    }

    /// Exports the chosen scope as PDF: the owned collection document, the
    /// sold one, or both in a single share sheet (014 P13, plan Q16). Same
    /// snapshot rule as `exportCSV`, and the covers' figures are this view
    /// model's own arithmetic, which is what criterion 8 measures.
    ///
    /// The scope has **no default** (plan Q14) — every call site says which
    /// items it means, so the Items list's own menu keeps producing exactly
    /// today's owned document until the chooser hands it a scope.
    ///
    /// A half with no rows is dropped rather than staged, so an empty file is
    /// never produced (011 criterion 2) and "owned and sold" with nothing
    /// sold is today's single owned document. The one or two files go through
    /// **one** `exportFiles` call — never one per document, which would purge
    /// each other on the live service — so the pair case can't purge itself
    /// and the single cases share the path (`SettingsViewModel.stage(_:)`).
    func exportPDF(scope: ExportScope) async {
        guard canExport(scope), !isBusy else { return }
        isExporting = true
        defer { isExporting = false }

        var files: [ExportFile] = []
        if scope != .sold, let document = ownedDocument() {
            files.append(.pdf(document, filename: ExportFilename.items(fileExtension: "pdf")))
        }
        if scope != .owned, let document = soldDocument() {
            files.append(.pdf(document, filename: ExportFilename.soldItems(fileExtension: "pdf")))
        }

        do {
            let urls = try await exportService.exportFiles(files)
            stagedExport = StagedExport(urls: urls, filenames: files.map(\.filename))
        } catch {
            exportFailureMessage = ExportCopy.failureMessage
        }
    }

    /// The owned collection document, or nil when the scope's owned half is
    /// empty. Built over `exportableOwnedItems` — the owned half under the
    /// on-screen side's narrowing (014 plan R2) — entries and cover over the
    /// one set of rows, so the cover never claims more than the file lists.
    private func ownedDocument() -> PDFDocumentModel? {
        let rows = exportableOwnedItems
        guard !rows.isEmpty else { return nil }

        let coverFigures = Self.figures(over: rows)
        return PDFDocumentModel(
            cover: CoverSummary(
                title: Self.documentTitle,
                coverageLabel: exportCoverageLabel,
                generatedAt: .now,
                itemCount: rows.count,
                totals: .items(
                    currentValueCents: coverFigures.currentValueCents,
                    paidCents: coverFigures.paidCents,
                    unvaluedCount: coverFigures.unvaluedCount
                )
            ),
            entries: rows.map { PDFEntry(record: ItemExportRecord(item: $0)) }
        )
    }

    /// The sold document (014 P14, plan Q15), or nil when the scope's sold
    /// half is empty. `exportableSoldItems` for the same reason the CSV uses
    /// it: the side's narrowing, always in Date-sold order, whatever the Sold
    /// side happens to be sorted by (P10). Proceeds and the realised delta
    /// come from `SaleOutcome.totals(over:)` — the Dashboard card's own sum —
    /// and what was paid from `figures(over:)`, the header's, so the cover
    /// can't total its rows by a rule the app doesn't use elsewhere.
    private func soldDocument() -> PDFDocumentModel? {
        let rows = exportableSoldItems
        guard !rows.isEmpty else { return nil }

        let saleTotals = SaleOutcome.totals(over: rows)
        return PDFDocumentModel(
            cover: CoverSummary(
                title: Self.soldDocumentTitle,
                coverageLabel: exportCoverageLabel,
                generatedAt: .now,
                itemCount: rows.count,
                totals: .sold(
                    proceedsCents: saleTotals.proceedsCents,
                    paidCents: Self.figures(over: rows).paidCents,
                    realisedDeltaCents: saleTotals.realisedDeltaCents
                )
            ),
            entries: rows.map { PDFEntry(record: ItemExportRecord(item: $0)) }
        )
    }

    // MARK: - Import (012)

    /// What the import flow is showing, or nil — one optional drives the one
    /// import alert (plan §View-model surface: this view already carries
    /// three presentations, and independent booleans that can go true
    /// together are how SwiftUI silently drops one). View-settable so
    /// dismissal writes nil back, the `stagedExport` convention.
    var importPresentation: ImportPresentation<ItemExportRecord>?

    /// True while a picked file parses or a confirmed batch commits. Not
    /// `isImporting`, deliberately: "import" already means *CloudKit sync*
    /// in this file (`mayStillBeImporting`, `completedImports`), and an
    /// empty collection mid-sync is exactly where both meanings are live
    /// at once.
    private(set) var isImportingFile = false

    /// The one busy flag the overflow badge reads. Every export and import
    /// intent guards on it, which serializes the operations.
    var isBusy: Bool { isExporting || isImportingFile }

    /// The import alert's title — composed here, not in the view, so the
    /// copy path stays testable without UI (the `ImportCopy` pattern).
    var importAlertTitle: String {
        switch importPresentation {
        case .confirmation(let preview):
            ImportCopy.confirmationTitle(importCount: preview.validated.count, target: .items)
        case .failure(let title, _):
            title
        case nil:
            ""
        }
    }

    var importAlertMessage: String {
        switch importPresentation {
        case .confirmation(let preview):
            ImportCopy.confirmationMessage(preview: preview)
        case .failure(_, let message):
            message
        case nil:
            ""
        }
    }

    /// Whether the alert offers an Import action: a confirmation with
    /// something to import. Zero importable rows is informational only
    /// (criterion 5).
    var importOffersConfirmation: Bool {
        guard case .confirmation(let preview) = importPresentation else { return false }
        return !preview.validated.isEmpty
    }

    /// Parses the picked file into a staged preview — nothing is written
    /// until `confirmImport()` (criterion 5's parse-first gate).
    func importCSV(from url: URL) async {
        guard !isBusy else { return }
        isImportingFile = true
        defer { isImportingFile = false }

        do {
            let preview = try await importService.parseItems(at: url, timeZone: .current)
            importPresentation = .confirmation(preview)
        } catch let error as ImportError {
            importPresentation = .failure(
                title: ImportCopy.failureTitle,
                message: ImportCopy.failureMessage(for: error, target: .items)
            )
        } catch {
            importPresentation = .failure(
                title: ImportCopy.failureTitle,
                message: ImportCopy.unexpectedFailureMessage
            )
        }
    }

    /// Cancel at the confirmation: nothing was written, so there is nothing
    /// to undo — the store-untouched half of criterion 5.
    func cancelImport() {
        importPresentation = nil
    }

    // 012's `exportBlankTemplate()` lived here until 013 moved the template
    // into Settings (`SettingsViewModel.exportItemsTemplate`); its tests
    // moved with it.

    /// Commits the staged preview: real items built from the validated
    /// records, appended to the end of custom order. On the main actor, on
    /// this context, deliberately (plan §The commit path): parsing was the
    /// expensive part and ran off-main; a bulk insert `load()` can see for
    /// free beats background-context refetch plumbing.
    /// **Synchronous capture, async commit** — reshaped by a T017 device
    /// finding: an alert button's dismissal writes nil through the
    /// presentation binding, and the original `Task`-wrapped async intent
    /// read `importPresentation` only after that write — the guard failed
    /// and Import silently did nothing. The unit tests couldn't see it
    /// (they call with the presentation still staged); only the manual
    /// pass could. The preview is now captured in the button action's
    /// synchronous window, so dismissal ordering can't matter; the
    /// returned task is the commit itself, for tests to await.
    @discardableResult
    func confirmImport() -> Task<Void, Never>? {
        guard !isBusy, case .confirmation(let preview) = importPresentation else { return nil }
        importPresentation = nil
        guard !preview.validated.isEmpty else { return nil }
        isImportingFile = true
        return Task {
            defer { isImportingFile = false }
            // A real suspension before the work, so the badge's spinner renders
            // a frame — setting the flag alone never draws (criterion 15; the
            // T056 lesson in reverse).
            await Task.yield()

            // Placement is computed HERE, never at parse time: a CloudKit
            // arrival — or a hand-add — between the alert and the confirm must
            // not stale the base.
            let existing = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
            let base = ManualOrderHelper.nextPosition(after: existing)

            // The canonical path set is fetched once; the per-row instance
            // method is a full two-entity fetch per call (T009's reason for
            // the static). Batch-internal casing resolves by file row order,
            // first occurrence wins, each resolved path joining the set.
            // Load-bearing beyond tidiness: chip casing follows the earliest
            // `createdAt` across both entities, so an import restoring old
            // dates could otherwise steal an existing path's casing.
            var knownPaths = (try? CategoryPathHelper(modelContext: modelContext).allCategoryPaths()) ?? []

            for (offset, validated) in preview.validated.enumerated() {
                let record = validated.record
                let path = CategoryPathHelper.canonicalize(record.categoryPath, against: knownPaths)
                if !path.isEmpty,
                   !knownPaths.contains(where: { $0.caseInsensitiveCompare(path) == .orderedSame }) {
                    knownPaths.append(path)
                }
                let item = Item(
                    name: record.name,
                    categoryPath: path,
                    purchasePriceCents: record.purchasePriceCents,
                    purchaseDate: record.purchaseDate,
                    currencyCode: record.currencyCode,
                    serialNumber: record.serialNumber,
                    purchaseLocation: record.purchaseLocation,
                    currentValueCents: record.currentValueCents,
                    desireToKeep: record.desireToKeep,
                    condition: Condition(rawValue: record.conditionRawValue) ?? .excellent,
                    conditionNotes: record.conditionNotes,
                    notes: record.notes,
                    sortOrder: base + offset,
                    // 002/T016a: the CSV's two appended columns restore the
                    // Reverb match and the year, so a re-imported item asks
                    // the same question of the market as before it left.
                    reverbProductID: record.reverbProductID,
                    year: record.year
                )
                modelContext.insert(item)
                // 006 (plan §7, Q6): a row carrying both halves of the pair
                // arrives sold. It points at no plan — an imported sale has
                // no wishlist item on this device it could have funded
                // (P11) — and `Item.sale` writes the four fields, so the
                // date-without-price shape never reaches the store.
                if let soldDate = record.soldDate, let salePriceCents = record.salePriceCents {
                    item.sale = Sale(
                        date: soldDate,
                        priceCents: salePriceCents,
                        location: record.saleLocation,
                        note: record.saleNote
                    )
                }
            }

            do {
                try modelContext.save()
            } catch {
                // Without the rollback, `load()` on this same context would
                // show the phantom batch — unsaved objects the context happily
                // returns — which would vanish on relaunch (criterion 14's
                // "never a partial batch").
                modelContext.rollback()
                importPresentation = .failure(
                    title: ImportCopy.failureTitle,
                    message: ImportCopy.saveFailureMessage
                )
            }
            load()
        }
    }

    private func isOrderedBefore(_ lhs: Item, _ rhs: Item) -> Bool {
        // Attribute first, the user's own order on any tie — spec.md's
        // confirmed rule for every non-"Custom" sort (plan.md's Resolved
        // decision 5 left this open; the first implementation fell back to
        // name, T039's review caught the divergence, and the 2026-08-30
        // close-out decided it: manual order, both lists). The order itself
        // — position, then the creation-then-id tie-break a pre-`010` store
        // needs — lives in `ManualOrderHelper` since 013, so "Custom" here
        // and Settings' export-everything sort with one function rather
        // than two that agree.
        attributeOrder(lhs, rhs) ?? ManualOrderHelper.areInCustomOrder(lhs, rhs)
    }

    /// The active sort's own comparison, `nil` on a tie — the shape
    /// `ManualOrderHelper.areInOrder` wants, mirroring the wishlist's
    /// `attributeOrder` so manual order steps in exactly where the attribute
    /// can't decide.
    private func attributeOrder(_ lhs: Item, _ rhs: Item) -> Bool? {
        switch sortOrder {
        case .custom:
            return nil
        case .purchaseDate:
            guard lhs.purchaseDate != rhs.purchaseDate else { return nil }
            return lhs.purchaseDate > rhs.purchaseDate
        case .currentValue, .currentValueAscending:
            guard lhs.currentValueCents != rhs.currentValueCents else { return nil }
            // Un-valued items sort last in *either* direction — they're not
            // worth zero, they're unknown, same as on the dashboard;
            // ascending must not promote them above the cheapest valued
            // item.
            guard let left = lhs.currentValueCents else { return false }
            guard let right = rhs.currentValueCents else { return true }
            return sortOrder == .currentValue ? left > right : left < right
        case .marketFigure, .marketFigureAscending:
            // The same nil-last block, over the device's own figure: an item
            // with no current median — unmatched, never refreshed here,
            // withheld, or stale past thirty days (Decision 21) — is unknown
            // rather than cheap, so it sorts last in either direction.
            let leftMedian = marketSummaries[lhs.id]?.medianCents
            let rightMedian = marketSummaries[rhs.id]?.medianCents
            guard leftMedian != rightMedian else { return nil }
            guard let left = leftMedian else { return false }
            guard let right = rightMedian else { return true }
            return sortOrder == .marketFigure ? left > right : left < right
        case .desireToKeep:
            guard lhs.desireToKeep != rhs.desireToKeep else { return nil }
            return lhs.desireToKeep > rhs.desireToKeep
        }
    }
}
