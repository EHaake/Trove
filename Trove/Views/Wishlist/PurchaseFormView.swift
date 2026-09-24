import SwiftUI

/// The purchase sheet — Mark as bought (015 plan §7). One mode, unlike the
/// sale sheet: a wanted entry is bought once, and there is nothing to go back
/// and edit.
///
/// A twin file rather than a mode on `SaleFormView` (plan Q8): the fields
/// differ — Condition instead of a note, and a comparison line under the
/// price — and this spec's non-goals forbid changing the sale sheet. So this
/// copies `SaleFormView`'s chrome, which `SaleFormView` itself copied from
/// `ItemFormView`, the house precedent for exactly this; the condition row is
/// `ItemFormView`'s `FlowLayout` of capsules, copied the same way.
///
/// It is hosted from the wishlist, the wanted-entry page and the Sell Plan,
/// and it writes nothing itself: confirming hands
/// `PurchaseFormViewModel.purchase()`'s value to `confirm`, and whoever
/// presented the sheet decides what to record. That is why this file never
/// touches a `ModelContext` — the same rule the sale sheet holds.
///
/// One deliberate divergence from the twin (plan Q9): the date popover is
/// **unbounded**. The sale sheet bounds its picker at `now()`, because a sale
/// in the future is not a sale; this sheet fills `Item.purchaseDate`, whose
/// own editor — `ItemFormView`'s "Date bought" — takes any date at all, and a
/// sheet that refuses what the Edit screen accepts is one rule with two
/// answers.
///
/// A second deliberate divergence, and the sharper one (T012a, the person's
/// decision at the device pass): this sheet carries **no navigation title**,
/// where `SaleFormView` keeps `.navigationTitle(viewModel.title)`. The title
/// read "Mark as bought", the confirm button reads "Mark as bought", and with
/// both in one inline bar the title truncated to "Mark as bo…" on every host.
/// The person's reason: the title is redundant with the button, so the title
/// is what goes. Saying it here so it reads as the decision it is rather than
/// as drift from the twin — and `PurchaseCopy.sheetTitle` and
/// `PurchaseFormViewModel.title` went with it, so there is no unused constant
/// left behind for someone to wire back up by accident.
///
/// Every word comes from `PurchaseCopy`, never typed here, so the sheet and
/// the rest of the spec's surfaces cannot drift apart.
struct PurchaseFormView: View {
    @State private var viewModel: PurchaseFormViewModel
    private let confirm: (Purchase) -> Void
    private let cancel: () -> Void

    @State private var showsDatePicker = false

    @Environment(\.theme) private var theme

    /// The view model is made by the host screen
    /// (`makePurchaseFormViewModel()`), so the seed comes from there. Held in
    /// `@State`, so the sheet's body being re-evaluated doesn't throw away
    /// what's been typed.
    init(
        viewModel: PurchaseFormViewModel,
        confirm: @escaping (Purchase) -> Void,
        cancel: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.confirm = confirm
        self.cancel = cancel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                        // The comparison line belongs to the price, not to the
                        // form: field spacing, directly beneath the row.
                        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                            priceAndDate
                            comparison
                        }
                        boughtFromField
                        conditionField
                    }
                    .padding(.horizontal, theme.metrics.screenGutter)
                    .padding(.top, theme.metrics.sectionGap)
                    .padding(.bottom, theme.metrics.sectionGap)
                }
                // Four short fields don't fill the medium detent, and a form
                // that rubber-bands over empty space reads as broken.
                .scrollBounceBehavior(.basedOnSize)
            }
            // No navigation title at all — see the note above. The inline
            // display mode stays: it is what keeps the bar the compact strip
            // Cancel and Mark as bought sit in, rather than a large-title bar
            // holding empty space where a title isn't.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PurchaseCopy.cancel, action: cancel)
                        .foregroundStyle(theme.colors.textBody)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.confirmLabel, action: record)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.accentBrass)
                        .accessibilityIdentifier("purchase.sheet.confirm")
                }
            }
        }
        // The sale sheet's size: the content sits at roughly the medium
        // detent, and the sheet has somewhere to go when the keyboard rises.
        .presentationDetents([.medium, .large])
    }

    /// Confirming validates first. An invalid sheet stays open with the rust
    /// border on the price and no message — the sale sheet's invalid state,
    /// and the only one reachable here, since the date is unbounded (Q9).
    private func record() {
        guard let purchase = viewModel.purchase() else { return }
        confirm(purchase)
    }

    // MARK: - Fields

    /// Purchase price and Purchase date, paired on one row, `SaleFormView`'s
    /// `priceAndDate` down to the equal-height trick: a `TextField` sits a
    /// couple of points taller than the date button's plain `Text`, and two
    /// side-by-side cards of different heights read as a mistake.
    private var priceAndDate: some View {
        HStack(alignment: .top, spacing: theme.metrics.listRowGap) {
            VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                Text(PurchaseCopy.purchasePriceLabel).monoLabel()
                HStack(spacing: 6) {
                    Text("$")
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textQuiet)
                    TextField(
                        "0",
                        value: $viewModel.price,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .tint(theme.colors.accentBrass)
                    .keyboardType(.decimalPad)
                    // Without this the field's accessibility label is its
                    // placeholder, "0" — the visible label above is a
                    // separate `Text`, so nothing else connects the two.
                    .accessibilityLabel(PurchaseCopy.purchasePriceLabel)
                    .accessibilityIdentifier("purchase.sheet.price")
                }
                .padding(.vertical, theme.metrics.fieldPaddingVertical)
                .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(fieldBackground)
                .overlay(fieldBorder(isInvalid: viewModel.validationErrors.contains(.priceMissing)
                    || viewModel.validationErrors.contains(.priceNegative)))
            }

            dateField
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The sale sheet's date field with its ceiling removed (Q9): the button
    /// wears the same chrome as every other field, and the popover behind it
    /// holds the real picker, selectable in either direction.
    ///
    /// Two digits each, locale-ordered, exactly as the sale date reads.
    private var dateField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(PurchaseCopy.purchaseDateLabel).monoLabel()

            Button {
                showsDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Text(
                        viewModel.date,
                        format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)
                    )
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(theme.colors.textLabel)
                }
                .padding(.vertical, theme.metrics.fieldPaddingVertical)
                .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(fieldBackground)
                .overlay(fieldBorder(isInvalid: false))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PurchaseCopy.purchaseDateLabel)
            .accessibilityValue(viewModel.date.formatted(date: .long, time: .omitted))
            .popover(isPresented: $showsDatePicker) {
                DatePicker(
                    PurchaseCopy.purchaseDateLabel,
                    selection: $viewModel.date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(theme.colors.accentBrass)
                // A graphical picker reports a tiny ideal width and the
                // popover honours it — without a floor the calendar collapses
                // into an unusable sliver.
                .frame(minWidth: 320, minHeight: 350)
                .padding(theme.metrics.cardPadding)
                // Without this a popover becomes a full sheet on iPhone, which
                // is far heavier than picking a date warrants — and inside a
                // sheet it would cover the form it belongs to.
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    /// How the entered price compares to what the wanted entry estimated, or
    /// nothing at all when they match or there was no estimate — the view
    /// model decides which, and this only places it.
    ///
    /// Quiet supporting text, and deliberately not colour-coded: the spec
    /// calls it an observation, not a verdict, so there is no branch here on
    /// over versus under.
    ///
    /// Sentence case (T011b, the person's decision at the Phase 2 pause,
    /// overturning plan §7's `.monoLabel`). `monoLabel` uppercases and
    /// letterspaces, which drew this line in the identical treatment as the
    /// PURCHASE PRICE label directly above it — a second field label rather
    /// than the observation the spec asks for. The pairing here is the house
    /// one for quiet supporting prose (`SellPlanMarketLines`' reason line,
    /// `PhotoPickerField`'s status line): `secondary` on `textQuiet`.
    @ViewBuilder
    private var comparison: some View {
        if let line = viewModel.comparisonLine {
            Text(line)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.textQuiet)
                .accessibilityIdentifier("purchase.sheet.comparison")
        }
    }

    private var boughtFromField: some View {
        labelledField(PurchaseCopy.boughtFromLabel) {
            plainTextField(
                PurchaseCopy.boughtFromPlaceholder,
                label: PurchaseCopy.boughtFromLabel,
                text: $viewModel.location
            )
        }
    }

    /// `ItemFormView`'s condition row, copied (Q8): a label over a flow of
    /// capsules, one per case. Not a picker — a system menu inside page
    /// content is what `MenuPolicyTests` forbids.
    private var conditionField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(PurchaseCopy.conditionLabel).monoLabel()
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Condition.allCases, id: \.self, content: conditionChip)
            }
        }
    }

    /// The selected trait is load-bearing twice over: it is how VoiceOver says
    /// which condition is chosen, and how a UI test reads the selection.
    private func conditionChip(_ condition: Condition) -> some View {
        let isSelected = viewModel.condition == condition

        return Button {
            viewModel.condition = condition
        } label: {
            Text(condition.rawValue.capitalized)
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
                // A clear fill doesn't hit-test: without this an unselected
                // chip's padding took no tap (009 T014a).
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Shared field chrome

    /// The sale sheet's chrome, field for field: every field is a card, so
    /// every field is a plate, and the border stays a *validity* signal rather
    /// than a separator — it draws nothing but rust when invalid.
    private var fieldBackground: some View {
        PlateSurface()
    }

    @ViewBuilder
    private func fieldBorder(isInvalid: Bool) -> some View {
        if isInvalid {
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .strokeBorder(theme.colors.accentRust, lineWidth: theme.metrics.hairline)
        }
    }

    private func labelledField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(label).monoLabel()
            content()
                .padding(.vertical, theme.metrics.fieldPaddingVertical)
                .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
                .background(fieldBackground)
                .overlay(fieldBorder(isInvalid: false))
        }
    }

    /// - Parameter label: what the field *is*, for VoiceOver. Separate from
    ///   the prompt on purpose: "eBay, Reverb, a friend…" is a hint, and it's
    ///   the only thing someone would hear without this.
    private func plainTextField(
        _ prompt: String,
        label: String,
        text: Binding<String>
    ) -> some View {
        TextField(
            prompt,
            text: text,
            prompt: Text(prompt).foregroundStyle(theme.colors.textInactive)
        )
        .font(theme.typography.body)
        .foregroundStyle(theme.colors.textPrimary)
        .tint(theme.colors.accentBrass)
        .autocorrectionDisabled()
        .accessibilityLabel(label)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PurchaseFormView(
                viewModel: PurchaseFormViewModel(estimatedCostCents: 240_000),
                confirm: { _ in },
                cancel: {}
            )
        }
        .environment(\.theme, .dark)
        .preferredColorScheme(.dark)
}
