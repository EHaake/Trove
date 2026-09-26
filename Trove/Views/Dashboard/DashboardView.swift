import SwiftData
import SwiftUI

/// The root Dashboard's dropdowns (013 Amendment A). One optional of this
/// type is the screen's whole open-menu state. The "…" left it at `018` for
/// a system menu of its own (`OverflowMenu`); the order control's dropdown
/// is what remains.
private enum DashboardDropdown: Hashable {
    case order

    /// What the tap-outside layer calls itself to VoiceOver.
    var dismissLabel: String {
        switch self {
        case .order: "Dismiss order options"
        }
    }
}

/// The overview screen, per `design/screens/Trove Dashboard.png`: what the
/// collection is worth, what it cost, what's missing from that figure, and how
/// it splits by category.
///
/// Also serves the category drill-down spec.md asks for — "the same numbers
/// scoped to it". Tapping a breakdown row pushes this same view with a
/// narrower scope, so "what have I spent on guitars specifically" is the
/// overview again rather than a second screen that could drift from it.
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var openDropdown: DashboardDropdown?
    /// 013 Amendment A: the "…" the mock always drew, holding Settings.
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

    /// Kept for the Settings sheet as well as the view model: constructor-
    /// injected the way `ContentView` injects this screen — one delivery
    /// mechanism for the monitor, never a sheet reading an observable it
    /// might not have.
    private let syncMonitor: SyncMonitor

    init(modelContext: ModelContext, scope: String = "", syncMonitor: SyncMonitor = .notSyncing) {
        self.syncMonitor = syncMonitor
        _viewModel = State(
            initialValue: DashboardViewModel(modelContext: modelContext, scope: scope, syncMonitor: syncMonitor)
        )
    }

    private var isRoot: Bool { viewModel.scope.isEmpty }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            // The empty state skips the scroll view entirely: there's nothing to
            // scroll, and a centred block only reads as centred if it has the
            // whole screen under the header to centre within. Inside the
            // scroll, it sized to its own content and sat a third of the way
            // down. Same shape as the two list screens.
            if viewModel.isEmpty {
                VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                    header
                        .padding(.horizontal, theme.metrics.screenGutter)
                        .padding(.top, theme.metrics.sectionGap)
                    emptyState
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                        header
                        headline
                        // Both figures cover valued items only, so with nothing
                        // valued this card is "$0 spent, $0 gain" — two false
                        // statements where the honest answer is that there's
                        // nothing to compare yet. The callout below says so.
                        if viewModel.hasAnyValues {
                            spentAndGain
                        }
                        if viewModel.unvaluedCount > 0 {
                            unvaluedCallout
                        }
                        // 006 §6: a ledger of its own, below the collection's
                        // figures and above the breakdown — never inside
                        // `spentAndGain` or the headline, which is what "sits
                        // apart" means structurally. It follows the scope,
                        // like every other figure here, and is simply absent
                        // when nothing in scope has been sold.
                        if viewModel.hasSales {
                            SoldCard(
                                line: viewModel.soldLine,
                                deltaLine: viewModel.soldDeltaLine,
                                realisedDeltaCents: viewModel.soldTotals.realisedDeltaCents
                            ) {
                                router.showSoldItems()
                            }
                        }
                        // 009 §12: directly below the Sold card, and inside
                        // this non-empty branch like it — the first-run
                        // Dashboard shows no card even with a plan on file
                        // (spec Decision 12). The gate itself hides it at
                        // zero and in a drill-down.
                        if viewModel.showsPlansCard {
                            PlansCard(line: viewModel.plansLine) {
                                router.showActivePlans()
                            }
                        }
                        breakdown
                    }
                    .padding(.horizontal, theme.metrics.screenGutter)
                    .padding(.top, theme.metrics.sectionGap)
                    .padding(.bottom, theme.metrics.sectionGap)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(isRoot ? .hidden : .automatic, for: .navigationBar)
        .navigationDestination(for: DashboardScope.self) { destination in
            DashboardView(modelContext: modelContext, scope: destination.path, syncMonitor: syncMonitor)
        }
        // Values change on the item screens, so the figures refetch whenever
        // this comes back into view.
        .onAppear(perform: viewModel.load)
        // An import landing while this screen is open changes what it should
        // show, and nothing else tells it — the view models fetch on appear
        // and hold an array rather than observing the store.
        .onChange(of: viewModel.completedImports) { viewModel.load() }
        // 009 Q3: a carry-over that landed on a failed setup moves no import
        // count, so the launch tab would keep a stale zero without this.
        .onChange(of: viewModel.settledCount) { viewModel.load() }
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
        // 013's Settings sheet, reached from the root "…" since Amendment A.
        // Owned here like the lists own theirs, for the same reason: a
        // Delete All behind it has to show on this screen the moment it
        // comes back — the sheet's dismissal runs the same load appear does.
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
        // The order control's dropdown floats over the whole screen from
        // here — the same host as the lists' had (013 Amendment A). The
        // header scrolls on this screen, which is exactly why the host finds
        // the control by its anchor rather than by a fixed offset.
        .dropdownHost(open: $openDropdown, dismissLabel: \.dismissLabel) { dropdown in
            switch dropdown {
            case .order:
                // The same surface and rows Sort By is made of, under its
                // own header (spec P12): the current order tinted and
                // checked, no REORDER tag — there is no manual order here.
                DropdownSurface(title: "ORDER BY") {
                    ForEach(DashboardViewModel.BreakdownOrder.allCases) { order in
                        DropdownRow(title: order.label, isSelected: order == viewModel.breakdownOrder) {
                            viewModel.breakdownOrder = order
                            viewModel.load()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    /// The wordmark and its meta line — and, on the root alone, the "…"
    /// Design's mock drew at the top-right, built at 013 Amendment A: the
    /// lists' bordered pill (spec P8), always visible, empty state included,
    /// since both branches of `body` compose this header. The drill-down is
    /// the same screen narrowed, with a navigation bar; one entry per tab.
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                if isRoot {
                    Text("TROVE")
                        .font(theme.typography.wordmark)
                        .tracking(theme.metrics.wordmarkTracking)
                        .foregroundStyle(theme.colors.textPrimary)
                } else {
                    CategoryPathLabel(path: viewModel.scope)
                        .font(theme.typography.screenTitle)
                        .foregroundStyle(theme.colors.textPrimary)
                }

                Text(headerMeta).monoLabel()
            }

            Spacer()

            if isRoot {
                overflowControl
            }
        }
    }

    /// Never busy: nothing runs from the Dashboard. One row, deliberately a
    /// menu rather than a direct button (spec P13): the roadmap's Dashboard
    /// exports land here. A system menu since `018` (plan §2).
    private var overflowControl: some View {
        OverflowMenu(isBusy: false) {
            Button("Settings") { isShowingSettings = true }
        }
        .accessibilityIdentifier("moreActions.dashboard")
    }

    /// Design's "34 ITEMS · 4 CATEGORIES".
    private var headerMeta: String {
        let items = viewModel.totalItemCount
        var parts = ["\(items) \(items == 1 ? "item" : "items")"]

        let categories = viewModel.categoryCount
        if categories > 0 {
            parts.append("\(categories) \(categories == 1 ? "category" : "categories")")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Headline figure

    /// With nothing valued there is no figure to print, and "$0" would be a
    /// claim rather than a gap — the same distinction `ItemRow` and the sort
    /// order already make between un-valued and worthless. The ruler goes with
    /// it: it measures how much of the total is accounted for, and a 0% reading
    /// under a non-figure is an instrument pointing at nothing.
    private var headline: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("Current value").monoLabel()

            if viewModel.hasAnyValues {
                HStack(alignment: .top, spacing: 4) {
                    Text(verbatim: Currency.symbol(for: "USD"))
                        .font(theme.typography.heroFigureSymbol)
                        .foregroundStyle(theme.colors.accentBrass)
                        .padding(.top, 10)

                    Text(viewModel.totalCurrentValueCents.formattedAsWholeAmount)
                        .font(theme.typography.heroFigureDashboard)
                        .foregroundStyle(theme.colors.accentBrass)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .accessibilityElement(children: .combine)

                ValueRuler(fraction: viewModel.valuedShare)
            } else {
                Text("Not yet valued")
                    .font(theme.typography.heroFigureSecondary)
                    .foregroundStyle(theme.colors.textInactive)
                    .accessibilityLabel("Current value not yet valued")
            }

            // Under the ruler either way: the asking-price figure exists
            // whether or not the person has priced anything, so a matched,
            // refreshed collection still says so under "Not yet valued".
            if viewModel.hasMarketFigures {
                marketLine(viewModel.marketLine)
            }
        }
    }

    /// 002 criterion 15: the market variant, one mono line under the ruler.
    ///
    /// One `Text` over one string, so the amount can never be read — or
    /// selected, or spoken — apart from the coverage it covers (spec P5).
    /// It shrinks rather than wraps for the same reason. Deliberately quiet
    /// and never brass or Archivo: this is an asking price on Reverb, and
    /// nothing about it may read as the total above.
    private func marketLine(_ line: String) -> some View {
        Text(attributedMarketLine(line))
            .font(theme.typography.monoMeta)
            .foregroundStyle(theme.colors.textMonoMeta)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 4)
    }

    /// The line with its amount lifted — the one part Design draws heavier
    /// and brighter. Found by searching for the formatted amount rather
    /// than composed from parts, so the view still renders the view model's
    /// string; a line whose amount can't be found renders uniform, which is
    /// legible rather than wrong.
    private func attributedMarketLine(_ line: String) -> AttributedString {
        var attributed = AttributedString(line)
        guard let amount = attributed.range(of: MarketCopy.median(cents: viewModel.marketTotalCents)) else {
            return attributed
        }
        attributed[amount].font = theme.typography.monoMeta.weight(.medium)
        attributed[amount].foregroundColor = theme.colors.textBody
        return attributed
    }

    // MARK: - Spent / gain

    private var spentAndGain: some View {
        HStack(spacing: 0) {
            figure(
                label: "Spent",
                value: viewModel.totalSpentCents.formattedAsWholeCurrency(currencyCode: "USD"),
                color: theme.colors.textPrimary
            )

            Rectangle()
                .fill(theme.colors.divider)
                .frame(width: theme.metrics.hairline)
                .padding(.vertical, 4)

            figure(
                label: "Gain",
                value: viewModel.valueDeltaCents.formattedAsSignedWholeCurrency(currencyCode: "USD"),
                color: viewModel.valueDeltaCents < 0
                    ? theme.colors.accentRustText
                    : theme.colors.accentMossText,
                trailingGlyph: viewModel.valueDeltaCents == 0
                    ? nil
                    : (viewModel.valueDeltaCents < 0 ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
            )
            .padding(.leading, theme.metrics.cardPadding)
        }
        .padding(theme.metrics.cardPadding)
        .extrudedPlate()
    }

    private func figure(
        label: String,
        value: String,
        color: Color,
        trailingGlyph: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).monoLabel()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(theme.typography.heroFigureSecondary)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let trailingGlyph {
                    Image(systemName: trailingGlyph)
                        .font(.system(size: 9))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Un-valued callout

    /// Design's card explains what the total is missing. The copy here also
    /// covers Spent and Gain, because those exclude the same items — saying
    /// only "your total" would leave two of the three figures unaccounted for.
    ///
    /// Unfilled with a hairline border, not a `surface` card: measured off the
    /// mock, which distinguishes it from the figures card above by outlining
    /// it rather than raising it. The rust edge is the attention mark.
    ///
    /// Design's "Value →" action is wired at last: it had nowhere to point
    /// until the real `TabView` existed. One un-valued item goes straight to
    /// that item; two or more go to the list narrowed to them.
    private var unvaluedCallout: some View {
        Button(action: followUnvaluedCallout) {
            HStack(alignment: .top, spacing: theme.metrics.cardPadding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.unvaluedCount) \(viewModel.unvaluedCount == 1 ? "item" : "items") not yet valued")
                        .font(theme.typography.rowTitle)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("They're left out of every figure above.")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textQuiet)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text("Value").monoLabel(color: theme.colors.accentBrass)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.colors.accentBrass)
                }
            }
            .padding(theme.metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(theme.colors.accentRust)
                    .frame(width: theme.metrics.calloutEdgeWidth)
            }
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                    .strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
            // Unfilled, so without this only the text, the arrow and the
            // outline took a tap; the padding and the spacer's gap didn't
            // (009 T014a).
            .contentShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(viewModel.unvaluedCount == 1
                           ? "Opens the item so you can value it"
                           : "Shows the items that still need a value")
    }

    private func followUnvaluedCallout() {
        switch viewModel.unvaluedDestination {
        case .none: break
        case .item(let id): router.showItem(id)
        case .filteredList: router.showUnvaluedItems()
        }
    }

    // MARK: - Breakdown

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: theme.metrics.controlRowGap) {
            HStack {
                Text("By category").monoLabel()
                Spacer()
                orderControl
            }

            // Every segment's width is its share of the total value, so with no
            // values the bar is a blank track under a heading promising a
            // proportion. The rows below still carry real information — how
            // many items sit where — so only the bar goes.
            if viewModel.hasAnyValues {
                stackedBar
            }

            VStack(spacing: 0) {
                ForEach(Array(viewModel.breakdown.enumerated()), id: \.element.id) { index, slice in
                    if index > 0 {
                        Divider().overlay(theme.colors.divider)
                    }
                    breakdownRow(slice, swatch: swatch(at: index))
                }
            }
        }
    }

    /// Design's "BY VALUE" control: the mono label the mock draws, not a
    /// pill (spec P12), opening the shared surface under ORDER BY on the
    /// host. A system `Menu` from `001` to 013 Amendment A — the exact
    /// variable-width-label-in-a-`Menu` shape T029c evicted from the list
    /// headers, unreported here only because this label has no border to
    /// lag. Converting it removed the risk rather than waiting for it.
    private var orderControl: some View {
        Button {
            openDropdown = .order
        } label: {
            Text(viewModel.breakdownOrder.label)
                .monoLabel(color: theme.colors.textQuiet)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropdownAnchor(DashboardDropdown.order)
        .accessibilityLabel("Order categories \(viewModel.breakdownOrder.label)")
        .accessibilityHint("Opens order options")
        .accessibilityIdentifier("orderOptions.dashboard")
    }

    /// Design's proportion bar. Widths track each category's share of value, so
    /// it and the percentages beneath it can't disagree.
    private var stackedBar: some View {
        GeometryReader { proxy in
            let gaps = CGFloat(max(viewModel.breakdown.count - 1, 0)) * theme.metrics.stackedBarSegmentGap
            let usable = max(proxy.size.width - gaps, 0)

            HStack(spacing: theme.metrics.stackedBarSegmentGap) {
                ForEach(Array(viewModel.breakdown.enumerated()), id: \.element.id) { index, slice in
                    Capsule()
                        .fill(swatch(at: index))
                        .frame(width: usable * CGFloat(viewModel.valueShare(of: slice)))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: theme.metrics.stackedBarHeight)
        .accessibilityHidden(true)
    }

    /// Three accents for the largest categories, then the neutral for the
    /// tail — Design's mock shows exactly that, and cycling the accents
    /// instead would put the same colour on two rows of one chart.
    private func swatch(at index: Int) -> Color {
        let swatches = theme.colors.categorySwatches
        return index < swatches.count ? swatches[index] : theme.colors.categoryNeutral
    }

    /// A row with a level beneath it drills further into the dashboard; a leaf
    /// leaves the dashboard entirely for the Items tab, narrowed to it.
    ///
    /// Until T042 a leaf rendered as plain content, because the only
    /// alternative — a disabled `NavigationLink` — dims its whole content,
    /// which reads as "this data is unavailable" when the figures are real and
    /// it's only the destination that was missing. Now it has one.
    @ViewBuilder
    private func breakdownRow(_ slice: DashboardViewModel.CategorySlice, swatch: Color) -> some View {
        if slice.canDrillIn {
            NavigationLink(value: DashboardScope(path: slice.path)) {
                breakdownRowContent(slice, swatch: swatch)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                router.showItems(inCategory: slice.path)
            } label: {
                breakdownRowContent(slice, swatch: swatch)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows this category in Items")
        }
    }

    private func breakdownRowContent(
        _ slice: DashboardViewModel.CategorySlice,
        swatch: Color
    ) -> some View {
        HStack(spacing: theme.metrics.cardPadding) {
            Rectangle()
                .fill(swatch)
                .frame(width: theme.metrics.categorySwatchWidth)

            VStack(alignment: .leading, spacing: 4) {
                Text(slice.label)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                Text(rowMeta(slice)).monoLabel()
            }

            Spacer(minLength: 0)

            if slice.hasAnyValues {
                Text(slice.currentValueCents.formattedAsWholeCurrency(currencyCode: "USD"))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
            } else {
                Text("Not yet valued").monoLabel(color: theme.colors.textInactive)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Design's "14 items · 45%", plus this category's own un-valued count
    /// when it has one — the percentage is a share of value, so a category
    /// carrying un-valued items reads lower than it really is.
    ///
    /// The percentage drops out entirely when nothing is valued — every row
    /// would read "0%", which looks like a measurement and isn't one.
    private func rowMeta(_ slice: DashboardViewModel.CategorySlice) -> String {
        var parts = ["\(slice.itemCount) \(slice.itemCount == 1 ? "item" : "items")"]
        if viewModel.hasAnyValues {
            parts.append("\(Int((viewModel.valueShare(of: slice) * 100).rounded()))%")
        }
        if slice.unvaluedCount > 0 {
            parts.append("\(slice.unvaluedCount) unvalued")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty

    /// Two states, and only the first gets an action.
    ///
    /// At the root, nothing tracked means nothing anywhere, so this is the
    /// app's first-run screen and the brief asks it to point at adding. The add
    /// form lives on the Items tab, so it goes through `AppRouter` rather than
    /// growing a second entry point here.
    ///
    /// A scoped dashboard is a different situation: the user drilled into a
    /// category from a row that had items in it, so an empty one means they've
    /// since been deleted or refiled. There's nothing to invite — adding an
    /// item wouldn't put it in this category — so it explains and stops.
    ///
    /// **Neither is where the dashboard's zero state actually bites.** With no
    /// items the whole figure stack is replaced by this, so the breakdown,
    /// ruler and callout never render at all. The state that degrades is items
    /// with no *values*, which is handled up in `headline`, `breakdown` and
    /// `spentAndGain` rather than here — see plan.md's Empty states section.
    private var emptyState: some View {
        Group {
            // Ahead of both, because this is the launch tab: on a new device
            // it's the first screen anyone sees, and "Nothing tracked yet" is
            // the wrong greeting for someone whose two hundred items are
            // three minutes from arriving. Scoped copies inherit it — a
            // category that looks emptied might just not be here yet.
            if viewModel.isStillSyncing {
                EmptyStateView(
                    mark: .stillSyncing,
                    headline: "Catching up with iCloud",
                    detail: "Your collection is on its way to this device. The figures fill in as it arrives."
                )
            } else if isRoot {
                EmptyStateView(
                    mark: .asset("TabDashboard"),
                    headline: "Nothing tracked yet",
                    detail: "Add your first piece of gear and this fills in: what it's worth, what you paid, and how it splits by category.",
                    action: .init(label: "Add an item", isProminent: true) { router.startAddingItem() }
                )
            } else {
                EmptyStateView(
                    mark: .system("tray"),
                    headline: "Nothing in this category",
                    detail: "Everything filed here has been moved or removed."
                )
            }
        }
    }
}

/// Wraps the drill-down path so the dashboard's `navigationDestination` can't
/// collide with the item list's, which routes on `UUID`.
struct DashboardScope: Hashable {
    let path: String
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.combinedSchema,
        configurations: ModelConfiguration(schema: TroveSchema.combinedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    let context = ModelContext(container)
    for item in [
        Item(name: "Leica M6", categoryPath: "Photography/Cameras",
             purchasePriceCents: 290_000, currentValueCents: 345_000),
        Item(name: "Hasselblad 500C/M", categoryPath: "Photography/Cameras",
             purchasePriceCents: 125_000, currentValueCents: 178_000),
        Item(name: "Nikon 105mm", categoryPath: "Photography/Lenses",
             purchasePriceCents: 24_000, currentValueCents: 31_000),
        Item(name: "Blues Junior", categoryPath: "Music/Amps",
             purchasePriceCents: 69_000, currentValueCents: 54_000),
        Item(name: "Squier CV50s", categoryPath: "Music/Guitars",
             purchasePriceCents: 34_900, currentValueCents: 38_000),
        Item(name: "HD 600", categoryPath: "Audio/Headphones",
             purchasePriceCents: 39_900, currentValueCents: nil),
        Item(name: "Gig bag", categoryPath: "Accessories",
             purchasePriceCents: 8_000, currentValueCents: 5_000),
    ] {
        context.insert(item)
    }

    return NavigationStack {
        DashboardView(modelContext: context)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
