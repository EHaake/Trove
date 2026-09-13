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
    /// The match sheet's detent, driven by which phase it is showing.
    @State private var matchDetent: PresentationDetent = .medium

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
        // 002 (plan §6, Q9): one sheet, two phases. An alert can hold no
        // link, and branching the *content* rather than swapping
        // presentations means no binding is written mid-flight. Swipe-down
        // over the notice is Not now by construction — only
        // `continueFromNotice()` acknowledges anything.
        .sheet(isPresented: $viewModel.isFindingMatch, onDismiss: viewModel.load) {
            matchSheet
        }
        // 005 (plan §6): a second sheet, two phases — the one-time notice in
        // front of the picker, or the picker itself. Modelled on the market
        // sheet above but simpler, and a separate `isPresented` flag so the
        // two never fight over one binding.
        .sheet(isPresented: $viewModel.isFindingPhoto, onDismiss: viewModel.load) {
            photoSheet
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
            Text(ItemDeleteCopy.message(isSold: viewModel.item?.isSold ?? false))
        }
        .onAppear(perform: viewModel.load)
    }

    /// The notice first, once per device, then the picker (spec Decision
    /// 14), then — since Amendment B — the pick's fetch and the value step
    /// (Decisions 33–34). The detent follows the phase: the notice and the
    /// value step are short reads, the picker and the fetch want the whole
    /// sheet.
    private var matchSheet: some View {
        Group {
            switch viewModel.sheetStep {
            case .notice:
                MarketNoticeView(
                    continueAction: viewModel.continueFromNotice,
                    declineAction: viewModel.declineNotice
                )
            case .pick:
                MarketMatchView(
                    viewModel: viewModel.makeMatchViewModel(),
                    pick: viewModel.setMatch,
                    cancel: { viewModel.isFindingMatch = false }
                )
            case .fetching(let candidate, _):
                // The picked card, held still under the picker's own bar,
                // so the sheet doesn't go blank while the fetch runs
                // (Decision 33). The token is the view model's business.
                MarketFetchingView(candidate: candidate)
            case .value(let step):
                MarketValueStepView(
                    step: step,
                    isWanted: false,
                    productTitle: viewModel.marketState.matchedTitle,
                    year: viewModel.item?.year ?? nil,
                    actions: MarketValueStepActions(
                        choose: viewModel.setChosen,
                        // The amount comes back from the step the view is
                        // holding; the write and its refusal are the view
                        // model's, as the section's adopt was.
                        use: { _ = viewModel.adopt(cents: $0) },
                        notNow: viewModel.dismissValueStep
                    )
                )
            }
        }
        .presentationDetents([.medium, .large], selection: $matchDetent)
        // The phase, not the whole step: the step carries the value
        // step's payload, which the slider rewrites on every tick of a
        // drag, so observing the step itself would re-decide a detent that
        // cannot have changed (T022's third review). The detent depends on
        // the phase alone.
        .onChange(of: viewModel.sheetStep.phase, initial: true) { _, phase in
            matchDetent = switch phase {
            case .notice, .value: .medium
            case .pick, .fetching: .large
            }
        }
    }

    /// The stock-photo sheet's two phases (plan §6): the one-time notice, or
    /// the picker. Branching the content rather than swapping presentations
    /// means no binding is written mid-flight; swipe-down over the notice is
    /// Not now by construction, since only `continuePhotoNotice()` acknowledges.
    private var photoSheet: some View {
        Group {
            switch viewModel.photoSheetStep {
            case .notice:
                PhotoNoticeView(
                    continueAction: viewModel.continuePhotoNotice,
                    declineAction: viewModel.declinePhotoNotice
                )
            case .pick:
                PhotoPickerSheetView(
                    viewModel: viewModel.makePhotoFetchViewModel(),
                    store: { viewModel.store($0) },
                    cancel: { viewModel.isFindingPhoto = false }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Find a photo… — the fetches treatment (outlined brass), the same
    /// register as Find on Reverb…, reusing the generic word-free chrome
    /// (plan §6). Sits directly beneath the hero, shown only while
    /// `canFindPhoto` (no owned photo yet).
    private var findPhotoAction: some View {
        Button(action: viewModel.findPhoto) {
            Text(StockPhotoCopy.findAPhoto)
                .font(theme.typography.button)
                .marketOutlinedChrome(fills: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stockphoto.find")
    }

    private func content(for item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                PhotoCarousel(
                    photos: viewModel.photos,
                    selectedIndex: $selectedPhotoIndex
                )

                if viewModel.canFindPhoto {
                    findPhotoAction
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(item.categorySegments.joined(separator: " · ")).monoLabel()
                    Text(item.name)
                        .font(theme.typography.heroFigureSecondary)
                        .foregroundStyle(theme.colors.textPrimary)
                }

                statPair(for: item)
                desireCard(for: item)
                details(for: item)
                marketSection(for: item)

                if let notes = item.notes, !notes.isEmpty {
                    DetailSection(title: "Notes") { DetailProse(text: notes) }
                }
            }
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.bottom, theme.metrics.sectionGap)
        }
    }

    // MARK: - Value

    /// WORTH NOW and PAID as two bevelled cells split by a hairline seam,
    /// clipped and shadowed once as a unit — `tokens.md`'s "Item detail" stat
    /// pair. The seam is the container's own colour showing through the gap,
    /// which is why the cells carry no radius of their own.
    private func statPair(for item: Item) -> some View {
        HStack(spacing: theme.metrics.hairline) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Worth now").monoLabel()
                if let worth = item.currentValueCents {
                    Text(worth.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                        .font(theme.typography.heroFigureSecondary)
                        .foregroundStyle(theme.colors.accentBrass)
                } else {
                    // Design drew only the valued case, but a value is optional
                    // at creation, so most items pass through this one.
                    Text("Not yet valued")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textQuiet)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, theme.metrics.cardPadding)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .plateBevel()

            VStack(alignment: .leading, spacing: 7) {
                Text("Paid").monoLabel()
                Text(item.purchasePriceCents.formattedAsWholeCurrency(currencyCode: item.currencyCode))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)

                if let delta = item.valueDeltaCents {
                    Text(deltaSummary(delta: delta, paid: item.purchasePriceCents))
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(delta < 0 ? theme.colors.accentRustText : theme.colors.accentMossText)
                }
            }
            .padding(.horizontal, theme.metrics.cardPadding)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .plateBevel()
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(theme.colors.divider)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
        .shadow(color: theme.colors.plateCastShadow, radius: 3, x: 0, y: 2)
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

            HStack(spacing: 20) {
                DesireDial(
                    value: desireBinding(for: item),
                    diameter: 116,
                    isInteractive: true,
                    showsScale: true
                )
                .padding(.bottom, -DesireDial.emptyBottomInset(diameter: 116))
                .padding(.top, DesireDial.knobOverhang(diameter: 116))

                VStack(alignment: .leading, spacing: 8) {
                    Text(DesireLevel(clamping: item.desireToKeep).summary)
                        .font(theme.typography.rowTitle)
                        .foregroundStyle(theme.colors.textPrimary)
                    // What the rating actually does today — see
                    // `DesireLevel.detail(isValued:)` for why the mock's
                    // richer copy was reworded, and when to restore it.
                    Text(
                        DesireLevel(clamping: item.desireToKeep)
                            .detail(isValued: item.currentValueCents != nil)
                    )
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.colors.textLabelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .extrudedPlate()
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

    // MARK: - Remaining fields

    /// Label left, value right, hairline under each row — `tokens.md`'s item
    /// detail table.
    ///
    /// Money and dates stay out of here deliberately: the stat pair above
    /// already carries them, and the refreshed mock's duplicate rows would
    /// have the screen state the same figure twice. Notes moved out to their
    /// own section, which is what the mock does with them.
    @ViewBuilder
    private func details(for item: Item) -> some View {
        let rows: [(label: String, value: String, isMono: Bool)] = [
            ("Condition", item.condition.rawValue.capitalized, false),
            ("Condition notes", item.conditionNotes ?? "", false),
            ("Bought", item.purchaseDate.formatted(date: .abbreviated, time: .omitted), true),
            ("Bought from", item.purchaseLocation ?? "", false),
            ("Serial number", item.serialNumber ?? "", true),
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

    // MARK: - Market (002)

    /// Reverb's asking price beside the person's own figure — never in
    /// place of it (spec 002, plan §6). Placed after DETAILS and before
    /// NOTES, and given the view model's state rather than any derivation
    /// of its own.
    private func marketSection(for item: Item) -> some View {
        MarketSection(
            state: viewModel.marketState,
            activity: viewModel.marketActivity,
            notice: viewModel.marketNotice,
            year: item.year,
            isWanted: false,
            canRefresh: viewModel.canRefresh,
            canAdopt: viewModel.canAdopt,
            actions: MarketSectionActions(
                find: viewModel.findMatch,
                refresh: viewModel.refresh,
                // Use as my value opens the value step rather than
                // writing (Amendment B): one adopt control, one flow, and
                // the write happens in the sheet where the amount is
                // chosen. `canAdopt` already gates the button.
                adopt: viewModel.openValueStep,
                // Change match… is Find on Reverb… over an existing match.
                changeMatch: viewModel.findMatch,
                removeMatch: viewModel.removeMatch
            )
        )
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
