import SwiftData
import SwiftUI

/// Browse owned gear, per `design/screens/Trove Item List.png`.
struct ItemListView: View {
    @State private var viewModel: ItemListViewModel
    @State private var isAddingItem = false

    /// The chip the next layout pass should bring into view.
    ///
    /// Set only when a filter arrives from another tab, never when the user
    /// taps a chip themselves — their finger already put it where they can see
    /// it, and sliding it out from under them would be motion for nothing.
    @State private var chipToReveal: String?

    /// The un-valued chip's scroll id. Not a category path, so it can't
    /// collide with one — no real path is empty *and* prefixed like this.
    private static let unvaluedChipID = "\u{0}unvalued"

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: ItemListViewModel(modelContext: modelContext))
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

                    SearchField(placeholder: "Search name or serial", text: $viewModel.searchText)
                        .padding(.horizontal, theme.metrics.screenGutter)

                    // Full-bleed so chips scroll off the edge rather than
                    // stopping at the gutter; the gutter moves inside instead.
                    categoryChips
                }
                .padding(.top, theme.metrics.sectionGap)
                // Only as much space as sits between two rows. A full section
                // gap here on top of each card's own padding read as a hole
                // between the chips and the list.
                .padding(.bottom, theme.metrics.listRowGap)
                .background(theme.colors.background)

                ScrollView {
                    // Rows sit inside the gutter by their own card padding, so
                    // a row's text lines up with the title above it while the
                    // card still reaches nearer the edge than the header does.
                    if viewModel.isEmpty {
                        emptyState
                            .padding(.horizontal, theme.metrics.screenGutter)
                            .padding(.bottom, theme.metrics.sectionGap)
                    } else {
                        LazyVStack(spacing: theme.metrics.listRowGap) {
                            ForEach(viewModel.items, id: \.id) { item in
                                NavigationLink(value: item.id) {
                                    ItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, theme.metrics.listRowInset)
                        // No bottom padding: the rows run right to the edge of
                        // the scroll, so the tab bar and the add button sit
                        // over the last one or two. Same rule the wishlist
                        // follows — see plan.md's Navigation section. The
                        // empty state above keeps its padding, having nothing
                        // for the glass to refract either way.
                    }
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
        // Values can change on the detail screen — an edit, or the dial — so
        // the list refetches whenever it comes back into view.
        // Applied here rather than written into the view model by the router:
        // navigation asks, the screen decides how to show it.
        .onAppear {
            apply(router.itemsRequest)
            viewModel.load()
        }
        .onChange(of: router.itemsRequest) { _, request in
            guard request != nil else { return }
            apply(request)
            viewModel.load()
        }
        // Per keystroke. A refetch-and-filter over a personal inventory is
        // cheap enough that debouncing would only add latency to typing;
        // revisit if the store ever holds thousands of items.
        .onChange(of: viewModel.searchText) { viewModel.load() }
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

            sortControl
        }
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

    private var sortControl: some View {
        Menu {
            ForEach(ItemListViewModel.SortOrder.allCases) { order in
                Button {
                    viewModel.sortOrder = order
                    viewModel.load()
                } label: {
                    if viewModel.sortOrder == order {
                        Label(order.label, systemImage: "checkmark")
                    } else {
                        Text(order.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .medium))
                Text(viewModel.sortOrder.label)
                    .font(theme.typography.body)
            }
            .foregroundStyle(theme.colors.textBody)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
            )
        }
        .accessibilityLabel("Sort by \(viewModel.sortOrder.label)")
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

    /// Placeholder until T045, which gives this real design attention and
    /// points at the add action rather than just reporting absence.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emptyStateMessage)
                .font(theme.typography.rowTitle)
                .foregroundStyle(theme.colors.textBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, theme.metrics.sectionGap)
    }

    /// Search is named first: it's the narrower of the two, and the one the
    /// user just typed. "Nothing in this category" under a query they can see
    /// in the field would point at the wrong control.
    private var emptyStateMessage: String {
        if !SearchMatching.normalized(viewModel.searchText).isEmpty {
            return "Nothing matches that"
        }
        return viewModel.categoryFilter.isEmpty ? "Nothing here yet" : "Nothing in this category"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.schema,
        configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
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
