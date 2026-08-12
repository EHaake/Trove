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
                WishlistRow(item: item)
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
        // No bottom margin, deliberately. The add button and the tab bar are
        // meant to sit over the last row or two when scrolled fully down —
        // that overlap is what gives iOS 26's glass material something to
        // refract. A margin here would buy clearance at the cost of the
        // effect it exists to enable. plan.md says so explicitly, because
        // this was once "fixed" the other way.
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

    // MARK: - Empty

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

    @Environment(\.theme) private var theme

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

            // Cost leads at the top, the gauge sits quietly at the bottom —
            // the brief puts it in the row's lower-right, unlabeled. The
            // thumbnail sets the row's height, so this column has the space
            // for both without the row growing.
            VStack(alignment: .trailing, spacing: 0) {
                Text(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .accessibilityLabel("Estimated cost \(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))")

                Spacer(minLength: theme.metrics.fieldGap)

                DesireGauge(value: .constant(item.desireToOwn))
            }
        }
        // One element again. It was split apart while the row held a button,
        // which combining would have swallowed; with nothing to reach in here,
        // a single description reads better than five fragments.
        .accessibilityElement(children: .combine)
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
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
