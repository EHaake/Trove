import SwiftData
import SwiftUI

/// A single wishlist item, per `design/screens/Trove Wishlist Detail.png`:
/// what it is, what you think it'll cost, how much you want it, your notes,
/// and — since `002` — what it is asking on Reverb, in the space the market
/// ghost was holding open for exactly that.
///
/// Deliberately quiet. plan.md keeps the Sell Plan a tap away rather than
/// rendering it here — this screen is about the thing you want, not about what
/// you'd sell to get it.
struct WishlistDetailView: View {
    @State private var viewModel: WishlistDetailViewModel
    @State private var selectedPhotoIndex = 0
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var sellPlanRoute: SellPlanRoute?
    /// The match sheet's detent, driven by which phase it is showing.
    @State private var matchDetent: PresentationDetent = .medium

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncMonitor.self) private var syncMonitor

    init(modelContext: ModelContext, itemID: UUID) {
        _viewModel = State(
            initialValue: WishlistDetailViewModel(modelContext: modelContext, itemID: itemID)
        )
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
                    noun: "wanted item",
                    edit: { isEditing = true },
                    delete: { isConfirmingDelete = true }
                )
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: viewModel.load) {
            NavigationStack {
                if let item = viewModel.item {
                    WishlistFormView(modelContext: modelContext, editing: item)
                }
            }
        }
        // 002 (plan §6, Q9): one sheet, two phases. An alert can hold no
        // link, and branching the *content* rather than swapping
        // presentations means no binding is written mid-flight. Swipe-down
        // over the notice is Not now by construction — only
        // `continueFromNotice()` acknowledges anything.
        .sheet(isPresented: $viewModel.isFindingMatch, onDismiss: viewModel.load) {
            matchSheet
        }
        // An alert rather than a confirmation dialog, for the same reason as
        // the item detail screen: from a toolbar button the dialog renders as
        // a popover that drops the cancel button entirely.
        .alert(
            WishlistDeleteCopy.title(for: viewModel.item?.name ?? "this item"),
            isPresented: $isConfirmingDelete
        ) {
            Button(WishlistDeleteCopy.confirm, role: .destructive) {
                if viewModel.delete() { dismiss() }
            }
            Button(WishlistDeleteCopy.cancel, role: .cancel) {}
        } message: {
            Text(WishlistDeleteCopy.message)
        }
        .navigationDestination(item: $sellPlanRoute) { route in
            SellPlanView(
                modelContext: modelContext,
                wishlistItemID: route.wishlistItemID,
                syncMonitor: syncMonitor
            )
        }
        .onAppear(perform: viewModel.load)
    }

    /// The notice first, once per device, then the picker (spec Decision
    /// 14). The detent follows the phase: the notice is a short read, the
    /// picker wants the whole sheet.
    private var matchSheet: some View {
        Group {
            if viewModel.noticeIsPending {
                MarketNoticeView(
                    continueAction: viewModel.continueFromNotice,
                    declineAction: viewModel.declineNotice
                )
            } else {
                MarketMatchView(
                    viewModel: viewModel.makeMatchViewModel(),
                    pick: viewModel.setMatch,
                    cancel: { viewModel.isFindingMatch = false }
                )
            }
        }
        .presentationDetents([.medium, .large], selection: $matchDetent)
        .onChange(of: viewModel.noticeIsPending, initial: true) { _, isPending in
            matchDetent = isPending ? .medium : .large
        }
    }

    private func content(for item: WishlistItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                PhotoCarousel(
                    photos: viewModel.photos,
                    selectedIndex: $selectedPhotoIndex,
                    noun: "Wishlist"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(headingLine(for: item)).monoLabel()
                    Text(item.name)
                        .font(theme.typography.heroFigureSecondary)
                        .foregroundStyle(theme.colors.textPrimary)
                }

                costCard(for: item)
                desireCard(for: item)
                details(for: item)

                if viewModel.hasNotes, let notes = item.notes {
                    notesSection(notes)
                }

                marketSection(for: item)
                findItemsToSell(for: item)
            }
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.bottom, theme.metrics.sectionGap)
        }
    }

    /// Design's "WANTED · LENSES" — the state, then where it sits.
    private func headingLine(for item: WishlistItem) -> String {
        (["Wanted"] + CategoryPathHelper.trailingSegments(of: item.categoryPath, limit: 1))
            .joined(separator: " · ")
    }

    // MARK: - Cost

    private func costCard(for item: WishlistItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated cost").monoLabel()
            Text(item.estimatedCostCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                .font(theme.typography.heroFigure)
                .foregroundStyle(theme.colors.accentBrass)
            // "YOUR ESTIMATE" is doing real work: it marks this figure as the
            // user's own guess rather than a looked-up figure — the
            // distinction the Market section below now actually draws.
            Text("Your estimate · Added \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .monoLabel(color: theme.colors.textQuiet)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .extrudedPlate()
    }

    // MARK: - Desire

    /// Design drew this as a plain "Priority · Next up" row in the details
    /// table. It's the gauge instead, labeled, per the brief — the same
    /// treatment the dial gets on the item detail screen, and the reason the
    /// gauge exists as its own control.
    private func desireCard(for item: WishlistItem) -> some View {
        VStack(alignment: .leading, spacing: theme.metrics.cardPadding) {
            HStack {
                Text("How much you want it").monoLabel()
                Spacer()
                Text("Tap to set").monoLabel(color: theme.colors.textQuiet)
            }

            DesireGauge(
                value: desireBinding(for: item),
                maxSegmentHeight: 22,
                segmentWidth: 40,
                showsLabel: true,
                isInteractive: true
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .extrudedPlate()
    }

    /// Writes straight through and saves, matching the item detail dial: a
    /// priority you can nudge in place beats one that needs a trip through the
    /// form, and priorities change more often than the rest of these fields.
    private func desireBinding(for item: WishlistItem) -> Binding<Int> {
        Binding(
            get: { item.desireToOwn },
            set: { newValue in
                guard newValue != item.desireToOwn else { return }
                item.desireToOwn = newValue
                try? modelContext.save()
            }
        )
    }

    // MARK: - Remaining fields

    /// No "Priority" row — the gauge above says it, and saying it twice in
    /// different words invites them to disagree.
    ///
    /// No "Estimated cost" row either, for the same reason plus a sharper one:
    /// the card above already carries the figure as the screen's headline, and
    /// this row was printing it a second time to the cent ("$1,000.00" under
    /// "$1,000"). Whole dollars is the convention everywhere else in the app,
    /// so the row wasn't adding precision anyone asked for — just a second
    /// number to reconcile against the first. Found at T044.
    @ViewBuilder
    private func details(for item: WishlistItem) -> some View {
        let rows: [(label: String, value: String, isMono: Bool)] = [
            ("Category", viewModel.categorySegments.joined(separator: " · "), false),
            ("Added", item.createdAt.formatted(date: .abbreviated, time: .omitted), true),
        ].filter { !$0.value.isEmpty }

        if !rows.isEmpty {
            DetailSection(title: "Details") {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        DetailRow(label: row.label, value: row.value, isMono: row.isMono)
                    }
                }
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        DetailSection(title: "Notes") { DetailProse(text: notes) }
    }

    // MARK: - Market (002)

    /// Reverb's asking price for the thing the person wants, where the
    /// market-price ghost used to sit (spec 002, plan §6). The ghost was
    /// the layout this section was reserved for, so the section takes its
    /// place exactly: after NOTES, before the sell-plan CTA.
    private func marketSection(for item: WishlistItem) -> some View {
        MarketSection(
            state: viewModel.marketState,
            activity: viewModel.marketActivity,
            notice: viewModel.marketNotice,
            year: item.year,
            isWanted: true,
            canRefresh: viewModel.canRefresh,
            canAdopt: viewModel.canAdopt,
            actions: MarketSectionActions(
                find: viewModel.findMatch,
                refresh: viewModel.refresh,
                // Adopt reports its own failure through the view model;
                // the result is the intent's, not the view's.
                adopt: { _ = viewModel.adopt() },
                // Change match… is Find on Reverb… over an existing match.
                changeMatch: viewModel.findMatch,
                removeMatch: viewModel.removeMatch
            )
        )
    }

    // MARK: - Sell Plan

    /// The one action on this screen, and deliberately the only route to the
    /// Sell Plan anywhere — spec.md is explicit that it's reached from this
    /// screen and not from the list rows. A row shortcut was built at T036/T041
    /// and removed after review; `WishlistView` documents its absence.
    ///
    /// A single button rather than the plan rendered inline: plan.md is
    /// explicit that showing it automatically would overstate what it currently
    /// does. The label names the task ("find items to sell"), not a target —
    /// nothing here says how much is needed or how close the user is.
    private func findItemsToSell(for item: WishlistItem) -> some View {
        Button {
            sellPlanRoute = SellPlanRoute(wishlistItemID: item.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find items to sell")
                        .font(theme.typography.rowTitle)
                        .foregroundStyle(theme.colors.accentBrass)
                    // True today: `SellPlanViewModel.rank` really does put the
                    // least-wanted gear first. Design's own subtitle, kept
                    // because it describes the ranking that exists rather
                    // than a target the app doesn't compute.
                    Text("Browse your lowest desire-to-keep items")
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.colors.textLabelSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.colors.accentBrass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
            )
            // The outline leaves the interior transparent, and a transparent
            // interior isn't hit-testable — the solid fill this replaced was
            // doing that job silently. Without this the button only responds
            // on its glyphs (caught on the simulator, not in review).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Reachable once sync is on and another device removes the item while
    /// this screen is open.
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

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.combinedSchema,
        configurations: ModelConfiguration(schema: TroveSchema.combinedSchema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let wanted = WishlistItem(
        name: "Leica Summicron 35mm f/2 (v4)",
        categoryPath: "Photography/Lenses",
        estimatedCostCents: 240_000,
        notes: "Version 4 only — the 11-blade one. Would take a user-grade copy with clean glass over a mint one with haze.",
        desireToOwn: 3
    )
    context.insert(wanted)

    return NavigationStack {
        WishlistDetailView(modelContext: context, itemID: wanted.id)
    }
    .environment(\.theme, .dark)
    .environment(SyncMonitor.notSyncing)
    .preferredColorScheme(.dark)
}
