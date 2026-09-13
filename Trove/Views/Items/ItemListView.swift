import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The header's two dropdowns. One optional of this type is the screen's
/// whole open-menu state, which is what makes "one open at a time" true by
/// type rather than by coordination (013 Amendment A).
private enum HeaderDropdown: Hashable {
    case sort
    case overflow

    /// What the tap-outside layer calls itself to VoiceOver.
    var dismissLabel: String {
        switch self {
        case .sort: "Dismiss sort options"
        case .overflow: "Dismiss more actions"
        }
    }
}

/// Browse owned gear, per `design/screens/Trove Item List.png`.
struct ItemListView: View {
    @State private var viewModel: ItemListViewModel
    @State private var isAddingItem = false

    /// The row a swipe has asked to delete, held until the alert resolves it.
    /// Same staging the wishlist uses: the swipe-then-tap gesture is a fine
    /// two-step on its own, but it can't *say* anything — and every delete
    /// path in this app states its consequences before committing.
    @State private var pendingDeletion: Item?

    /// The row whose Edit swipe action is open in the form sheet — the same
    /// form, same pre-fill, the detail screen already presents; the swipe is
    /// a shortcut into that flow, not a new one (spec.md).
    @State private var itemBeingEdited: Item?

    /// The chip the next layout pass should bring into view.
    ///
    /// Set only when a filter arrives from another tab, never when the user
    /// taps a chip themselves — their finger already put it where they can see
    /// it, and sliding it out from under them would be motion for nothing.
    @State private var chipToReveal: String?

    /// The un-valued chip's scroll id. Not a category path, so it can't
    /// collide with one — no real path is empty *and* prefixed like this.
    private static let unvaluedChipID = "\u{0}unvalued"

    /// Which header dropdown is open — Sort By or the "…" — or neither.
    /// Owned here rather than by a badge because the dropdown floats over
    /// the whole screen and dismisses on any outside tap, both beyond the
    /// header's reach; one optional, so only one can be open (T035, then
    /// 013 Amendment A).
    @State private var openDropdown: HeaderDropdown?

    /// Whether 012's file picker is up. View state, not view-model state:
    /// the picker is pure navigation — the view model's flow starts when a
    /// URL actually arrives.
    @State private var isPickingImportFile = false

    /// Whether 013's Settings sheet is up — view state like the picker:
    /// the sheet is navigation, and the view model behind it is its own.
    @State private var isShowingSettings = false

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.storageMode) private var storageMode
    @Environment(\.storageFallbackReason) private var storageFallbackReason
    /// 004: the app-level appearance choice, injected by `ThemedRoot`, threaded
    /// into the Settings sheet the way `syncMonitor` is — never read there.
    @Environment(AppearanceStore.self) private var appearanceStore
    /// 004 (T009): the resolved scheme under `ThemedRoot`, read HERE so the
    /// Settings sheet can adopt it — the sheet's own `colorScheme` is the stale
    /// value a live switch leaves behind, which is the bug being fixed.
    @Environment(\.colorScheme) private var systemColorScheme

    /// Kept for the Settings sheet, which is constructor-injected the way
    /// `ContentView` injects this screen — one delivery mechanism for the
    /// monitor, never a sheet reading an observable it might not have.
    private let syncMonitor: SyncMonitor

    init(modelContext: ModelContext, syncMonitor: SyncMonitor = .notSyncing) {
        self.syncMonitor = syncMonitor
        _viewModel = State(
            initialValue: ItemListViewModel(modelContext: modelContext, syncMonitor: syncMonitor)
        )
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            // Title, summary, search and filter chips stay put; only the rows
            // move. Standing layout rule in plan.md — the wishlist follows it
            // too. Losing the running total, the query and the active filter
            // the moment you scroll is what it's there to prevent.
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: theme.metrics.controlRowGap) {
                    header
                        .padding(.horizontal, theme.metrics.screenGutter)
                        .padding(.bottom, theme.metrics.sectionGap - theme.metrics.controlRowGap)

                    // Controls for narrowing a list need a list to narrow. On a
                    // first run they were a search field over nothing and a
                    // lone "All" chip, both of which made the screen look like
                    // it had lost something rather than not started yet.
                    if viewModel.totalCount > 0 {
                        SearchField(placeholder: "Search name or serial", text: $viewModel.searchText)
                            .padding(.horizontal, theme.metrics.screenGutter)

                        // Full-bleed so chips scroll off the edge rather than
                        // stopping at the gutter; the gutter moves inside.
                        categoryChips
                    }
                }
                .padding(.top, theme.metrics.sectionGap)
                // Only as much space as sits between two rows. A full section
                // gap here on top of each card's own padding read as a hole
                // between the chips and the list.
                .padding(.bottom, theme.metrics.listRowGap)
                .background(theme.colors.background)

                // Outside the scroll view on purpose: there's nothing to
                // scroll, and a centred block only reads as centred if it
                // takes the whole space the rows would have.
                if let reason = viewModel.emptyReason {
                    emptyState(reason)
                } else {
                    rows
                }
            }
        }
        // Floats over the rows on purpose — see plan.md's Navigation section.
        // The list scrolls right to the bottom underneath it.
        .overlay(alignment: .bottomTrailing) {
            AddButton(label: "Add item") { isAddingItem = true }
                .padding(.trailing, theme.metrics.screenGutter)
                .padding(.bottom, theme.metrics.sectionGap)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        // The one destination for this stack, and deliberately the only
        // push mechanism: row taps and the router (the dashboard's un-valued
        // callout) both go through the bound `itemsPath`. T039's review
        // caught the split that existed before — row taps pushed through a
        // separate `navigationDestination(item:)` binding the router
        // couldn't see, so `popToItemsRoot()` left a tapped-open detail
        // sitting on top of the narrowed list the dashboard had asked for.
        // One path, one destination, and the router's pop clears everything.
        .navigationDestination(for: UUID.self) { itemID in
            ItemDetailView(modelContext: modelContext, itemID: itemID)
        }
        // Owned here rather than by a parent so dismissing the form can
        // refetch — a new item has to appear without the user leaving and
        // coming back.
        .sheet(isPresented: $isAddingItem, onDismiss: viewModel.load) {
            NavigationStack {
                ItemFormView(modelContext: modelContext)
            }
        }
        // The Edit swipe's sheet (T023). Same refetch-on-dismiss reasoning
        // as the add sheet above.
        .sheet(item: $itemBeingEdited, onDismiss: viewModel.load) { item in
            NavigationStack {
                ItemFormView(modelContext: modelContext, editing: item)
            }
        }
        // 013's Settings sheet. Owned here like the form sheets, for the
        // same reason: a Delete All behind it has to show on this list the
        // moment it comes back.
        .sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load) {
            NavigationStack {
                SettingsView(
                    modelContext: modelContext,
                    appearanceStore: appearanceStore,
                    syncMonitor: syncMonitor,
                    storageMode: storageMode,
                    storageFallbackReason: storageFallbackReason
                )
            }
            // 004 (T009): the sheet adopts the resolved scheme so its own
            // system chrome follows a live appearance switch — read from this
            // host, under `ThemedRoot`, never from inside the sheet.
            .preferredColorScheme(appearanceStore.choice.sheetColorScheme(device: systemColorScheme))
        }
        // Values can change on the detail screen — an edit, or the dial — so
        // the list refetches whenever it comes back into view.
        // Applied here rather than written into the view model by the router:
        // navigation asks, the screen decides how to show it.
        .onAppear {
            apply(router.itemsRequest)
            applyAddItemRequest()
            viewModel.load()
        }
        .onChange(of: router.itemsRequest) { _, request in
            guard request != nil else { return }
            apply(request)
            viewModel.load()
        }
        // The dashboard's first-run empty state asks for the form; this tab is
        // where it lives.
        .onChange(of: router.wantsAddItemForm) { applyAddItemRequest() }
        // Per keystroke. A refetch-and-filter over a personal inventory is
        // cheap enough that debouncing would only add latency to typing;
        // revisit if the store ever holds thousands of items.
        .onChange(of: viewModel.searchText) { viewModel.load() }
        // An import landing while this screen is open changes what it should
        // show, and nothing else tells it — the view models fetch on appear
        // and hold an array rather than observing the store.
        .onChange(of: viewModel.completedImports) { viewModel.load() }
        // Pull to refresh, per plan.md's CloudKit sync section: the user says
        // when a screen should look again, rather than the screen watching the
        // store continuously. Straight into the same load() everything else
        // calls — no second fetch path to keep in step with this one.
        .refreshable {
            viewModel.load()
            // Holds the refresh open so the list doesn't snap back up
            // underneath the still-animating spinner — see RefreshPacing.
            await RefreshPacing.hold()
        }
        // The same alert, word for word, that the detail screen shows for the
        // same action — both read from ItemDeleteCopy, so they can't drift.
        // Same staging shape as the wishlist's.
        .alert(
            ItemDeleteCopy.title(for: pendingDeletion?.name ?? "this item"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { item in
            Button(ItemDeleteCopy.confirm, role: .destructive) {
                viewModel.delete(id: item.id)
            }
            Button(ItemDeleteCopy.cancel, role: .cancel) {}
        } message: { item in
            Text(ItemDeleteCopy.message(isSold: item.isSold))
        }
        // 011's share sheet, presented off view-model state so the export
        // intent stays a testable method; dismissal writes nil back through
        // the binding.
        .sheet(item: $viewModel.stagedExport) { staged in
            ShareSheet(urls: staged.urls)
                .presentationDetents([.medium, .large])
        }
        // Criterion 2a: a failed export says so plainly — shared copy, so
        // the two screens and their view models can't drift.
        .alert(
            ExportCopy.failureTitle,
            isPresented: Binding(
                get: { viewModel.exportFailureMessage != nil },
                set: { if !$0 { viewModel.exportFailureMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportFailureMessage ?? ExportCopy.failureMessage)
        }
        // 012's file picker. `.plainText` deliberately included — CSVs that
        // arrived by mail are routinely `.txt`, and the header gate is the
        // real filter. Cancellation must be a no-op: only a picked URL
        // starts the flow, so a `.failure` (or an uninvoked callback,
        // whichever this OS does) never surfaces as the failure alert.
        .fileImporter(
            isPresented: $isPickingImportFile,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            if case .success(let url) = result {
                Task { await viewModel.importCSV(from: url) }
            }
        }
        // 012's one import presentation — the pre-commit gate or a failure,
        // both off a single optional (plan §View-model surface: independent
        // booleans that can go true together are how SwiftUI drops an
        // alert). The zero-importable confirmation renders dismiss-only.
        .alert(
            viewModel.importAlertTitle,
            isPresented: Binding(
                get: { viewModel.importPresentation != nil },
                set: { if !$0 { viewModel.importPresentation = nil } }
            )
        ) {
            if viewModel.importOffersConfirmation {
                Button("Import") { viewModel.confirmImport() }
                Button("Cancel", role: .cancel) { viewModel.cancelImport() }
            } else {
                Button("OK", role: .cancel) { viewModel.cancelImport() }
            }
        } message: {
            Text(viewModel.importAlertMessage)
        }
        // The header's dropdowns float over the whole screen from here —
        // T035's screen-level float-and-catcher, now the shared host
        // (013 Amendment A): it finds the open badge by its anchor, so the
        // header needn't reach over the rows below it, and it closes on
        // any outside tap. Placed after the add button's overlay so the
        // dropdown draws above it.
        .dropdownHost(open: $openDropdown, dismissLabel: \.dismissLabel) { dropdown in
            switch dropdown {
            case .sort:
                SortDropdown(
                    options: ItemListViewModel.SortOrder.allCases,
                    selection: viewModel.sortOrder,
                    label: \.label,
                    isManualOrder: { $0 == .custom }
                ) { option in
                    // The row has already closed the dropdown.
                    viewModel.sortOrder = option
                    viewModel.load()
                }
            case .overflow:
                OverflowDropdown(
                    canExport: viewModel.canExport,
                    exportCSV: { Task { await viewModel.exportCSV() } },
                    exportPDF: { Task { await viewModel.exportPDF() } },
                    importCSV: { isPickingImportFile = true },
                    openSettings: { isShowingSettings = true }
                )
            }
        }
    }

    // MARK: - Rows

    /// A `List` for the same reasons the wishlist's is one — swipe actions
    /// now, drag reordering at T027 — with everything visible overridden so it
    /// reads as the same card stack the `LazyVStack` used to draw. The styling
    /// mirrors `WishlistView.rows` line for line, deliberately: the two list
    /// screens are one pattern, not two (T012).
    private var rows: some View {
        List {
            ForEach(viewModel.items, id: \.id) { item in
                ItemRow(item: item, trend: viewModel.trend(for: item.id))
                    // The screen's own background, not `.clear`, and not
                    // decoration: at rest they're pixel-identical (the screen
                    // shows through either way), but the reorder lift
                    // snapshots the row *with* this background. Clear-backed,
                    // UIKit substitutes an opaque black plateau behind the
                    // snapshot and the row floats as an edge-to-edge black
                    // slab; screen-colored, the slab blends into the screen
                    // and only the plate reads as picked up. Verified on film
                    // both ways (2026-08-30).
                    .listRowBackground(theme.colors.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: theme.metrics.listRowGap / 2,
                        leading: theme.metrics.listRowInset,
                        bottom: theme.metrics.listRowGap / 2,
                        trailing: theme.metrics.listRowInset
                    ))
                    .contentShape(Rectangle())
                    // Tap-gesture navigation, same as the wishlist: inside a
                    // List a `NavigationLink` row brings its own styling, and
                    // the row is already the whole tap target. Pushed through
                    // the router's bound path — not view-local state — so a
                    // cross-tab pop (`popToItemsRoot`) can actually clear it.
                    .onTapGesture { router.itemsPath.append(item.id) }
                    // Stages, never deletes — the alert commits through the
                    // view model (T015). A full swipe triggers the same
                    // staging, so the farthest gesture still can't skip the
                    // consequence line.
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = item
                        } label: {
                            // Design's own glyphs (T036), not SF Symbols —
                            // template-rendered from `design/icons/`.
                            Label { Text(ItemDeleteCopy.confirm) } icon: { Image("ActionDelete") }
                        }
                        // Explicit, not redundant: ContentView's brass .tint
                        // cascades into swipe buttons and overrides the
                        // destructive role's default red. Every swipe action
                        // must color itself from tokens.md's "Swipe-action
                        // rows" table for the same reason — rust stays the
                        // one consequential color on a swiped-open row.
                        .tint(theme.colors.accentRust)
                    }
                    // Edit nearest the edge, Copy second — the design mock's
                    // order, and Edit is what a full swipe triggers. Neutral
                    // tints per tokens.md, so rust keeps the only
                    // consequential color on a swiped-open row.
                    .swipeActions(edge: .leading) {
                        Button {
                            itemBeingEdited = item
                        } label: {
                            Label { Text("Edit") } icon: { Image("ActionEdit") }
                        }
                        .tint(theme.colors.divider)
                        // "Copy" on screen, "Duplicate" in code — Design's
                        // chosen string, per plan.md's Resolved decisions
                        // (the refreshed export's DUPLICATE is outdated
                        // text, confirmed at the Phase 7 review).
                        Button {
                            viewModel.duplicate(id: item.id)
                        } label: {
                            Label { Text("Copy") } icon: { Image("ActionDuplicate") }
                        }
                        .tint(theme.colors.surfaceInset)
                    }
                    // VoiceOver's route into reordering. The drag gesture
                    // below has no accessible equivalent of its own, and the
                    // edit mode that natively carries Move Up/Move Down left
                    // at T028a — these named actions are what keeps spec.md's
                    // "reordering is VoiceOver-reachable on both lists"
                    // criterion true, invisibly. Gated on `canReorder` alone,
                    // never on the row's position: an earlier position-aware
                    // version changed this block's structure while a drag
                    // settled, and the List answered by painting the
                    // pre-drag order over the committed move (T029b's
                    // bisect pinned it). The ends of the list are handled
                    // inside `moveUp`/`moveDown`, which no-op there.
                    .accessibilityActions {
                        if viewModel.canReorder {
                            Button("Move up") { viewModel.moveUp(id: item.id) }
                            Button("Move down") { viewModel.moveDown(id: item.id) }
                        }
                    }
            }
            // Attached only while Custom is the active, unnarrowed view —
            // `nil` detaches the gesture entirely, so reordering is hidden,
            // not just disabled, everywhere it wouldn't be meaningful (T027).
            // The view model's own guard stays as the second line of defense.
            .onMove(perform: viewModel.canReorder ? { source, destination in
                viewModel.move(fromOffsets: source, toOffset: destination)
            } : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // No bottom margin, deliberately — the add button and the tab bar sit
        // over the last row or two when scrolled fully down. Same rule as
        // `WishlistView.rows`, recorded in plan.md's Navigation section.
        //
        // No `\.editMode` here, deliberately. An interim build wired it to
        // `canReorder`, which put drag handles on every row and silenced the
        // swipe actions whenever Custom was active — spec.md's reorder flow
        // records why that left: Custom only *allows* the long-press drag.
        // VoiceOver reorders through the rows' named actions instead.
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Items")
                    .font(theme.typography.screenTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(summaryLine).monoLabel()
            }

            Spacer()

            // Nothing to sort on an empty list, so the sort badge still
            // hides — but the "…" shows regardless since 012 (criterion 1,
            // superseding 011's hide-when-empty rule): its menu carries
            // Import and, since 013, Settings — where the blank template
            // now lives — and the fresh install with a spreadsheet in hand
            // is exactly who they serve. Guarded from both directions —
            // ImportWiringTests' brace-span scan and the empty-collection
            // UI test.
            HStack(spacing: 8) {
                if viewModel.totalCount > 0 {
                    sortControl
                }
                overflowControl
            }
        }
    }

    /// 011's export menu grown into 012's overflow, with 013's Settings at
    /// the bottom — since Amendment A a badge that opens `OverflowDropdown`
    /// on the screen's host. The async intents fire into Tasks and
    /// `isBusy` drives the spinner; Import opens the file picker and
    /// Settings opens its sheet rather than an intent — navigation is view
    /// state here.
    private var overflowControl: some View {
        OverflowBadge(isBusy: viewModel.isBusy) {
            openDropdown = .overflow
        }
        .dropdownAnchor(HeaderDropdown.overflow)
        .accessibilityIdentifier("moreActions.items")
    }

    /// Design's "34 ITEMS · $18,420", plus a count of what the total leaves
    /// out. Items with no value entered aren't worth zero, so saying how many
    /// there are keeps the figure honest as a floor.
    private var summaryLine: String {
        let count = viewModel.items.count
        var parts = ["\(count) \(count == 1 ? "item" : "items")"]
        parts.append(viewModel.totalCurrentValueCents.formattedAsWholeCurrency(currencyCode: "USD"))
        if viewModel.unvaluedCount > 0 {
            parts.append("\(viewModel.unvaluedCount) unvalued")
        }
        return parts.joined(separator: " · ")
    }

    /// T035's badge — see `SortBadge` for why this stopped being a system
    /// `Menu` (the T029c saga in one sentence: UIKit animated the Menu
    /// label's bounds beyond SwiftUI's reach; a custom control has no such
    /// machinery, so the badge simply hugs its label again).
    private var sortControl: some View {
        SortBadge(label: viewModel.sortOrder.label) {
            openDropdown = .sort
        }
        .dropdownAnchor(HeaderDropdown.sort)
        .accessibilityLabel("Sort by \(viewModel.sortOrder.label)")
        .accessibilityHint("Opens sort options")
        .accessibilityIdentifier("sortOptions.items")
    }

    // MARK: - Filter

    /// Takes a request from another tab and turns it into this screen's own
    /// filter state, then clears it so a later re-appearance doesn't re-narrow
    /// a list the user has since changed.
    private func apply(_ request: AppRouter.ItemsRequest?) {
        guard let request else { return }

        // Whichever narrowing was asked for replaces the others, rather than
        // stacking on top of whatever happened to be set — arriving from the
        // dashboard should show what the dashboard pointed at, not that
        // intersected with a filter left over from last time.
        viewModel.searchText = ""
        switch request {
        case .category(let path):
            viewModel.categoryFilter = path
            viewModel.showsOnlyUnvalued = false
            chipToReveal = path
        case .unvalued:
            viewModel.categoryFilter = ""
            viewModel.showsOnlyUnvalued = true
            chipToReveal = Self.unvaluedChipID
        case .sold:
            // Becomes the single `viewModel.show(.sold)` call once the side
            // exists (T009/T015). Unreachable until then — nothing calls
            // `router.showSoldItems()` yet.
            break
        }
        router.clearItemsRequest()
    }

    /// The same `ScrollViewReader` treatment `CategoryPickerField` already
    /// uses, for the same reason: a single scrolling row hides any chip far
    /// enough along it, and alphabetically the interesting one usually is.
    ///
    /// Arriving from a dashboard drill-in was the case that made it necessary.
    /// The filter applied correctly and the chip lit up brass, both off the
    /// right edge — so the list looked narrowed for no reason a user could
    /// see. Same principle the un-valued chip is built on: a filter you can't
    /// see is worse than one you can't set. Found at T044.
    private var categoryChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if viewModel.showsOnlyUnvalued {
                        unvaluedChip.id(Self.unvaluedChipID)
                    }
                    chip(label: "All", path: "").id("")
                    ForEach(viewModel.categoryOptions, id: \.self) { path in
                        chip(label: viewModel.categoryLabels[path] ?? path, path: path)
                            .id(path)
                    }
                }
                .padding(.horizontal, theme.metrics.screenGutter)
            }
            .scrollClipDisabled()
            // Both hooks, because the request can land either before this row
            // exists (arriving on a tab that hasn't been shown yet) or while
            // it's already on screen. Whichever fires second finds the pending
            // chip already cleared.
            .onAppear { reveal(using: proxy) }
            .onChange(of: chipToReveal) { reveal(using: proxy) }
        }
    }

    private func applyAddItemRequest() {
        guard router.wantsAddItemForm else { return }
        isAddingItem = true
        router.clearAddItemRequest()
    }

    private func reveal(using proxy: ScrollViewProxy) {
        guard let chipToReveal else { return }
        proxy.scrollTo(chipToReveal, anchor: .center)
        self.chipToReveal = nil
    }

    /// The un-valued filter's own chip. It has no off-switch anywhere else —
    /// it arrives from the dashboard rather than from a control on this screen
    /// — and a filter the user can't see or clear is worse than one they can't
    /// set. Shown only while it's on, and tapping it clears it.
    private var unvaluedChip: some View {
        Button {
            viewModel.showsOnlyUnvalued = false
            viewModel.load()
        } label: {
            HStack(spacing: 6) {
                Text("Not yet valued")
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(theme.typography.secondary)
            .foregroundStyle(theme.colors.accentRustText)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(theme.colors.surface))
            .overlay(
                Capsule().strokeBorder(theme.colors.accentRust, lineWidth: theme.metrics.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear the not-yet-valued filter")
    }

    private func chip(label: String, path: String) -> some View {
        let isSelected = viewModel.categoryFilter == path && !viewModel.showsOnlyUnvalued

        return Button {
            viewModel.categoryFilter = path
            // Picking any category chip — "All" included — steps out of the
            // un-valued view, so "All" always means all.
            viewModel.showsOnlyUnvalued = false
            viewModel.load()
        } label: {
            CategoryPathLabel(
                path: label,
                separatorColor: isSelected ? theme.colors.accentBrass : theme.colors.textQuiet
            )
                .font(theme.typography.secondary)
                .foregroundStyle(isSelected ? theme.colors.accentBrass : theme.colors.textBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? theme.colors.accentBrassTint : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? theme.colors.accentBrass : theme.colors.divider,
                        lineWidth: theme.metrics.hairline
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Empty

    /// Four states, not one. Which applies is `ItemListViewModel`'s call; this
    /// only decides how each one looks and reads.
    ///
    /// The filtered empty states survive an in-progress import rather than
    /// being replaced by it — they're feedback on what the user just typed —
    /// so they say so instead of stating a narrower absence as final. See
    /// `ListEmptyReason.reason`'s precedence note.
    private func detail(_ base: String) -> String {
        ListEmptyReason.detail(base, mayStillBeImporting: viewModel.mayStillBeImporting)
    }

    /// Every case that was caused by a narrowing offers to undo that narrowing,
    /// rather than describing the situation and leaving the user to find the
    /// control that got them there. The un-valued case is the odd one and the
    /// reason it exists at all: it's what you land on after valuing the last
    /// item from the dashboard's callout, so it's a result, not a dead end, and
    /// reading "no gear yet" there was flatly wrong.
    ///
    /// `stillSyncing` is the one state with no action, because there isn't one
    /// — nothing here is the user's to fix, and offering a button would imply
    /// otherwise.
    @ViewBuilder
    private func emptyState(_ reason: ListEmptyReason) -> some View {
        switch reason {
        case .nothingAdded:
            EmptyStateView(
                mark: .asset("TabItems"),
                headline: "No gear yet",
                detail: "Add what you own and Trove tracks what you paid against what it's worth now.",
                action: .init(label: "Add an item", isProminent: true) { isAddingItem = true }
            )

        case .stillSyncing:
            EmptyStateView(
                mark: .stillSyncing,
                headline: "Catching up with iCloud",
                detail: "Your gear is on its way to this device. It'll appear here as it arrives."
            )

        case .searchMatchedNothing(let query):
            EmptyStateView(
                mark: .system("magnifyingglass"),
                headline: "No matches for \u{201C}\(query)\u{201D}",
                detail: detail("Names and serial numbers are what's searched."),
                action: .init(label: "Clear search") {
                    viewModel.searchText = ""
                    viewModel.load()
                }
            )

        case .categoryMatchedNothing:
            EmptyStateView(
                mark: .system("line.3.horizontal.decrease"),
                headline: "Nothing in this category",
                detail: detail("Everything else is still here — the filter is just narrow."),
                action: .init(label: "Show all items") {
                    viewModel.categoryFilter = ""
                    viewModel.load()
                }
            )

        // Placeholder until the Sold side itself lands (T015), which owns how
        // this state reads. Unreachable before then: only the Sold side's
        // `emptyReason` produces `.nothingSold`, and there is no Sold side yet.
        case .nothingSold:
            EmptyStateView(
                mark: .asset("TabItems"),
                headline: SaleCopy.emptyState
            )

        case .everythingIsValued:
            EmptyStateView(
                mark: .system("checkmark.circle"),
                headline: "Everything has a value",
                detail: "Nothing is left out of your totals. They're as complete as the values you've entered.",
                action: .init(label: "Show all items") {
                    viewModel.showsOnlyUnvalued = false
                    viewModel.load()
                }
            )
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.combinedSchema,
        configurations: ModelConfiguration(schema: TroveSchema.combinedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = ModelContext(container)
    for item in [
        Item(name: "Leica M6 (0.72x)", categoryPath: "Photography/Cameras",
             purchasePriceCents: 290_000, currentValueCents: 345_000, desireToKeep: 5),
        Item(name: "Fender Blues Junior IV", categoryPath: "Music/Amps",
             purchasePriceCents: 69_000, currentValueCents: 54_000, desireToKeep: 2),
        Item(name: "Squier Classic Vibe 50s", categoryPath: "Music/Guitars/Electric",
             purchasePriceCents: 38_000, desireToKeep: 1),
    ] {
        context.insert(item)
    }

    return NavigationStack {
        ItemListView(modelContext: context)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
