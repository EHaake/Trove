import SwiftUI

/// The sale sheet — Mark as sold and Edit sale, one component in two modes
/// (006 plan §5; the visuals are `design/elements/006-mark-as-sold/SheetFilled`
/// and `SheetInvalid`).
///
/// It is hosted from the item detail page and from a Sell Plan row, and it
/// writes nothing itself: confirming hands `SaleFormViewModel.sale()`'s value
/// to `confirm`, and whoever presented the sheet decides what to record. That
/// is why this file never touches a `ModelContext` — the same rule the
/// deletion guard already holds every view to.
///
/// The fields wear the item form's chrome, because the spec asks for exactly
/// that: the money field's `$` prefix and decimal pad, and the date button
/// with the calendar popover behind it rather than a system date chip. The
/// one difference from `ItemFormView.dateField` is the bound —
/// `in: ...viewModel.latestDate` — so a future day cannot be picked at all
/// (spec P2). The bound is the courtesy; `sale()`'s check is what actually
/// refuses one.
///
/// Every word comes from `SaleCopy`, never typed here, so the sheet and the
/// sold page cannot drift apart.
struct SaleFormView: View {
    @State private var viewModel: SaleFormViewModel
    private let confirm: (Sale) -> Void
    private let cancel: () -> Void

    @State private var showsDatePicker = false

    @Environment(\.theme) private var theme

    /// The view model is made by the host screen (`makeSaleFormViewModel()`),
    /// so the mode and the seed both come from there. Held in `@State`, so the
    /// sheet's body being re-evaluated doesn't throw away what's been typed.
    init(
        viewModel: SaleFormViewModel,
        confirm: @escaping (Sale) -> Void,
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
                        priceAndDate
                        soldAtField
                        noteField
                    }
                    .padding(.horizontal, theme.metrics.screenGutter)
                    .padding(.top, theme.metrics.sectionGap)
                    .padding(.bottom, theme.metrics.sectionGap)
                }
                // Four short fields don't fill the medium detent, and a form
                // that rubber-bands over empty space reads as broken.
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SaleCopy.cancel, action: cancel)
                        .foregroundStyle(theme.colors.textBody)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.confirmLabel, action: record)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.colors.accentBrass)
                        .accessibilityIdentifier("sale.sheet.confirm")
                }
            }
        }
        // The Design pass's size: the content sits at roughly the medium
        // detent, and the sheet has somewhere to go when the keyboard rises.
        .presentationDetents([.medium, .large])
    }

    /// Confirming validates first. An invalid sheet stays open with the rust
    /// border on the price and no message — the Design pass's invalid state,
    /// and the only one reachable here, since the picker's bound means a
    /// future date can't be chosen in the first place.
    private func record() {
        guard let sale = viewModel.sale() else { return }
        confirm(sale)
    }

    // MARK: - Fields

    /// Sale price and Sold on, paired on one row, `ItemFormView.priceAndDate`'s
    /// layout down to the equal-height trick: a `TextField` sits a couple of
    /// points taller than the date button's plain `Text`, and two side-by-side
    /// cards of different heights read as a mistake.
    private var priceAndDate: some View {
        HStack(alignment: .top, spacing: theme.metrics.listRowGap) {
            VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                Text(SaleCopy.salePriceLabel).monoLabel()
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
                    .accessibilityLabel(SaleCopy.salePriceLabel)
                    .accessibilityIdentifier("sale.sheet.price")
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

    /// The item form's date field with a ceiling on it: the button wears the
    /// same chrome as every other field, and the popover behind it holds the
    /// real picker, bounded at `viewModel.latestDate` so no future day is
    /// selectable (spec P2). Read from the view model on each pass rather than
    /// captured, so a sheet left open across midnight isn't stale.
    ///
    /// Two digits each, locale-ordered, exactly as the purchase date reads.
    private var dateField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(SaleCopy.soldOnLabel).monoLabel()

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
            .accessibilityLabel(SaleCopy.soldOnLabel)
            .accessibilityValue(viewModel.date.formatted(date: .long, time: .omitted))
            .popover(isPresented: $showsDatePicker) {
                DatePicker(
                    SaleCopy.soldOnLabel,
                    selection: $viewModel.date,
                    in: ...viewModel.latestDate,
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

    private var soldAtField: some View {
        labelledField(SaleCopy.soldAtLabel) {
            plainTextField(SaleCopy.soldAtPlaceholder, label: SaleCopy.soldAtLabel, text: $viewModel.location)
        }
    }

    private var noteField: some View {
        labelledField(SaleCopy.noteLabel) {
            plainTextField(SaleCopy.notePlaceholder, label: SaleCopy.noteLabel, text: $viewModel.note)
        }
    }

    // MARK: - Shared field chrome

    /// `ItemFormView`'s chrome, field for field: every field is a card, so
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
            SaleFormView(
                viewModel: SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: 120_000),
                confirm: { _ in },
                cancel: {}
            )
        }
        .environment(\.theme, .dark)
        .preferredColorScheme(.dark)
}
