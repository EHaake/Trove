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
/// the estimated cost as two figures side by side, with nothing derived
/// between them.
///
/// **006 reopens the first paragraph and leaves the second standing.** Marking
/// one candidate sold, from the row it belongs to, is something this screen now
/// does (spec Decision 4) — but there is still no batch commit step, and the
/// Sold figure it grows joins the other two on the same terms: read side by
/// side, never subtracted from the cost (Decision 5). The sold items are listed
/// under the candidates so the plan reads as a record of what was actually done
/// toward it (P15).
struct SellPlanView: View {
    @State private var viewModel: SellPlanViewModel
    /// Whether the purchase sheet is up (015 plan §8). A flag rather than the
    /// Wishlist row's `.sheet(item:)` staging, for the reason the wanted
    /// entry's page holds one too: this screen has one subject, so there is
    /// nothing to choose between.
    @State private var isMarkingBought = false

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

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
        // 015 (plan §8, criterion 3): Mark as bought… for the wanted item this
        // plan belongs to, as a bar button rather than a menu — this screen has
        // no Edit or Delete for it to sit beside, and a one-row menu is a menu
        // for nothing. It lands in the same top-right corner the wanted entry's
        // "…" occupies, so "the action is top-right" is true on both screens.
        //
        // The gate is not decoration: this screen already draws `missingItem`
        // when its entry has gone (deleted on another device), and an ungated
        // button there would be tappable over no subject and would confirm a
        // purchase of nothing.
        .toolbar {
            if viewModel.wishlistItem != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isMarkingBought = true
                    } label: {
                        Image(systemName: "bag")
                    }
                    .accessibilityLabel(PurchaseCopy.markAsBought)
                    .accessibilityIdentifier("purchase.sellPlan")
                }
            }
        }
        .onAppear(perform: viewModel.load)
        // An import landing while this screen is open changes what it should
        // show, and nothing else tells it — the view models fetch on appear
        // and hold an array rather than observing the store.
        .onChange(of: viewModel.completedImports) { viewModel.load() }
        // `.sheet(item:)` over the row itself, the shape the item detail
        // presents its own sale sheet with (T014): one component, one seeding
        // rule — `makeSaleFormViewModel(for:)` seeds exactly as the detail
        // seeds `.mark` — and the sheet writes nothing, so what a confirmed
        // sale *means* is decided here. From this host it means a sale toward
        // this plan (spec P5); the view model's `markSold` reloads, so the row
        // leaves the candidates and the figures re-derive.
        .sheet(item: $viewModel.saleCandidate) { item in
            SaleFormView(
                viewModel: viewModel.makeSaleFormViewModel(for: item),
                confirm: { sale in
                    viewModel.markSold(item, sale: sale)
                    viewModel.saleCandidate = nil
                },
                cancel: { viewModel.saleCandidate = nil }
            )
        }
        // 015 (plan §8): a second sheet, beside the sale sheet above — the
        // shared purchase form, seeded by the view model exactly as the
        // Wishlist row's and the wanted entry's page are, so all three hosts
        // open on the same defaults. The sheet writes nothing itself: what a
        // confirmed purchase means is decided here, through `markBought`, the
        // one path into the store. A purchase that took pops this screen (R2),
        // since the plan's subject is no longer wanted.
        //
        // Only one that took. A refused save rolls back, so the entry and its
        // plan are still exactly as they were, and popping would move the
        // person off a screen that is still correct. Worth being plain about
        // what that costs: `markBought` records the reason in
        // `saveFailureMessage`, and **no view in the app reads that property**
        // — so a refusal is silent today, and staying put is the whole of what
        // the person is told.
        .sheet(isPresented: $isMarkingBought) {
            PurchaseFormView(
                viewModel: viewModel.makePurchaseFormViewModel(),
                confirm: { purchase in
                    isMarkingBought = false
                    if viewModel.markBought(purchase: purchase) { dismiss() }
                },
                cancel: { isMarkingBought = false }
            )
        }
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
                emptyPlan(reason)
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

    // MARK: - The figures

    /// Two figures until something has been sold toward this plan, three after
    /// — side by side either way, and nothing subtracted from the cost by
    /// either layout. See `SellPlanViewModel` for why no figure here is derived
    /// from the others: the comparison is the user's to make.
    ///
    /// The two-figure card is 001's, untouched. The three-figure one is the
    /// Design pass's: the cells hug their content with the dividers between
    /// them, every figure drops to `heroFigureSecondary` (Selected from 34, the
    /// one size at which three cells fit a phone), and the plate's side padding
    /// comes in to 12.
    @ViewBuilder
    private func figures(for wanted: WishlistItem) -> some View {
        if viewModel.hasSales {
            HStack(spacing: 0) {
                figureCell(
                    header: "Selected",
                    figure: viewModel.selectedValueCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode),
                    color: selectedFigureColor,
                    caption: "\(viewModel.selectedCount) of \(viewModel.candidates.count) items"
                )

                figureDivider

                // One stop for VoiceOver rather than three (criterion 16),
                // and the identifier plan §3 and §8 name — the header, the
                // figure and the count are one announcement, and T018's UI
                // test reads this one label instead of hunting three loose
                // texts above the candidates header.
                figureCell(
                    header: SaleCopy.sellPlanFigureHeader,
                    figure: viewModel.soldValueCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode),
                    color: theme.colors.textPrimary,
                    caption: SaleCopy.sellPlanSoldCaption(count: viewModel.soldCount)
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("sellPlan.soldFigure")

                figureDivider

                figureCell(
                    header: "Estimated cost",
                    figure: viewModel.estimatedCostCents.formattedAsWholeCurrency(currencyCode: wanted.currencyCode),
                    color: theme.colors.textPrimary,
                    caption: "Your estimate"
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(
                PlateSurface()
            )
        } else {
            twoFigures(for: wanted)
        }
    }

    /// 001's card, unchanged: each figure centred in its own half of the plate.
    private func twoFigures(for wanted: WishlistItem) -> some View {
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

    /// One cell of the three-figure card: a header, the figure, the caption
    /// under it. The figure is allowed to shrink rather than wrap or truncate —
    /// three whole figures on a phone is what this layout is for.
    private func figureCell(
        header: String,
        figure: String,
        color: Color,
        caption: String
    ) -> some View {
        VStack(spacing: 6) {
            Text(header).monoLabel()
            Text(figure)
                .font(theme.typography.heroFigureSecondary)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .monoLabel(color: theme.colors.textQuiet)
                .lineLimit(1)
        }
    }

    /// The divider between two cells, with the Design pass's 6 pt minimum
    /// either side — the cells hug their content and the space left over is
    /// spread between them, so three cells read as three rather than as a
    /// crowd.
    @ViewBuilder
    private var figureDivider: some View {
        Spacer(minLength: 6)

        Rectangle()
            .fill(theme.colors.divider)
            .frame(width: theme.metrics.hairline)
            .padding(.vertical, 4)

        Spacer(minLength: 6)
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
            VStack(alignment: .leading, spacing: 0) {
                LazyVStack(spacing: theme.metrics.listRowGap) {
                    ForEach(viewModel.candidates, id: \.id) { item in
                        SellPlanRow(
                            item: item,
                            isSelected: viewModel.isSelected(item),
                            toggle: { viewModel.toggle(item) },
                            markAsSold: { viewModel.saleCandidate = item },
                            summary: viewModel.summary(for: item.id),
                            rise: viewModel.rise(for: item.id),
                            now: viewModel.loadedAt
                        )
                    }
                }
                .padding(.horizontal, theme.metrics.listRowInset)

                if viewModel.hasSales {
                    soldSection
                }
            }
            .padding(.bottom, theme.metrics.sectionGap)
        }
    }

    /// The other host for the Sold section. Selling the last candidate empties
    /// the pool, and a plan whose pool has run dry still lists what was sold
    /// toward it (spec Decision 14) — the empty state says why there is
    /// nothing left to pick, the section under it says what was already done.
    ///
    /// One `soldSection`, composed here as well as under the candidates and
    /// gated the same way: a plan that has sold nothing is the bare empty
    /// state it has always been, unscrolled and centred.
    ///
    /// In a `ScrollView` for the same reason the candidates are — the sales
    /// outlive the pool, so there can be more of them than a screen holds.
    /// Inside one, `EmptyStateView`'s `maxHeight: .infinity` resolves to its
    /// own height rather than the screen's, so the state sits above the
    /// section instead of centring over it, which is what puts the record in
    /// view without a scroll.
    @ViewBuilder
    private func emptyPlan(_ reason: SellPlanViewModel.EmptyReason) -> some View {
        if viewModel.hasSales {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    emptyState(reason)

                    soldSection
                }
                .padding(.bottom, theme.metrics.sectionGap)
            }
        } else {
            emptyState(reason)
        }
    }

    // MARK: - What was actually sold toward this plan

    /// Under the candidates, and quieter than them: unplated rows of a mark, a
    /// name, a date and a price, so the plan reads as a record of what was
    /// done as well as a list of what might be (spec P15). Nothing here is
    /// added up on screen — the total is the header's Sold figure, and it is
    /// still beside the cost rather than against it.
    ///
    /// Composed by both halves of `content(for:)` — the candidate list and
    /// `emptyPlan(_:)` — because selling the last candidate must not take the
    /// record with it (spec Decision 14).
    private var soldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(SaleCopy.sellPlanSectionTitle).monoLabel()

            VStack(spacing: 0) {
                ForEach(viewModel.soldItems, id: \.id) { item in
                    soldRow(item)
                }
            }
        }
        .padding(.top, theme.metrics.sectionGap)
        .padding(.horizontal, theme.metrics.screenGutter)
    }

    /// One sale: what it was, when it went, what it brought in. The date and
    /// the price are the sale's own — never a current value, which a sold item
    /// no longer has an opinion about — and the row is one VoiceOver stop
    /// (criterion 16).
    private func soldRow(_ item: Item) -> some View {
        HStack(spacing: 10) {
            // `SoldMark`'s tag at row scale, and the same drawing: the word
            // inverted — the page's ink behind the page's background colour —
            // at `thumbnailRadius`, the smallest corner the app draws, with
            // the page's padding brought in and its asymmetry kept (the mono
            // label's tracking hangs a gap off the last letter).
            //
            // Inline rather than a property of its own: one row draws it, and
            // the scan next door reads the row for `SaleCopy.soldMark`.
            //
            // First in the row, so the combined announcement opens with the
            // word and the marks line up down the section's left edge. The
            // section header says SOLD once; a plan whose candidates have all
            // been sold is nothing *but* this section, and each row has to
            // carry it on its own (spec Decision 14).
            Text(SaleCopy.soldMark)
                .monoLabel(color: theme.colors.background)
                .padding(.leading, 5)
                .padding(.trailing, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius)
                        .fill(theme.colors.textPrimary)
                )

            Text(item.name)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let sale = item.sale {
                Text(sale.date.formatted(date: .abbreviated, time: .omitted))
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.colors.textMonoMeta)
                    .lineLimit(1)

                Text(sale.priceCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                    .font(ThemeTypography.font(.mono, size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.surfaceInset)
                .frame(height: theme.metrics.hairline)
        }
        .accessibilityElement(children: .combine)
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

        // The plan emptied by selling (spec Decision 15). It keeps the Items
        // mark the first-launch state above carries — the gear is still what
        // this screen is about — and, like every other case here, offers no
        // action: the sales are already on screen beneath it, and there is
        // nothing to send the person off to do.
        case .everythingSold:
            EmptyStateView(
                mark: .asset("TabItems"),
                headline: SaleCopy.planEverythingSoldHeadline,
                detail: SaleCopy.planEverythingSoldDetail
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
/// 006 splits the card in two tap targets (spec Decision 4, the Design pass's
/// footer strip): the body above is still the toggle, and Mark as sold… sits
/// under a hairline at the foot of the same card. Two targets rather than one
/// — a single `Button` wrapping both would have to guess which of a selection
/// and a sale the tap meant.
///
/// Internal rather than private so the render tests can build one.
struct SellPlanRow: View {
    let item: Item
    let isSelected: Bool
    let toggle: () -> Void
    /// Opens the sale sheet for this row. The row records nothing itself: the
    /// screen owns `saleCandidate` and what confirming the sheet means.
    let markAsSold: () -> Void
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
        VStack(spacing: 0) {
            Button(action: toggle) {
                card
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

            markAsSoldStrip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The card's fill and border move out here, around both halves, so the
        // strip sits *inside* the same card rather than under it.
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

    /// The half that toggles: everything the row said before 006, and the only
    /// thing the checkbox's tap target covers.
    private var card: some View {
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
            // line beside them (spec Decision 14: on the simulator
            // "Blues Junior" read "Blues Juni…" over "$600 on Reverb").
            // The value below is fixed-size, so the column can never
            // squeeze the figure the checkbox adds up.
            //
            // Measured while fixing S1, and it states an intent rather
            // than a mechanism: removing this line changes nothing.
            // The name's ink ends on the same pixel with it and without
            // it, at 327/345/382/402 pt, on long and short names, with
            // the figure rigid and with it limited — `Spacer` yields to
            // the column either way. Kept because it says which column
            // is meant to win if that ever stops being true, and there
            // is no test under it for the reason `CLAUDE.md` gives:
            // nothing can make one fail.
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
    }

    /// The Design pass's footer strip: a hairline across the card, 40 pt of
    /// quiet space, and the action right-aligned in the row's own style — a
    /// bespoke in-page control, not a system menu (`013`, and the spec's
    /// "system in the bars, bespoke in the page").
    private var markAsSoldStrip: some View {
        Button(action: markAsSold) {
            Text(SaleCopy.markAsSold)
                .font(theme.typography.buttonCompact)
                .foregroundStyle(theme.colors.accentBrass)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .trailing)
                .padding(.horizontal, theme.metrics.cardPadding)
                // 40 pt of strip, 44 pt of hit, and the four extra points go
                // downward only — below the strip, into the gap under the
                // card. An inset on every side reached two points back over
                // the toggle above, and the strip is the later sibling, so it
                // won those taps from the half they belonged to.
                .padding(.bottom, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sellPlan.row.markAsSold")
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.colors.surfaceInset)
                .frame(height: theme.metrics.hairline)
        }
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
