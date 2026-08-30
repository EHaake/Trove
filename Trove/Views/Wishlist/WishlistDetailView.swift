import SwiftData
import SwiftUI

/// A single wishlist item, per `design/screens/Trove Wishlist Detail.png`:
/// what it is, what you think it'll cost, how much you want it, your notes,
/// and space held open for pricing that doesn't exist yet.
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

                marketPricePlaceholder
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
            // user's own guess rather than a looked-up price, which is exactly
            // the distinction the market-price block below is reserved for.
            Text("Your estimate · Added \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .monoLabel(color: theme.colors.textQuiet)
        }
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
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
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
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
        let rows: [(String, String)] = [
            ("Category", viewModel.categorySegments.joined(separator: " · ")),
            ("Added", item.createdAt.formatted(date: .abbreviated, time: .omitted)),
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
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 13)
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("Notes").monoLabel()
            Text(notes)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textBody)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            HStack(spacing: 8) {
                Text("Find items to sell")
                    .font(theme.typography.rowTitle)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(theme.colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .fill(theme.colors.accentBrass)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reserved

    /// Space held open for the market pricing spec.md lists as a non-goal for
    /// v1, drawn as Design drew it: dashed, dim, and explicitly labeled as not
    /// tracked rather than mocked up with fake numbers.
    ///
    /// Reserving it now is the point — plan.md asks for the layout to already
    /// have a home for this so adding it later isn't a redesign of the screen.
    private var marketPricePlaceholder: some View {
        VStack(alignment: .leading, spacing: theme.metrics.cardPadding) {
            HStack {
                Text("Market price").monoLabel()
                Spacer()
                Text("Not tracked yet").monoLabel(color: theme.colors.textInactive)
            }

            // Inert bars, not data. Varying heights so the block reads as a
            // chart's footprint rather than as a loading state that might
            // finish.
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(Self.placeholderBarHeights.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius)
                        .fill(theme.colors.surfaceInset)
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44, alignment: .bottom)

            Text("Trove will chart what this actually sells for once price tracking is switched on.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textInactive)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .strokeBorder(
                    theme.colors.divider,
                    style: StrokeStyle(lineWidth: theme.metrics.hairline, dash: [4, 3])
                )
        )
    }

    private static let placeholderBarHeights: [CGFloat] = [18, 24, 16, 30, 22, 34, 26, 38, 30, 42, 34, 44]

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
        for: TroveSchema.schema,
        configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
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
