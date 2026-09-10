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

/// Browse the wishlist, per `design/screens/Trove Wishlist List.png`.
///
/// Follows the item list's standing layout rule from plan.md — title, summary,
/// search and chips stay fixed, only the rows scroll — so the two list screens
/// behave the same way.
///
/// **Design's per-row "59% / $990 short / $360 surplus" progress bars, and the
/// "SELLABLE VALUE AGAINST WISHLIST" card above them, are deliberately not
/// built.** spec.md rules out exactly that framing three times over: the Sell
/// Plan is "advisory, not a target to hit", "full cost covered, or explicitly
/// falling short" is named as the thing it must not imply, and an acceptance
/// criterion forbids text implying the user is expected to cover the full
/// cost. The mock's arithmetic also measures one sellable pool against every
/// wishlist item independently, so the same gear reads as funding all four.
struct WishlistView: View {
    @State private var viewModel: WishlistViewModel
    @State private var isAddingItem = false
    @State private var selectedItemID: UUID?

    /// Which header dropdown is open — Sort By or the "…" — or neither;
    /// see ItemListView's twin for why the screen owns it.
    @State private var openDropdown: HeaderDropdown?

    /// Whether 012's file picker is up — see `ItemListView`'s twin.
    @State private var isPickingImportFile = false

    /// Whether 013's Settings sheet is up — see `ItemListView`'s twin.
    @State private var isShowingSettings = false

    /// The row whose Edit swipe action is open in the form sheet — a
    /// shortcut into the same flow the detail screen offers (T024).
    @State private var itemBeingEdited: WishlistItem?

    /// The row a swipe has asked to delete, held until the alert resolves it.
    /// The swipe-then-tap gesture is a fine two-step on its own; what it
    /// can't do is *say* anything — and every other delete path in the app
    /// states the cascade/nullify asymmetry before committing, so this one
    /// does too.
    ///
    /// Until T016 this was fed by `.onDelete`, which also powered the
    /// edit-mode minus button; `.swipeActions` doesn't — and since T028a
    /// removed edit mode from this screen entirely, the swipe is simply the
    /// list's one delete gesture. T001's finding records the ordering call.
    @State private var pendingDeletion: WishlistItem?

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.storageMode) private var storageMode
    @Environment(\.storageFallbackReason) private var storageFallbackReason

    /// Kept for the Settings sheet — see `ItemListView`'s twin.
    private let syncMonitor: SyncMonitor

    init(modelContext: ModelContext, syncMonitor: SyncMonitor = .notSyncing) {
        self.syncMonitor = syncMonitor
        _viewModel = State(
            initialValue: WishlistViewModel(modelContext: modelContext, syncMonitor: syncMonitor)
        )
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: theme.metrics.controlRowGap) {
                    header
                        .padding(.horizontal, theme.metrics.screenGutter)
                        .padding(.bottom, theme.metrics.sectionGap - theme.metrics.controlRowGap)

                    // Controls for narrowing a list need a list to narrow.
                    // On a first run they were a search field over nothing and
                    // a lone "All" chip, both of which made the screen look
                    // like it had lost something rather than not started yet.
                    if viewModel.totalCount > 0 {
                        SearchField(placeholder: "Search wishlist", text: $viewModel.searchText)
                            .padding(.horizontal, theme.metrics.screenGutter)

                        categoryChips
                    }
                }
                .padding(.top, theme.metrics.sectionGap)
                .padding(.bottom, theme.metrics.listRowGap)
                .background(theme.colors.background)

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
            AddButton(label: "Add wanted item") { isAddingItem = true }
                .padding(.trailing, theme.metrics.screenGutter)
                .padding(.bottom, theme.metrics.sectionGap)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        // The item's own screen is the only thing this list pushes. The Sell
        // Plan is reached from there, not from here — `WishlistDetailView`
        // declares that destination.
        .navigationDestination(item: $selectedItemID) { itemID in
            WishlistDetailView(modelContext: modelContext, itemID: itemID)
        }
        .sheet(isPresented: $isAddingItem, onDismiss: viewModel.load) {
            NavigationStack { WishlistFormView(modelContext: modelContext) }
        }
        // The Edit swipe's sheet (T024), refetching on dismiss like the add
        // sheet above.
        .sheet(item: $itemBeingEdited, onDismiss: viewModel.load) { item in
            NavigationStack {
                WishlistFormView(modelContext: modelContext, editing: item)
            }
        }
        // 013's Settings sheet — ItemListView's twin, refetching on dismiss
        // so a Delete All behind it shows here at once.
        .sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load) {
            NavigationStack {
                SettingsView(
                    modelContext: modelContext,
                    syncMonitor: syncMonitor,
                    storageMode: storageMode,
                    storageFallbackReason: storageFallbackReason
                )
            }
        }
        // Values can change on the detail screen — an edit, the gauge, or a
        // deletion — so the list refetches whenever it comes back into view.
        .onAppear(perform: viewModel.load)
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
        // same action — both read from WishlistDeleteCopy, so they can't
        // drift. An alert rather than a confirmation dialog for the same
        // reason the detail screens chose one.
        .alert(
            WishlistDeleteCopy.title(for: pendingDeletion?.name ?? "this item"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { item in
            Button(WishlistDeleteCopy.confirm, role: .destructive) {
                viewModel.delete(id: item.id)
            }
            Button(WishlistDeleteCopy.cancel, role: .cancel) {}
        } message: { _ in
            Text(WishlistDeleteCopy.message)
        }
        .onChange(of: viewModel.searchText) { viewModel.load() }
        // 011's share sheet and failure alert — ItemListView's twins, off
        // the same view-model state shape.
        .sheet(item: $viewModel.stagedExport) { staged in
            ShareSheet(urls: staged.urls)
                .presentationDetents([.medium, .large])
        }
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
        // 012's file picker and import alert — ItemListView's twins; see
        // the notes there (cancel-safe by construction, one presentation
        // optional, dismiss-only when nothing is importable).
        .fileImporter(
            isPresented: $isPickingImportFile,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            if case .success(let url) = result {
                Task { await viewModel.importCSV(from: url) }
            }
        }
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
        // The header's dropdowns — the same shared host as ItemListView's,
        // for the same reach reasons (013 Amendment A).
        .dropdownHost(open: $openDropdown, dismissLabel: \.dismissLabel) { dropdown in
            switch dropdown {
            case .sort:
                SortDropdown(
                    options: WishlistViewModel.SortOrder.allCases,
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Wishlist")
                    .font(theme.typography.screenTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(summaryLine).monoLabel()
            }

            Spacer()

            // The "…" shows regardless of collection size since 012
            // (criterion 1, superseding 011's hide-when-empty); the sort
            // badge still hides — see ItemListView's header note.
            HStack(spacing: 8) {
                if viewModel.totalCount > 0 {
                    sortControl
                }
                overflowControl
            }
        }
    }

    /// 012's overflow — ItemListView's twin.
    private var overflowControl: some View {
        OverflowBadge(isBusy: viewModel.isBusy) {
            openDropdown = .overflow
        }
        .dropdownAnchor(HeaderDropdown.overflow)
        .accessibilityIdentifier("moreActions.wishlist")
    }

    /// Design's "4 WANTED · $4,740".
    private var summaryLine: String {
        let count = viewModel.items.count
        return "\(count) wanted · "
            + viewModel.totalEstimatedCostCents.formattedAsWholeCurrency(currencyCode: "USD")
    }

    /// T035's badge — one control on both screens; see `SortBadge` and
    /// ItemListView's twin for the note on why the system `Menu` left.
    private var sortControl: some View {
        SortBadge(label: viewModel.sortOrder.label) {
            openDropdown = .sort
        }
        .dropdownAnchor(HeaderDropdown.sort)
        .accessibilityLabel("Sort by \(viewModel.sortOrder.label)")
        .accessibilityHint("Opens sort options")
        .accessibilityIdentifier("sortOptions.wishlist")
    }

    // MARK: - Rows

    /// A `List` purely for `onMove`; everything visible is overridden so it
    /// reads as the same card stack the item list draws with a `LazyVStack`.
    private var rows: some View {
        List {
            ForEach(viewModel.items, id: \.id) { item in
                WishlistRow(item: item, trend: viewModel.trend(for: item.id))
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
                    // Opens the item, not the form. Tapping a row used to jump
                    // straight to editing because there was nowhere else to
                    // go; now that the detail screen exists it's the row's
                    // destination, and editing is one step further in — the
                    // same shape as the item list.
                    .onTapGesture { selectedItemID = item.id }
                    // `.swipeActions` rather than `.onDelete` (T016), so both
                    // lists delete through one mechanism — and so T036 can put
                    // custom iconography in a button `.onDelete` doesn't let
                    // anyone touch. Stages, never deletes; the alert commits
                    // through the view model.
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = item
                        } label: {
                            // Design's own glyphs (T036) — see ItemListView's
                            // twin buttons.
                            Label { Text(WishlistDeleteCopy.confirm) } icon: { Image("ActionDelete") }
                        }
                        // Explicit, not redundant — see ItemListView's swipe
                        // action: the root brass .tint cascades in here and
                        // overrides the destructive role's red, so each
                        // swipe button carries its own tokens.md color.
                        .tint(theme.colors.accentRust)
                    }
                    // Same order, tints, and "Copy" string as ItemListView's
                    // leading swipe (T023) — one pattern, both lists.
                    .swipeActions(edge: .leading) {
                        Button {
                            itemBeingEdited = item
                        } label: {
                            Label { Text("Edit") } icon: { Image("ActionEdit") }
                        }
                        .tint(theme.colors.divider)
                        Button {
                            viewModel.duplicate(id: item.id)
                        } label: {
                            Label { Text("Copy") } icon: { Image("ActionDuplicate") }
                        }
                        .tint(theme.colors.surfaceInset)
                    }
                    // Same named actions as ItemListView's rows, for the
                    // same reason — one accessible reorder pattern on both
                    // screens, replacing the edit-mode path the Reorder
                    // button used to provide (T028a/T028b). Gated on
                    // `canReorder` alone, never on the row's position: this
                    // block's structure must not change while a drag
                    // settles, or the List paints the pre-drag order over
                    // the committed move (T029b's bisect). The ends of the
                    // list are handled inside `moveUp`/`moveDown`, which
                    // no-op there.
                    .accessibilityActions {
                        if viewModel.canReorder {
                            Button("Move up") { viewModel.moveUp(id: item.id) }
                            Button("Move down") { viewModel.moveDown(id: item.id) }
                        }
                    }
            }
            // Attached only while Custom is the active, unnarrowed view —
            // `nil` detaches the gesture entirely, so reordering is hidden,
            // not just disabled, everywhere it wouldn't be meaningful. Same
            // pattern as ItemListView's, since T028a unified the two screens;
            // the view model's guard stays as the second line of defense.
            .onMove(perform: viewModel.canReorder ? { source, destination in
                viewModel.move(fromOffsets: source, toOffset: destination)
            } : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // No bottom margin, deliberately. The add button and the tab bar are
        // meant to sit over the last row or two when scrolled fully down —
        // that overlap is what gives iOS 26's glass material something to
        // refract. A margin here would buy clearance at the cost of the
        // effect it exists to enable. plan.md says so explicitly, because
        // this was once "fixed" the other way.
    }

    // MARK: - Filter

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", path: "")
                ForEach(viewModel.categoryOptions, id: \.self) { path in
                    chip(label: viewModel.categoryLabels[path] ?? path, path: path)
                }
            }
            .padding(.horizontal, theme.metrics.screenGutter)
        }
        .scrollClipDisabled()
    }

    private func chip(label: String, path: String) -> some View {
        let isSelected = viewModel.categoryFilter == path

        return Button {
            viewModel.categoryFilter = path
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

    /// See `ItemListView.detail(_:)` — the filtered cases keep their context
    /// mid-import and say they may be incomplete, rather than being replaced.
    private func detail(_ base: String) -> String {
        ListEmptyReason.detail(base, mayStillBeImporting: viewModel.mayStillBeImporting)
    }

    /// Every case the item list has except the un-valued one, which can't
    /// arise here — nothing on a wishlist is owned yet, so nothing on it has a
    /// value to be missing. The shared `ListEmptyReason` is still what decides
    /// which, so the two screens can't end up disagreeing about what "empty"
    /// means.
    ///
    /// The copy differs from the item list's throughout, because the wishlist
    /// is about wanting rather than owning and "no gear yet" would be the wrong
    /// sentence on a screen that never holds gear.
    @ViewBuilder
    private func emptyState(_ reason: ListEmptyReason) -> some View {
        switch reason {
        case .stillSyncing:
            EmptyStateView(
                mark: .stillSyncing,
                headline: "Catching up with iCloud",
                detail: "Your list is on its way to this device. It'll appear here as it arrives."
            )

        case .nothingAdded, .everythingIsValued:
            EmptyStateView(
                mark: .asset("TabWishlist"),
                headline: "Nothing on the list yet",
                detail: "Keep track of what you're after, and Trove can work out which gear could fund it.",
                action: .init(label: "Add something you want", isProminent: true) { isAddingItem = true }
            )

        case .searchMatchedNothing(let query):
            EmptyStateView(
                mark: .system("magnifyingglass"),
                headline: "No matches for \u{201C}\(query)\u{201D}",
                detail: detail("Only names are searched here."),
                action: .init(label: "Clear search") {
                    viewModel.searchText = ""
                    viewModel.load()
                }
            )

        case .categoryMatchedNothing:
            EmptyStateView(
                mark: .system("line.3.horizontal.decrease"),
                headline: "Nothing in this category",
                detail: detail("The rest of your list is still here — the filter is just narrow."),
                action: .init(label: "Show the whole list") {
                    viewModel.categoryFilter = ""
                    viewModel.load()
                }
            )
        }
    }
}

/// One wishlist row: what it is, its category, and what it's expected to cost.
///
/// **No per-row Sell Plan shortcut.** One was drawn by Design, built, and
/// removed after seeing it: a CTA repeated down every row pushes harder toward
/// the Sell Plan than the goal-completion framing that was already cut from
/// the plan screen itself — the same over-prominence in another form. The plan
/// is reached from `WishlistDetailView`'s button alone, one tap further in,
/// which is the right trade for something meant to stay quietly available.
/// See spec.md's Sell Plan section.
private struct WishlistRow: View {
    let item: WishlistItem

    /// The market trend for this wanted item, from the list's own view model
    /// (002/T012) — the row's only market mark (spec Decision 8).
    var trend: MarketTrend?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.rowContentGap) {
            RowThumbnail(photos: item.photos ?? [])

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)

                Text(CategoryPathHelper.trailingSegments(of: item.categoryPath).joined(separator: " · "))
                    .monoLabel()
                    .lineLimit(1)

                if let notes = item.notes {
                    Text(notes)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textQuiet)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Cost leads at the top, the gauge sits quietly at the bottom —
            // the brief puts it in the row's lower-right, unlabeled. The
            // thumbnail sets the row's height, so this column has the space
            // for both without the row growing.
            VStack(alignment: .trailing, spacing: 0) {
                // The arrow *after* the cost, so the cost's own explicit
                // label still reads first in the combined row (plan §6).
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                        .accessibilityLabel("Estimated cost \(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))")

                    TrendArrow(trend: trend)
                }

                Spacer(minLength: theme.metrics.fieldGap)

                // Legended per row since `010`'s stepped-ramp redesign — a
                // deliberate reversal of `001`'s "unlabeled in list rows"
                // call; tokens.md and plan.md's Resolved decisions carry it.
                DesireGauge(value: .constant(item.desireToOwn), showsLegend: true)
            }
        }
        // One element again. It was split apart while the row held a button,
        // which combining would have swallowed; with nothing to reach in here,
        // a single description reads better than five fragments.
        .accessibilityElement(children: .combine)
        // A stock-leading row announces its thumbnail as representative, not as
        // the person's own (criterion 11). An empty value adds nothing to a
        // normal row's combined label. Same predicate as the visible mark.
        .accessibilityValue(PhotoSelection.leadsWithStock(item.photos ?? [])
            ? StockPhotoCopy.badgeAccessibilityLabel : "")
        .padding(theme.metrics.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .extrudedPlate()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.combinedSchema,
        configurations: ModelConfiguration(schema: TroveSchema.combinedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = ModelContext(container)
    for (index, wanted) in [
        WishlistItem(name: "Leica Summicron 35mm f/2 (v4)", categoryPath: "Photography/Lenses",
                     estimatedCostCents: 240_000, notes: "v4 only", desireToOwn: 3),
        WishlistItem(name: "Vox AC15 Custom", categoryPath: "Music/Amps",
                     estimatedCostCents: 105_000),
        WishlistItem(name: "Hasselblad 80mm f/2.8 CF", categoryPath: "Photography/Lenses",
                     estimatedCostCents: 95_000),
    ].enumerated() {
        wanted.sortOrder = index
        context.insert(wanted)
    }

    return NavigationStack {
        WishlistView(modelContext: context)
    }
    .environment(\.theme, .dark)
    .environment(SyncMonitor.notSyncing)
    .preferredColorScheme(.dark)
}
