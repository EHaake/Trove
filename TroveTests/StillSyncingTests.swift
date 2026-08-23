import Foundation
import SwiftData
import Testing
@testable import Trove

/// T053/T054: an empty screen mid-import means "not here *yet*," and every
/// screen that used to say otherwise now says so.
///
/// `SyncMonitorTests` covers where the phase comes from; this covers what the
/// four screens do with it, and — the half that's easy to skip — what they
/// still do without it, since a `stillSyncing` that outranks everything would
/// be its own bug.
@Suite("Still syncing")
struct StillSyncingTests {
    /// A monitor mid-first-import, built the way a real one gets there.
    private func importing() -> SyncMonitor {
        let monitor = SyncMonitor(mode: .cloudKit)
        monitor.record(SyncEvent(kind: .importChanges, isFinished: false, succeeded: false))
        return monitor
    }

    private func caughtUp() -> SyncMonitor {
        let monitor = SyncMonitor(mode: .cloudKit)
        monitor.record(SyncEvent(kind: .importChanges, isFinished: true, succeeded: true))
        return monitor
    }

    // MARK: - The rule

    @Test func anEmptyCollectionMidImportIsNotAnEmptyCollection() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 0, visibleCount: 0, searchText: "", categoryFilter: "",
                mayStillBeImporting: true
            ) == .stillSyncing
        )
    }

    @Test func anEmptyCollectionOnceCaughtUpIsJustEmpty() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 0, visibleCount: 0, searchText: "", categoryFilter: "",
                mayStillBeImporting: false
            ) == .nothingAdded
        )
    }

    /// The success claim. "Everything has a value" over a third of someone's
    /// gear is the same false confidence as "you own nothing".
    @Test func aCompleteSetOfValuesIsNotClaimedOverAPartialCollection() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 3, visibleCount: 0, searchText: "", categoryFilter: "",
                showsOnlyUnvalued: true, mayStillBeImporting: true
            ) == .stillSyncing
        )
    }

    /// The other side of the precedence, and the one worth stating as a test
    /// rather than a comment: what the user typed still gets an answer. The
    /// note that answer carries is checked below.
    @Test func aSearchStillGetsAnAnswerMidImport() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 3, visibleCount: 0, searchText: "hasselblad", categoryFilter: "",
                mayStillBeImporting: true
            ) == .searchMatchedNothing(query: "hasselblad")
        )
    }

    @Test func aCategoryFilterStillGetsAnAnswerMidImport() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 3, visibleCount: 0, searchText: "", categoryFilter: "Audio",
                mayStillBeImporting: true
            ) == .categoryMatchedNothing
        )
    }

    /// Not empty is not empty, whatever CloudKit is doing.
    @Test func aListWithRowsInItHasNoEmptyStateAtAll() {
        #expect(
            ListEmptyReason.reason(
                totalCount: 9, visibleCount: 9, searchText: "", categoryFilter: "",
                mayStillBeImporting: true
            ) == nil
        )
    }

    // MARK: - What the surviving cases say

    /// The half of the precedence decision that isn't the precedence: the
    /// filtered cases keep their headline, and stop stating their narrower
    /// absence as final.
    @Test func aSurvivingEmptyStateSaysItMayNotBeTheWholePicture() {
        let detail = ListEmptyReason.detail(
            "Names and serial numbers are what's searched.",
            mayStillBeImporting: true
        )

        #expect(detail.hasPrefix("Names and serial numbers are what's searched."))
        #expect(detail.contains(ListEmptyReason.stillArrivingNote))
    }

    @Test func aSettledEmptyStateSaysNothingAboutICloud() {
        let base = "Names and serial numbers are what's searched."

        #expect(ListEmptyReason.detail(base, mayStillBeImporting: false) == base)
    }

    // MARK: - The four screens

    @Test func theItemListAsksItsMonitor() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = ItemListViewModel(modelContext: context, syncMonitor: importing())

        viewModel.load()

        #expect(viewModel.emptyReason == .stillSyncing)
        #expect(viewModel.mayStillBeImporting)
    }

    @Test func theWishlistAsksItsMonitor() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = WishlistViewModel(modelContext: context, syncMonitor: importing())

        viewModel.load()

        #expect(viewModel.emptyReason == .stillSyncing)
    }

    /// The launch tab, so the one a new device sees first.
    @Test func theDashboardAsksItsMonitor() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = DashboardViewModel(modelContext: context, syncMonitor: importing())

        viewModel.load()

        #expect(viewModel.isEmpty)
        #expect(viewModel.isStillSyncing)
    }

    @Test func theSellPlanAsksItsMonitor() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let wanted = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(wanted)

        let viewModel = SellPlanViewModel(
            modelContext: context,
            wishlistItemID: wanted.id,
            syncMonitor: importing()
        )
        viewModel.load()

        #expect(viewModel.emptyReason == .stillSyncing)
    }

    /// The Sell Plan's own precedence: unlike the list screens, `stillSyncing`
    /// outranks every case, because none of the three is feedback on something
    /// the user typed. "Everything's a keeper" is exactly as wrong as "nothing
    /// to sell yet" when the low-desire items are the ones still in flight.
    @Test func theSellPlanDoesNotDiagnoseAPartialCollection() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let wanted = WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps")
        context.insert(wanted)
        // Rated 5, so without the monitor this is `everythingIsAKeeper`.
        let keeper = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        keeper.desireToKeep = 5
        keeper.currentValueCents = 345_000
        context.insert(keeper)

        let midImport = SellPlanViewModel(
            modelContext: context, wishlistItemID: wanted.id, syncMonitor: importing()
        )
        midImport.load()
        #expect(midImport.emptyReason == .stillSyncing)

        let settled = SellPlanViewModel(
            modelContext: context, wishlistItemID: wanted.id, syncMonitor: caughtUp()
        )
        settled.load()
        #expect(settled.emptyReason == .everythingIsAKeeper, "The diagnosis is still made once it's earned")
    }

    // MARK: - Once the import lands

    /// The whole point is that this is temporary. A screen stuck on "catching
    /// up" forever would be a worse lie than the one being fixed.
    @Test func aCaughtUpDeviceGoesBackToTheOrdinaryEmptyStates() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = ItemListViewModel(modelContext: context, syncMonitor: caughtUp())

        viewModel.load()

        #expect(viewModel.emptyReason == .nothingAdded)
        #expect(!viewModel.mayStillBeImporting)
    }

    /// T051's probe recorded exactly this sequence on a simulator with no
    /// iCloud account. Nothing further arrives, so the collection on screen is
    /// the whole collection and the ordinary invitation to add something is
    /// the right one.
    @Test func aSignedOutDeviceGetsTheOrdinaryEmptyStates() throws {
        let monitor = SyncMonitor(mode: .cloudKit)
        monitor.record(SyncEvent(kind: .setup, isFinished: false, succeeded: false))
        monitor.record(SyncEvent(kind: .setup, isFinished: true, succeeded: false))

        let context = ModelContext(try makeInMemoryContainer())
        let viewModel = ItemListViewModel(modelContext: context, syncMonitor: monitor)
        viewModel.load()

        #expect(viewModel.emptyReason == .nothingAdded)
    }
}

/// The wiring T053 can't see: every screen that can show an empty state has to
/// have been *given* a monitor, and the default is one that never syncs. A
/// screen left on the default is indistinguishable from a correct one in every
/// test above — it just silently never shows the new state.
@Suite("Still syncing wiring")
struct StillSyncingWiringTests {
    /// Each place a screen that can show an empty state is constructed.
    ///
    /// Checked call by call, not file by file. The first version of this test
    /// asked whether the file mentioned `syncMonitor: syncMonitor` anywhere,
    /// which `ContentView` satisfies with one of its three tabs wired and the
    /// other two silently on the default — mutation testing is how that
    /// surfaced, since deleting one handoff left the test green.
    struct Handoff: Sendable, CustomStringConvertible {
        let file: String
        let callee: String

        var description: String { "\(callee) in \(file)" }
    }

    private nonisolated static let handoffs = [
        Handoff(file: "Trove/App/ContentView.swift", callee: "DashboardView"),
        Handoff(file: "Trove/App/ContentView.swift", callee: "ItemListView"),
        Handoff(file: "Trove/App/ContentView.swift", callee: "WishlistView"),
        // The scoped dashboard the root one pushes, and the Sell Plan pushed
        // from wishlist detail — the two easiest to forget.
        Handoff(file: "Trove/Views/Dashboard/DashboardView.swift", callee: "DashboardView"),
        Handoff(file: "Trove/Views/Wishlist/WishlistDetailView.swift", callee: "SellPlanView"),
    ]

    /// The two list screens compose their own detail lines, and a filtered
    /// empty state that forgets the note goes back to stating a narrower
    /// absence as fact.
    private nonisolated static let listScreens = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ]

    private func source(_ path: String) throws -> String {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test(arguments: handoffs)
    func everyScreenIsHandedTheRealMonitor(handoff: Handoff) throws {
        // Truncated at `#Preview`: a preview legitimately takes the default,
        // since there's no app around it to have a real monitor.
        let calls = SourceScan.argumentLists(
            of: handoff.callee,
            in: try SourceScan.production(handoff.file)
        )

        #expect(!calls.isEmpty, "No \(handoff.callee)(…) found in \(handoff.file) — this would pass over nothing.")
        for call in calls {
            #expect(
                call.contains("syncMonitor"),
                """
                \(handoff) is constructed without its monitor, so it falls back \
                to SyncMonitor.notSyncing and can never show the still-syncing \
                state: \(handoff.callee)(\(call.trimmingCharacters(in: .whitespacesAndNewlines)))
                """
            )
        }
    }

    /// Every screen that can show the still-syncing state has to leave it when
    /// the data lands. The view models fetch on appear and hold an array, so an
    /// import arriving under an open screen changes nothing until something
    /// asks them to look again — and the screen it leaves behind claims the
    /// collection is empty.
    ///
    /// Comment-stripped and body-checked. The first version was a bare
    /// `contains`, which a commented-out modifier still satisfies — the exact
    /// mutation that proved it, after this test was accidentally deleted
    /// during the rewrite and the suite stayed green without it.
    @Test(arguments: [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
        "Trove/Views/Dashboard/DashboardView.swift",
        "Trove/Views/Wishlist/SellPlanView.swift",
    ])
    func everyScreenRefetchesWhenAnImportLands(path: String) throws {
        let bodies = SourceScan.closureBodies(
            after: ".onChange(of: viewModel.completedImports)",
            in: try SourceScan.production(path)
        )

        #expect(bodies.count == 1, "\(path) has \(bodies.count) import-refetch handlers, expected exactly 1")
        for body in bodies {
            #expect(
                body.contains("viewModel.load()"),
                """
                \(path) watches the import count but doesn't refetch, so it would \
                sit on "Catching up with iCloud" until the data arrived and then \
                show the empty state instead of the collection: {\(body)}
                """
            )
        }
    }

    @Test(arguments: listScreens)
    func bothListScreensQualifyTheirFilteredEmptyStates(path: String) throws {
        // Counts the *call sites*, not the helper's existence. The previous
        // version looked for "ListEmptyReason.detail(", which lives in a private
        // helper in both views — drop `detail(...)` from the two filtered cases
        // and the helper survives unused (Swift doesn't error on that), so the
        // guard stayed green while the note vanished from the UI.
        let qualified = try SourceScan.production(path)
        let callSites = SourceScan.argumentLists(of: "EmptyStateView", in: qualified)
            .count { $0.contains("detail: detail(") }

        #expect(
            callSites == 2,
            """
            \(path) qualifies \(callSites) empty state(s) mid-import, expected 2 \
            (the search and category cases). Any other number means a filtered \
            empty state states a narrower absence as final while the collection \
            is still arriving.
            """
        )
    }
}
