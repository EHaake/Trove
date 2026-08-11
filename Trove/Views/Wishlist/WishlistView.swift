import SwiftData
import SwiftUI

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
    @State private var sellPlanRoute: SellPlanRoute?
    @State private var isReordering = false

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: WishlistViewModel(modelContext: modelContext))
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: theme.metrics.controlRowGap) {
                    header
                        .padding(.horizontal, theme.metrics.screenGutter)
                        .padding(.bottom, theme.metrics.sectionGap - theme.metrics.controlRowGap)

                    SearchField(placeholder: "Search wishlist", text: $viewModel.searchText)
                        .padding(.horizontal, theme.metrics.screenGutter)

                    categoryChips
                }
                .padding(.top, theme.metrics.sectionGap)
                .padding(.bottom, theme.metrics.listRowGap)
                .background(theme.colors.background)

                if viewModel.isEmpty {
                    emptyState
                    Spacer(minLength: 0)
                } else {
                    rows
                }
            }
        }
        .overlay(alignment: .bottomTrailing) { addButton }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        // A separate destination type from the item list's bare `UUID`, so the
        // two stacks can't be confused about which entity an id belongs to.
        .navigationDestination(item: $selectedItemID) { itemID in
            WishlistDetailView(modelContext: modelContext, itemID: itemID)
        }
        .navigationDestination(item: $sellPlanRoute) { route in
            SellPlanView(modelContext: modelContext, wishlistItemID: route.wishlistItemID)
        }
        .sheet(isPresented: $isAddingItem, onDismiss: viewModel.load) {
            NavigationStack { WishlistFormView(modelContext: modelContext) }
        }
        // Values can change on the detail screen — an edit, the gauge, or a
        // deletion — so the list refetches whenever it comes back into view.
        .onAppear(perform: viewModel.load)
        .onChange(of: viewModel.searchText) { viewModel.load() }
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

            VStack(alignment: .trailing, spacing: 8) {
                sortControl
                if viewModel.canReorder || isReordering {
                    reorderToggle
                }
            }
        }
    }

    /// Design's "4 WANTED · $4,740".
    private var summaryLine: String {
        let count = viewModel.items.count
        return "\(count) wanted · "
            + viewModel.totalEstimatedCostCents.formattedAsWholeCurrency(currencyCode: "USD")
    }

    private var sortControl: some View {
        Menu {
            ForEach(WishlistViewModel.SortOrder.allCases) { order in
                Button {
                    viewModel.sortOrder = order
                    if !viewModel.canReorder { isReordering = false }
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

    /// Dragging needs an explicit mode. Long-press-to-drag competes with
    /// tapping a row to edit it, and a permanent set of grab handles would put
    /// furniture on a screen that's usually just being read.
    private var reorderToggle: some View {
        Button {
            isReordering.toggle()
        } label: {
            Text(isReordering ? "Done" : "Reorder")
                .monoLabel(color: isReordering ? theme.colors.accentBrass : theme.colors.textQuiet)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rows

    /// A `List` purely for `onMove`; everything visible is overridden so it
    /// reads as the same card stack the item list draws with a `LazyVStack`.
    private var rows: some View {
        List {
            ForEach(viewModel.items, id: \.id) { item in
                WishlistRow(item: item) {
                    sellPlanRoute = SellPlanRoute(wishlistItemID: item.id)
                }
                    .listRowBackground(Color.clear)
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
            }
            .onMove { source, destination in
                viewModel.move(fromOffsets: source, toOffset: destination)
            }
            .onDelete { offsets in
                delete(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Room to scroll the last row clear of the floating add button. It
        // always overlapped the bottom row, but the row's trailing corner used
        // to hold a gauge — something to read past. Now it holds the sell-plan
        // button, and a control you can't reach without scrolling first is a
        // different matter.
        .contentMargins(.bottom, 76, for: .scrollContent)
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets where viewModel.items.indices.contains(index) {
            modelContext.delete(viewModel.items[index])
        }
        try? modelContext.save()
        viewModel.load()
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
            if !viewModel.canReorder { isReordering = false }
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

    // MARK: - Add / empty

    private var addButton: some View {
        Button {
            isAddingItem = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(theme.colors.background)
                .frame(width: 56, height: 56)
                .background(Circle().fill(theme.colors.accentBrass))
        }
        .buttonStyle(.plain)
        .padding(.trailing, theme.metrics.screenGutter)
        .padding(.bottom, theme.metrics.sectionGap)
        .accessibilityLabel("Add wanted item")
    }

    /// Placeholder until T045, same as the item list's.
    private var emptyState: some View {
        Text(emptyStateMessage)
            .font(theme.typography.rowTitle)
            .foregroundStyle(theme.colors.textBody)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.vertical, theme.metrics.sectionGap)
    }

    private var emptyStateMessage: String {
        if !SearchMatching.normalized(viewModel.searchText).isEmpty {
            return "Nothing matches that"
        }
        return viewModel.categoryFilter.isEmpty
            ? "Nothing on the wishlist yet"
            : "Nothing in this category"
    }
}

/// One wishlist row: what it is, its category, and what it's expected to cost.
private struct WishlistRow: View {
    let item: WishlistItem
    let showSellPlan: () -> Void

    @Environment(\.theme) private var theme

    /// Everything lives in one row, with the trailing column carrying all three
    /// of the item's own readings top to bottom: cost, how much it's wanted,
    /// and the way through to its sell plan.
    ///
    /// The shortcut used to sit in a full-width strip under a divider, as
    /// Design drew it — but Design paired it there with a "$990 short" figure
    /// that spec.md rules out, and once that came off the strip was one short
    /// label and a lot of empty width. Folding it into the column the cost
    /// already occupies took the row from ~155pt to ~104pt, which is most of a
    /// row back per screen.
    var body: some View {
        HStack(alignment: .top, spacing: theme.metrics.cardPadding) {
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

            // Cost, gauge, shortcut — one field gap between each, rather than
            // grouping the first two and pushing the third to the bottom with
            // a spacer. Three readings of the same item deserve the same
            // spacing; the uneven version read as two things and an orphan.
            // The thumbnail still sets the row's height, so the column has
            // room to spare.
            VStack(alignment: .trailing, spacing: theme.metrics.fieldGap) {
                Text(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .accessibilityLabel("Estimated cost \(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))")

                DesireGauge(value: .constant(item.desireToOwn))

                sellPlanShortcut
            }
        }
        // Deliberately not `.accessibilityElement(children: .combine)`, which
        // the row used to carry: combining swallows the sell-plan button into
        // one long description and leaves no way to reach it. Read as separate
        // elements, the row is name, category, notes, cost, the gauge's own
        // label, then the button.
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
    }

    /// The way through to this item's sell plan.
    ///
    /// Plain brass text and an arrow — the treatment the full-width strip used
    /// before this moved into the column, without the capsule that stood here
    /// briefly.
    ///
    /// Set semibold, which the strip didn't need. Down here colour alone
    /// can't mark this as a control: the gauge sitting directly above ends on
    /// `accentBrass`, the very same value as this text, so brass reads as
    /// continuous with it rather than as the app's action colour. At regular
    /// weight it was also the lightest text in the row. The weight is what
    /// separates it from the readouts; the arrow says where it goes.
    ///
    /// "Sell plan" rather than Design's "See sell plan": the column is beside a
    /// truncating title, and the shorter label keeps roughly the cost's width
    /// instead of eating into the name. The full phrasing survives as the
    /// accessibility label, where nothing is competing for space.
    ///
    /// Its own `Button` inside a row that already navigates to the item, so
    /// taps here reach the sell plan rather than opening the item — the same
    /// arrangement as the full-width version, which behaved correctly.
    private var sellPlanShortcut: some View {
        Button(action: showSellPlan) {
            HStack(spacing: 6) {
                Text("Sell plan")
                    .font(theme.typography.secondary.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(theme.colors.accentBrass)
            // Hit area pushed well past the text on every side. A negative
            // inset grows the tappable region without moving anything, which
            // matters more now there's no capsule padding to sit in: what's
            // drawn is only about 75×16.
            .contentShape(Rectangle().inset(by: -12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See sell plan for \(item.name)")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.schema,
        configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
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
    .preferredColorScheme(.dark)
}
