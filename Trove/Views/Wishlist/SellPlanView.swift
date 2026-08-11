import SwiftData
import SwiftUI

/// The Sell Plan for one wishlist item, per `design/screens/Trove Sell Plan.png`
/// — with the mock's two closing elements deliberately not built.
///
/// **"Mark 3 for sale" is out.** spec.md and plan.md both rule out sale
/// tracking in v1 in as many words: no marking as sold, no removal from
/// inventory, no transaction history. The Sell Plan is for deciding, not for
/// bookkeeping a sale. The button also implies a commit step that doesn't
/// exist — every toggle already persists on its own, which is the behaviour the
/// spec asks for.
///
/// **"Nothing is listed or sold until you say so" goes with it.** It's
/// reassurance about the button above it; with no button, it answers a question
/// the screen never raises, while implying listing and selling are things this
/// app does.
///
/// What the mock gets exactly right, and what's kept: the selected total and
/// the estimated cost as two figures side by side, with no third number
/// between them.
struct SellPlanView: View {
    @State private var viewModel: SellPlanViewModel

    @Environment(\.theme) private var theme

    init(modelContext: ModelContext, wishlistItemID: UUID) {
        _viewModel = State(
            initialValue: SellPlanViewModel(modelContext: modelContext, wishlistItemID: wishlistItemID)
        )
    }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            if let wanted = viewModel.wishlistItem {
                content(for: wanted)
            } else if viewModel.hasLoaded {
                missingItem
            }
        }
        .navigationTitle("Sell plan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: viewModel.load)
    }

    private func content(for wanted: WishlistItem) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                heading(for: wanted)
                figures(for: wanted)
                sectionHeader
            }
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.top, theme.metrics.sectionGap)
            .padding(.bottom, theme.metrics.listRowGap)
            .background(theme.colors.background)

            if viewModel.isEmpty {
                emptyState
                Spacer(minLength: 0)
            } else {
                candidateList
            }
        }
    }

    private func heading(for wanted: WishlistItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((["Wanted"] + CategoryPathHelper.trailingSegments(of: wanted.categoryPath, limit: 1))
                .joined(separator: " · "))
                .monoLabel()
            Text(wanted.name)
                .font(theme.typography.heroFigureSecondary)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(2)
        }
    }

    // MARK: - The two figures

    /// Side by side, never subtracted. See `SellPlanViewModel` for why there's
    /// no third figure here — the comparison is the user's to make.
    private func figures(for wanted: WishlistItem) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Selected").monoLabel()
                Text(viewModel.selectedValueCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode))
                    .font(theme.typography.heroFigure)
                    .foregroundStyle(selectedFigureColor)
                Text("\(viewModel.selectedCount) of \(viewModel.candidates.count) items")
                    .monoLabel(color: theme.colors.textQuiet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(theme.colors.divider)
                .frame(width: theme.metrics.hairline)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Estimated cost").monoLabel()
                Text(viewModel.estimatedCostCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode))
                    .font(theme.typography.heroFigureSecondary)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Your estimate").monoLabel(color: theme.colors.textQuiet)
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

    /// The quiet colour cue spec.md permits, and the only thing that changes
    /// when the selection reaches the estimate. No copy accompanies it — a tone
    /// is information the user reads, a sentence would be an instruction.
    private var selectedFigureColor: Color {
        viewModel.selectedValueMeetsCost ? theme.colors.accentMossText : theme.colors.accentBrass
    }

    // MARK: - Candidates

    private var sectionHeader: some View {
        HStack {
            Text("Sell candidates").monoLabel()
            Spacer()
            Text("Lowest desire to keep first").monoLabel(color: theme.colors.textQuiet)
        }
    }

    private var candidateList: some View {
        ScrollView {
            LazyVStack(spacing: theme.metrics.listRowGap) {
                ForEach(viewModel.candidates, id: \.id) { item in
                    SellPlanRow(
                        item: item,
                        isSelected: viewModel.isSelected(item),
                        toggle: { viewModel.toggle(item) }
                    )
                }
            }
            .padding(.horizontal, theme.metrics.listRowInset)
            .padding(.bottom, theme.metrics.sectionGap)
        }
    }

    /// Reachable with a real collection: everything rated 4–5, or nothing
    /// valued yet. Says which, since the two have different fixes.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing to suggest yet")
                .font(theme.typography.rowTitle)
                .foregroundStyle(theme.colors.textBody)
            Text("Candidates are things you've rated 3 or lower on desire to keep, with a current value entered.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textQuiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.metrics.screenGutter)
        .padding(.vertical, theme.metrics.sectionGap)
    }

    private var missingItem: some View {
        VStack(spacing: 8) {
            Text("This item is gone")
                .font(theme.typography.rowTitle)
                .foregroundStyle(theme.colors.textPrimary)
            Text("It was removed somewhere else.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textQuiet)
        }
        .padding(theme.metrics.screenGutter)
    }
}

/// One candidate: a checkbox, what it is, what it's worth, and how much the
/// user wants to keep it.
///
/// Design's meta line reads "GUITARS · DESIRE 1" beside a dial already showing
/// 1. That's the same value twice in two notations, so the meta line carries
/// the category alone — matching `ItemRow`, which pairs a category meta line
/// with a separate dial for exactly this reason.
private struct SellPlanRow: View {
    let item: Item
    let isSelected: Bool
    let toggle: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: theme.metrics.cardPadding) {
                checkbox

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(theme.typography.rowTitle)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                    Text(CategoryPathHelper.trailingSegments(of: item.categoryPath).joined(separator: " · "))
                        .monoLabel()
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let value = item.currentValueCents {
                    Text(value.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                } else {
                    // Only reachable for something already on the plan whose
                    // value was cleared afterwards — it stays switchable off.
                    Text("No value")
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.colors.textQuiet)
                }

                DesireDial(value: .constant(item.desireToKeep), diameter: 36)
            }
            .padding(theme.metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                    .fill(theme.colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                    .strokeBorder(
                        isSelected ? theme.colors.accentBrass : theme.colors.divider,
                        lineWidth: theme.metrics.hairline
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var checkbox: some View {
        RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
            .fill(isSelected ? theme.colors.accentBrass : Color.clear)
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                    .strokeBorder(
                        isSelected ? theme.colors.accentBrass : theme.colors.divider,
                        lineWidth: theme.metrics.hairline
                    )
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.background)
                }
            }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.schema,
        configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let wanted = WishlistItem(
        name: "Leica Summicron 35mm f/2 (v4)",
        categoryPath: "Photography/Lenses",
        estimatedCostCents: 240_000
    )
    context.insert(wanted)
    for item in [
        Item(name: "Squier Classic Vibe 50s", categoryPath: "Music/Guitars/Electric",
             currentValueCents: 38_000, desireToKeep: 1),
        Item(name: "Fender Blues Junior IV", categoryPath: "Music/Amps",
             currentValueCents: 64_000, desireToKeep: 2),
        Item(name: "Rode NT1-A", categoryPath: "Audio/Microphones",
             currentValueCents: 14_000, desireToKeep: 2),
        Item(name: "Leica M6", categoryPath: "Photography/Cameras",
             currentValueCents: 345_000, desireToKeep: 5),
    ] {
        context.insert(item)
    }

    return NavigationStack {
        SellPlanView(modelContext: context, wishlistItemID: wanted.id)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
