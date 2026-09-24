import SwiftData
import SwiftUI

/// The header's dropdowns. An optional of this type is the screen's whole
/// open-menu state — the list screens' shape (013 Amendment A): Sort By, and
/// since Amendment A the "…" holding Settings (009 plan QA3, revising R6).
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

/// The Plans tab (009 plan §11): every sell plan, split into the ones still
/// waiting on their purchase and the ones whose wanted item has been bought.
///
/// `WishlistView`'s file shape with only what the spec asks for — a fixed
/// header with the sort badge and the "…", the Active / Completed switch under
/// it, then the empty state or the rows. The "…" holds Settings alone (plan
/// QA3, Amendment A's criterion 21 — every tab reaches Settings). No search,
/// no category chips, no summary line, and no money anywhere (plan Q8,
/// criterion 8). The row value alone doesn't guarantee that — a row's
/// photos reach their item, and so its prices, through `Photo.item` — so
/// what keeps money off the screen is `PlansWiringTests`'
/// `theScreenDrawsNoMoneyAndReachesNoStore`.
struct PlansView: View {
    @State private var viewModel: PlansViewModel

    /// Which header dropdown is open, or neither — see `ItemListView`'s twin.
    @State private var openDropdown: HeaderDropdown?

    /// The row whose Buy swipe is open in the purchase sheet (plan Q13) —
    /// `WishlistView`'s `itemBeingBought` staging, over the plan's row.
    @State private var planBeingBought: PlansViewModel.PlanRow?

    /// The row a swipe has asked to delete, held until the alert resolves it
    /// — the swipe stages, the alert commits through the view model (Q12).
    @State private var pendingDeletion: PlansViewModel.PlanRow?

    /// Amendment A (plan QA3): the "…" opens Settings, as on the other tabs.
    @State private var isShowingSettings = false

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.storageMode) private var storageMode
    @Environment(\.storageFallbackReason) private var storageFallbackReason
    /// 004: threaded into the Settings sheet — see `ItemListView`'s twin.
    @Environment(AppearanceStore.self) private var appearanceStore
    /// 004 (T009): the resolved scheme under `ThemedRoot` — see `ItemListView`'s twin.
    @Environment(\.colorScheme) private var systemColorScheme

    /// Kept for the Sell Plan screens this tab pushes and for the Settings
    /// sheet, which take the monitor the way this screen does.
    private let syncMonitor: SyncMonitor

    init(modelContext: ModelContext, syncMonitor: SyncMonitor = .notSyncing) {
        self.syncMonitor = syncMonitor
        _viewModel = State(
            initialValue: PlansViewModel(modelContext: modelContext, syncMonitor: syncMonitor)
        )
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: theme.metrics.controlRowGap) {
                    header
                        .padding(.horizontal, theme.metrics.screenGutter)

                    // In the standing header, so it is there over an empty
                    // side exactly as over a full one — `ItemListView`'s
                    // placement. Never bound to `side`: a tap asks `show(_:)`,
                    // which sets the side and reloads, and clears nothing, so
                    // each side keeps its own sort (criterion 5).
                    SideSwitch(side: viewModel.side, select: { viewModel.show($0) })
                        .padding(.horizontal, theme.metrics.screenGutter)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        // The one destination for this stack, and the only push mechanism:
        // row taps go through the router's bound `plansPath`, so the
        // Dashboard's `showActivePlans()` pop clears whatever is open —
        // `ItemListView`'s T039 lesson. The Sell Plan decides for itself
        // whether it is the live plan or the completed record.
        .navigationDestination(for: UUID.self) { wishlistItemID in
            SellPlanView(modelContext: modelContext, wishlistItemID: wishlistItemID, syncMonitor: syncMonitor)
        }
        // The Buy swipe's sheet (plan Q13): the shared purchase form, seeded
        // by the view model exactly as the other three hosts seed theirs,
        // over the staged row so two rows can never both be being bought.
        // The write is `markBought`'s; the reload on dismiss moves the row to
        // Completed (criterion 14).
        .sheet(item: $planBeingBought, onDismiss: viewModel.load) { row in
            PurchaseFormView(
                viewModel: viewModel.makePurchaseFormViewModel(for: row),
                confirm: { purchase in
                    viewModel.markBought(row, purchase: purchase)
                    planBeingBought = nil
                },
                cancel: { planBeingBought = nil }
            )
        }
        // Values change on the Sell Plan behind a row — a selection, a sale, a
        // purchase, a deleted plan — so the list refetches whenever it comes
        // back into view. The Dashboard's request is applied first, so the
        // load reads the side it asked for.
        .onAppear {
            applyActivePlansRequest()
            viewModel.load()
        }
        .onChange(of: router.wantsActivePlans) { applyActivePlansRequest() }
        // An import landing, or the carry-over finishing, changes what this
        // screen should show, and nothing else tells it (plan Q3).
        .onChange(of: viewModel.completedImports) { viewModel.load() }
        .onChange(of: viewModel.settledCount) { viewModel.load() }
        // Pull to refresh — the list screens' twin: the same load(), held
        // open by RefreshPacing so the list doesn't snap back under the
        // spinner.
        .refreshable {
            viewModel.load()
            await RefreshPacing.hold()
        }
        // The delete alert (Q12): one sentence frame whose one clause names
        // what stays — the wishlist entry on Active, the bought item on
        // Completed — read from the row being deleted.
        .alert(
            SellPlanCopy.deleteTitle(for: pendingDeletion?.name ?? SellPlanCopy.deleteTitleFallbackName),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { row in
            Button(SellPlanCopy.deleteConfirm, role: .destructive) {
                viewModel.deletePlan(id: row.id)
            }
            Button(SellPlanCopy.deleteCancel, role: .cancel) {}
        } message: { row in
            Text(SellPlanCopy.deleteMessage(isCompleted: row.isCompleted))
        }
        // A refused purchase says so — `WishlistView`'s alert, `015` T012b.
        .alert(
            PurchaseCopy.failureTitle,
            isPresented: Binding(
                get: { viewModel.purchaseFailureMessage != nil },
                set: { if !$0 { viewModel.purchaseFailureMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.purchaseFailureMessage ?? PurchaseCopy.failureMessage)
        }
        // The Settings sheet, reached from the "…" since Amendment A — the
        // Dashboard's block. The dismissal runs the same load appear does, so
        // a Delete all behind it empties this list at once.
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
            // 004 (T009): the sheet adopts the resolved scheme so a live
            // appearance switch follows — see `ItemListView`'s twin.
            .preferredColorScheme(appearanceStore.choice.sheetColorScheme(device: systemColorScheme))
        }
        // The header's dropdowns, through the shared host (013 Amendment A).
        // Sort By is one badge over two selections: the side on screen picks
        // which orders it offers and which it writes. No REORDER tag on
        // either — a plan list has no manual order to drag into (plan P5).
        .dropdownHost(open: $openDropdown, dismissLabel: \.dismissLabel) { dropdown in
            switch dropdown {
            case .overflow:
                // Settings alone (plan QA3): plans are in no export, so
                // Export and Import stay the lists'. A one-row menu, as on
                // the Dashboard (013 P13).
                DropdownSurface {
                    DropdownRow(title: "Settings") {
                        isShowingSettings = true
                    }
                }
            case .sort:
                switch viewModel.side {
                case .active:
                    SortDropdown(
                        options: PlansViewModel.ActiveSortOrder.allCases,
                        selection: viewModel.activeSortOrder,
                        label: \.label,
                        isManualOrder: { _ in false }
                    ) { option in
                        // The row has already closed the dropdown. The intent
                        // sets this side's order and reloads the rows.
                        viewModel.setActiveSort(option)
                    }
                case .completed:
                    SortDropdown(
                        options: PlansViewModel.CompletedSortOrder.allCases,
                        selection: viewModel.completedSortOrder,
                        label: \.label,
                        isManualOrder: { _ in false }
                    ) { option in
                        viewModel.setCompletedSort(option)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text(SellPlanCopy.tab)
                .font(theme.typography.screenTitle)
                .foregroundStyle(theme.colors.textPrimary)

            Spacer()

            // `WishlistView`'s pair. Sort is hidden over an empty side, as on
            // the list screens — there is nothing to order; the "…" always
            // shows, since Settings is never gated (plan QA3).
            HStack(spacing: 8) {
                if !viewModel.rows.isEmpty {
                    sortControl
                }
                overflowControl
            }
        }
    }

    /// Never busy: nothing runs from this tab. The badge only opens the
    /// one-row menu on the host — the Dashboard's twin.
    private var overflowControl: some View {
        OverflowBadge(isBusy: false) {
            openDropdown = .overflow
        }
        .dropdownAnchor(HeaderDropdown.overflow)
        .accessibilityIdentifier("moreActions.plans")
    }

    /// T035's badge — `ItemListView`'s twin, naming the side on screen's
    /// selection.
    private var sortControl: some View {
        SortBadge(label: viewModel.visibleSortLabel) {
            openDropdown = .sort
        }
        .dropdownAnchor(HeaderDropdown.sort)
        .accessibilityLabel("Sort by \(viewModel.visibleSortLabel)")
        .accessibilityHint("Opens sort options")
        .accessibilityIdentifier("sortOptions.plans")
    }

    // MARK: - Rows

    /// A `List` for the swipe actions, with everything visible overridden so
    /// it reads as the list screens' card stack — `WishlistView.rows`' styling
    /// line for line.
    private var rows: some View {
        List {
            ForEach(viewModel.rows) { row in
                PlanRowView(row: row)
                    // The screen's own background, as on the list screens.
                    .listRowBackground(theme.colors.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: theme.metrics.listRowGap / 2,
                        leading: theme.metrics.listRowInset,
                        bottom: theme.metrics.listRowGap / 2,
                        trailing: theme.metrics.listRowInset
                    ))
                    // The whole row is the tap target, not only its text.
                    .contentShape(Rectangle())
                    // Pushed through the router's bound path, so a cross-tab
                    // pop can clear it — `ItemListView`'s twin.
                    .onTapGesture { router.plansPath.append(row.id) }
                    // Both sides delete the same way (Q12). Stages, never
                    // deletes; the alert commits through the view model.
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = row
                        } label: {
                            Label { Text(SellPlanCopy.deleteConfirm) } icon: { Image("ActionDelete") }
                        }
                        // Explicit, not redundant: the root brass .tint
                        // cascades in here and overrides the destructive
                        // role's red (tokens.md, "Destructive actions").
                        .tint(theme.colors.accentRust)
                    }
                    // Buy from a row, Active rows only (Q13) — a completed
                    // plan's item is already bought, so its row has no
                    // leading swipe at all. The Wishlist's Buy button exactly:
                    // "Buy" on screen, `markAsBought` spoken, the brass
                    // mid-tone.
                    .swipeActions(edge: .leading) {
                        if viewModel.side == .active {
                            Button {
                                planBeingBought = row
                            } label: {
                                Label { Text(PurchaseCopy.swipeBuy) } icon: { Image("ActionBuy") }
                            }
                            .tint(theme.colors.accentBrassMid)
                            .accessibilityLabel(PurchaseCopy.markAsBought)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // No bottom margin — the list screens' reason: the tab bar sits over
        // the last row when scrolled fully down, for the glass to refract.
    }

    // MARK: - Empty

    /// The view model's four reasons (plan Q10), each saying what is actually
    /// missing (criterion 16). No action on any: the Plans tab adds nothing
    /// itself — a plan starts from a wishlist entry, which the copy names.
    @ViewBuilder
    private func emptyState(_ reason: PlansViewModel.EmptyReason) -> some View {
        switch reason {
        case .stillSyncing:
            EmptyStateView(
                mark: .stillSyncing,
                headline: "Catching up with iCloud",
                detail: SellPlanCopy.stillSyncingDetail
            )

        case .noPlans:
            EmptyStateView(
                mark: .asset("TabPlans"),
                headline: SellPlanCopy.noPlansHeadline,
                detail: SellPlanCopy.noPlansDetail
            )

        case .nothingWanted:
            EmptyStateView(
                mark: .asset("TabWishlist"),
                headline: SellPlanCopy.nothingWantedHeadline,
                detail: SellPlanCopy.nothingWantedDetail
            )

        case .nothingCompleted:
            EmptyStateView(
                mark: .asset("TabPlans"),
                headline: SellPlanCopy.nothingCompletedHeadline,
                detail: SellPlanCopy.nothingCompletedDetail
            )
        }
    }

    // MARK: - Requests

    /// The Dashboard's Plans card asks for the Active side; this screen owns
    /// the side, so it applies the request and clears it — a later visit then
    /// keeps whichever side the person has since chosen.
    private func applyActivePlansRequest() {
        guard router.wantsActivePlans else { return }
        viewModel.show(.active)
        router.clearPlansRequest()
    }
}

/// One plan row: `WishlistRow`'s head — thumbnail, name, category — with the
/// row's count lines stacked beneath.
///
/// **The view decides nothing about which lines show**: `row.lines` is
/// `SellPlanSummary.rowLines`, chosen in the view model (plan Q5), so this
/// draws what it is handed. No trailing column, no gauge, no figure — a plan
/// row shows counts, never money (criterion 8).
private struct PlanRowView: View {
    let row: PlansViewModel.PlanRow

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.rowContentGap) {
            // Every row, on both sides (Amendment A, criterion 20): the view
            // model chose whose photos these are, and an empty array draws
            // the placeholder — one shape for every row, as `WishlistRow`.
            RowThumbnail(photos: row.photos)

            VStack(alignment: .leading, spacing: 5) {
                Text(row.name)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)

                Text(CategoryPathHelper.trailingSegments(of: row.categoryPath).joined(separator: " · "))
                    .monoLabel()
                    .lineLimit(1)

                // `015` T011b's house pairing for a quiet line under a title.
                ForEach(row.lines, id: \.self) { line in
                    Text(line)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.colors.textQuiet)
                }
            }

            Spacer(minLength: 0)
        }
        // One element, as the wishlist row is.
        .accessibilityElement(children: .combine)
        // A stock-leading thumbnail is announced as representative, as on
        // the wishlist row. Same predicate as the visible mark.
        .accessibilityValue(PhotoSelection.leadsWithStock(row.photos)
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
                     estimatedCostCents: 240_000),
        WishlistItem(name: "Vox AC15 Custom", categoryPath: "Music/Amps",
                     estimatedCostCents: 105_000),
    ].enumerated() {
        wanted.sortOrder = index
        context.insert(wanted)
        _ = SellPlanStore.create(for: wanted, at: .now)
    }

    return NavigationStack {
        PlansView(modelContext: context)
    }
    .environment(\.theme, .dark)
    .environment(AppRouter())
    .environment(SyncMonitor.notSyncing)
    .environment(AppearanceStore())
    .preferredColorScheme(.dark)
}
