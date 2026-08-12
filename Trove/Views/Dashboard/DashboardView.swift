import SwiftData
import SwiftUI

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

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(modelContext: ModelContext, scope: String = "") {
        _viewModel = State(initialValue: DashboardViewModel(modelContext: modelContext, scope: scope))
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
            DashboardView(modelContext: modelContext, scope: destination.path)
        }
        // Values change on the item screens, so the figures refetch whenever
        // this comes back into view.
        .onAppear(perform: viewModel.load)
    }

    // MARK: - Header

    private var header: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("Not yet known")
                    .font(theme.typography.heroFigureSecondary)
                    .foregroundStyle(theme.colors.textInactive)
                    .accessibilityLabel("Current value not yet known")
            }
        }
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
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
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

    private var orderControl: some View {
        Menu {
            ForEach(DashboardViewModel.BreakdownOrder.allCases) { order in
                Button {
                    viewModel.breakdownOrder = order
                    viewModel.load()
                } label: {
                    if viewModel.breakdownOrder == order {
                        Label(order.label, systemImage: "checkmark")
                    } else {
                        Text(order.label)
                    }
                }
            }
        } label: {
            Text(viewModel.breakdownOrder.label).monoLabel(color: theme.colors.textQuiet)
        }
        .accessibilityLabel("Order categories \(viewModel.breakdownOrder.label)")
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
                Text("Not valued").monoLabel(color: theme.colors.textInactive)
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
            if isRoot {
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
        for: TroveSchema.schema,
        configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
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
