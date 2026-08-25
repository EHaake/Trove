import SwiftData
import SwiftUI

/// A single item, per `design/screens/Trove Item Detail.png`: photos, what
/// it's worth against what it cost, the dial large and editable, then the
/// remaining fields.
struct ItemDetailView: View {
    @State private var viewModel: ItemDetailViewModel
    @State private var selectedPhotoIndex = 0
    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    init(modelContext: ModelContext, itemID: UUID) {
        _viewModel = State(initialValue: ItemDetailViewModel(modelContext: modelContext, itemID: itemID))
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            if let item = viewModel.item {
                content(for: item)
            } else if viewModel.hasLoaded {
                missingItem
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DetailOverflowMenu(
                    noun: "item",
                    edit: { isEditing = true },
                    delete: { isConfirmingDelete = true }
                )
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: viewModel.load) {
            NavigationStack {
                if let item = viewModel.item {
                    ItemFormView(modelContext: modelContext, editing: item)
                }
            }
        }
        // An alert rather than a confirmation dialog: presented from a toolbar
        // button, the dialog renders as an anchored popover that drops the
        // cancel button entirely, leaving "Delete" as the only thing to press
        // on a destructive, irreversible action.
        .alert(
            ItemDeleteCopy.title(for: viewModel.item?.name ?? "this item"),
            isPresented: $isConfirmingDelete
        ) {
            Button(ItemDeleteCopy.confirm, role: .destructive) {
                if viewModel.delete() { dismiss() }
            }
            Button(ItemDeleteCopy.cancel, role: .cancel) {}
        } message: {
            // Shared with the list's swipe path (T017) — one source, so the
            // two entry points can't drift, and the sell-plan consequence
            // T002 found missing here arrives with it.
            Text(ItemDeleteCopy.message)
        }
        .onAppear(perform: viewModel.load)
    }

    private func content(for item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                PhotoCarousel(
                    photos: viewModel.photos,
                    selectedIndex: $selectedPhotoIndex
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.categorySegments.joined(separator: " · ")).monoLabel()
                    Text(item.name)
                        .font(theme.typography.heroFigureSecondary)
                        .foregroundStyle(theme.colors.textPrimary)
                }

                valueCard(for: item)
                desireCard(for: item)
                details(for: item)
            }
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.bottom, theme.metrics.sectionGap)
        }
    }

    // MARK: - Value

    private func valueCard(for item: Item) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Worth now").monoLabel()
                if let worth = item.currentValueCents {
                    Text(worth.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                        .font(theme.typography.heroFigure)
                        .foregroundStyle(theme.colors.accentBrass)
                } else {
                    // Design drew only the valued case, but a value is optional
                    // at creation, so most items pass through this one.
                    Text("Not yet valued")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textQuiet)
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(theme.colors.divider)
                .frame(width: theme.metrics.hairline)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Paid").monoLabel()
                Text(item.purchasePriceCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                    .font(theme.typography.heroFigureSecondary)
                    .foregroundStyle(theme.colors.textPrimary)

                if let delta = item.valueDeltaCents {
                    Text(deltaSummary(delta: delta, paid: item.purchasePriceCents))
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(delta < 0 ? theme.colors.accentRustText : theme.colors.accentMossText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, theme.metrics.cardPadding)
        }
        .padding(theme.metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
    }

    /// Design's "+$550 · +19%". The percentage is skipped when the item was
    /// free, since everything is an infinite gain over nothing.
    private func deltaSummary(delta: Int, paid: Int) -> String {
        let amount = "\(delta.formattedAsSignedWholeAmount)"
        guard paid > 0 else { return "\(amount) vs paid" }
        let percent = (Double(delta) / Double(paid) * 100).rounded()
        return "\(amount) · \(delta < 0 ? "−" : "+")\(abs(Int(percent)))%"
    }

    // MARK: - Desire

    private func desireCard(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: theme.metrics.cardPadding) {
            HStack {
                Text("Desire to keep").monoLabel()
                Spacer()
                Text("Tap or drag").monoLabel(color: theme.colors.textQuiet)
            }

            HStack(spacing: theme.metrics.sectionGap) {
                DesireDial(
                    value: desireBinding(for: item),
                    diameter: 116,
                    isInteractive: true,
                    showsScale: true
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(DesireLevel(clamping: item.desireToKeep).summary)
                        .font(theme.typography.rowTitle)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(sellCandidacyNote(for: item))
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textQuiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
    }

    /// Editing the dial writes straight through to the item and saves, so the
    /// rating behaves like the quick adjustment the brief describes rather
    /// than something needing a trip through the form.
    private func desireBinding(for item: Item) -> Binding<Int> {
        Binding(
            get: { item.desireToKeep },
            set: { newValue in
                guard newValue != item.desireToKeep else { return }
                item.desireToKeep = newValue
                item.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    /// Says what the rating actually does. Design shows this for a 5
    /// ("Excluded from sell candidates unless you say otherwise"); the
    /// candidate side is the same fact from the other direction.
    private func sellCandidacyNote(for item: Item) -> String {
        let level = DesireLevel(clamping: item.desireToKeep)
        if level.isSellCandidate {
            return item.currentValueCents == nil
                ? "Would appear in sell plans, once it has a value."
                : "Appears in sell plans for wishlist items."
        }
        return "Excluded from sell candidates unless you say otherwise."
    }

    // MARK: - Remaining fields

    @ViewBuilder
    private func details(for item: Item) -> some View {
        let rows: [(String, String)] = [
            ("Condition", item.condition.rawValue.capitalized),
            ("Condition notes", item.conditionNotes ?? ""),
            ("Bought", item.purchaseDate.formatted(date: .abbreviated, time: .omitted)),
            ("Bought from", item.purchaseLocation ?? ""),
            ("Serial number", item.serialNumber ?? ""),
            ("Notes", item.notes ?? ""),
        ].filter { !$0.1.isEmpty }

        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Divider().overlay(theme.colors.divider)
                }
                HStack(alignment: .top, spacing: theme.metrics.cardPadding) {
                    Text(row.0).monoLabel()
                        .frame(width: 116, alignment: .leading)
                    Text(row.1)
                        .font(row.0 == "Serial number" ? theme.typography.monoMeta : theme.typography.body)
                        .foregroundStyle(theme.colors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 13)
            }
        }
    }

    /// Reachable once sync is on and another device deletes the item while
    /// this screen is open.
    private var missingItem: some View {
        VStack(spacing: 8) {
            Text("This item is gone")
                .font(theme.typography.rowTitle)
                .foregroundStyle(theme.colors.textPrimary)
            Text("It was deleted somewhere else.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textQuiet)
        }
        .padding(theme.metrics.screenGutter)
    }
}
