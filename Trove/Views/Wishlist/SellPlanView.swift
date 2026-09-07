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

    init(modelContext: ModelContext, wishlistItemID: UUID, syncMonitor: SyncMonitor = .notSyncing) {
        _viewModel = State(
            initialValue: SellPlanViewModel(
                modelContext: modelContext,
                wishlistItemID: wishlistItemID,
                syncMonitor: syncMonitor
            )
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
        // An import landing while this screen is open changes what it should
        // show, and nothing else tells it — the view models fetch on appear
        // and hold an array rather than observing the store.
        .onChange(of: viewModel.completedImports) { viewModel.load() }
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

            if let reason = viewModel.emptyReason {
                emptyState(reason)
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
            VStack(spacing: 6) {
                Text("Selected").monoLabel()
                Text(viewModel.selectedValueCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode))
                    .font(theme.typography.heroFigure)
                    .foregroundStyle(selectedFigureColor)
                Text("\(viewModel.selectedCount) of \(viewModel.candidates.count) items")
                    .monoLabel(color: theme.colors.textQuiet)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(theme.colors.divider)
                .frame(width: theme.metrics.hairline)
                .padding(.vertical, 4)

            VStack(spacing: 6) {
                Text("Estimated cost").monoLabel()
                Text(viewModel.estimatedCostCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode))
                    .font(theme.typography.heroFigureSecondary)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("Your estimate").monoLabel(color: theme.colors.textQuiet)
            }
            .frame(maxWidth: .infinity)
        }
        // The divider is a `Rectangle` with only its width fixed, so it grows
        // to whatever height it's offered — and this header isn't inside a
        // scroll view, so it was offered plenty and stretched the card with it.
        // Sizing the row to its content puts the divider back to spanning the
        // text rather than setting the card's height.
        .fixedSize(horizontal: false, vertical: true)
        // Tighter above and below than the card's own padding: the two figures
        // are one comparison read across the divider, and the extra height was
        // pushing the candidate list further down than it earned.
        .padding(.vertical, 12)
        .padding(.horizontal, theme.metrics.cardPadding)
        .background(
            PlateSurface()
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
                        toggle: { viewModel.toggle(item) },
                        summary: viewModel.summary(for: item.id),
                        rise: viewModel.rise(for: item.id),
                        now: viewModel.loadedAt
                    )
                }
            }
            .padding(.horizontal, theme.metrics.listRowInset)
            .padding(.bottom, theme.metrics.sectionGap)
        }
    }

    /// Reachable with a real collection, and which way decides what to say —
    /// qualifying takes a desire-to-keep of 3 or lower *and* a current value,
    /// so reciting both rules to someone missing only one is noise.
    ///
    /// No action button on any of them, unlike the list screens. What each one
    /// asks for happens on a different screen — rate something lower, or go and
    /// value it — and there's no single item to send the user to. Naming the
    /// rule is the invitation; the toolbar behind this screen is the way back.
    @ViewBuilder
    private func emptyState(_ reason: SellPlanViewModel.EmptyReason) -> some View {
        switch reason {
        case .stillSyncing:
            EmptyStateView(
                mark: .stillSyncing,
                headline: "Catching up with iCloud",
                detail: "Your gear is on its way to this device. Anything you'd part with turns up here as it arrives."
            )

        case .nothingOwned:
            EmptyStateView(
                mark: .asset("TabItems"),
                headline: "Nothing to sell yet",
                detail: "Add the gear you own and anything you'd part with turns up here."
            )

        case .everythingIsAKeeper:
            EmptyStateView(
                mark: .system("lock"),
                headline: "Everything's a keeper",
                detail: "Sell plans draw from gear you've rated 3 or lower on desire to keep. Nothing is, right now."
            )

        case .nothingValued:
            EmptyStateView(
                mark: .system("questionmark.circle"),
                headline: "Nothing has a value yet",
                detail: "There's gear you'd part with, but a plan needs to know what it's worth. Add current values and it'll fill in."
            )
        }
    }

    private var missingItem: some View {
        EmptyStateView(
            mark: .system("tray"),
            headline: "This item is gone",
            detail: "It was removed somewhere else."
        )
    }
}

/// One candidate: a checkbox, what it is, what it's worth, and how much the
/// user wants to keep it.
///
/// Design's meta line reads "GUITARS · DESIRE 1" beside a dial already showing
/// 1. That's the same value twice in two notations, so the meta line carries
/// the category alone — matching `ItemRow`, which pairs a category meta line
/// with a separate dial for exactly this reason.
///
/// 003 adds two quiet lines, and both stack in the left column under the
/// category: the market line when there is a current median, then the
/// reason line beneath it when the item is rising. The person's value sits
/// alone on the right. The market line lived under that value until the
/// Phase 2 pause, where at phone width the two columns split the row so
/// the category truncated to "MUSIC · GUI…" and the sentence stacked four
/// lines deep beside a whole figure (003 spec Decision 14). The stack is
/// top-aligned so the checkbox, name, value and dial sit on the same edge
/// whether a row carries zero, one or two of them (criterion 11) — which
/// does move the marks on a plain two-line row from centred to top-hung, a
/// small geometry shift to an approved row recorded for the device pass
/// (003 plan Q6).
///
/// Internal rather than private so the render tests can build one.
struct SellPlanRow: View {
    let item: Item
    let isSelected: Bool
    let toggle: () -> Void
    /// The item's figure, from the screen's own view model — nil when it is
    /// unmatched, withheld or no longer current.
    let summary: MarketSummary?
    /// Set only for a rising row; the reason line's whole condition.
    let rise: MarketRise?
    /// When the screen loaded, so the reason line's date reads relative to
    /// the same instant the trend was derived at.
    let now: Date

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: theme.metrics.cardPadding) {
                checkbox

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(theme.typography.rowTitle)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                    Text(CategoryPathHelper.trailingSegments(of: item.categoryPath).joined(separator: " · "))
                        .monoLabel()
                        .lineLimit(1)
                    // Under the category, never instead of the person's own
                    // figure, which keeps its place on the right. The
                    // non-optional median is what keeps criterion 6 true by
                    // construction: withheld and stale both read nil here.
                    if let median = summary?.medianCents {
                        SellPlanMarketLine(medianCents: median, trend: summary?.currentTrend)
                    }
                    if let rise {
                        SellPlanReasonLine(rise: rise, now: now)
                    }
                }
                // Sized before the spacer, so the name and category take
                // the row's spare width rather than being cut to the market
                // line's rigid width beside them (spec Decision 14: on the
                // simulator "Blues Junior" read "Blues Juni…" over "$600 on
                // Reverb"). The value below is fixed-size, so the column
                // can never squeeze the figure the checkbox adds up.
                .layoutPriority(1)

                Spacer(minLength: 0)

                if let value = item.currentValueCents {
                    Text(value.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
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
        for: TroveSchema.combinedSchema,
        configurations: ModelConfiguration(schema: TroveSchema.combinedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
