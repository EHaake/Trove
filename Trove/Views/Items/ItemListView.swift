import SwiftData
import SwiftUI

/// Browse owned gear, per `design/screens/Trove Item List.png`.
///
/// Design also shows a search field over name/brand/serial. It isn't in
/// spec.md's acceptance criteria or in `ItemListViewModel`, so it isn't built
/// here — adding an unasked-for feature quietly is worse than the gap.
struct ItemListView: View {
    @State private var viewModel: ItemListViewModel
    @State private var isAddingItem = false

    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: ItemListViewModel(modelContext: modelContext))
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            // Title, summary and filter chips stay put; only the rows move.
            // Standing layout rule in plan.md — the wishlist follows it too.
            // Losing the running total and the active filter the moment you
            // scroll is what it's there to prevent.
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                    header
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
                    Group {
                        if viewModel.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: theme.metrics.listRowGap) {
                                ForEach(viewModel.items, id: \.id) { item in
                                    NavigationLink(value: item.id) {
                                        ItemRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, theme.metrics.screenGutter)
                    .padding(.bottom, theme.metrics.sectionGap)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) { addButton }
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
        .onAppear { viewModel.load() }
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

    /// Design puts the add action in the tab bar, which doesn't exist until
    /// T042 — this floating button stands in for it and may well move there.
    /// It's here rather than in the harness so the list can reload when the
    /// form closes.
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
        .accessibilityLabel("Add item")
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

    /// Placeholder until T045, which gives this real design attention and
    /// points at the add action rather than just reporting absence.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.categoryFilter.isEmpty ? "Nothing here yet" : "Nothing in this category")
                .font(theme.typography.rowTitle)
                .foregroundStyle(theme.colors.textBody)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, theme.metrics.sectionGap)
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
