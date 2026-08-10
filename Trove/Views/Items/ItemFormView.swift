import SwiftData
import SwiftUI

/// Add or edit an owned item, following `design/screens/Trove Item Form.png`.
///
/// The four required fields lead; everything optional sits behind "More
/// details". The spec's quick-add bar is the reason — this screen gets used
/// constantly and shouldn't march the user through fields they don't have to
/// hand.
struct ItemFormView: View {
    @State private var viewModel: ItemFormViewModel
    @State private var showsMoreDetails = false
    @State private var showsDatePicker = false

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    init(modelContext: ModelContext, editing item: Item? = nil) {
        _viewModel = State(initialValue: ItemFormViewModel(modelContext: modelContext, editing: item))
    }

    private var title: String { viewModel.isEditing ? "Edit item" : "Add item" }

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                        nameField
                        CategoryPickerField(
                            suggestions: viewModel.categorySuggestions,
                            categoryPath: $viewModel.categoryPath,
                            isInvalid: viewModel.validationErrors.contains(.categoryMissing)
                        )
                        priceAndDate
                        desireCard
                        moreDetails
                    }
                    .padding(.horizontal, theme.metrics.screenGutter)
                    .padding(.top, theme.metrics.sectionGap)
                    .padding(.bottom, theme.metrics.sectionGap)
                }

                saveBar
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(theme.colors.textBody)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .foregroundStyle(theme.colors.accentBrass)
            }
        }
        .onAppear {
            viewModel.loadCategorySuggestions()
            // An item being edited usually has optional fields filled in
            // already, so hiding them behind a closed disclosure would make
            // them look lost.
            showsMoreDetails = viewModel.isEditing
        }
    }

    // MARK: - Required fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("Name").monoLabel()
            TextField(
                "Name",
                text: $viewModel.name,
                prompt: Text("Leica M6").foregroundStyle(theme.colors.textInactive)
            )
            .font(theme.typography.formInput)
            .foregroundStyle(theme.colors.textPrimary)
            .tint(theme.colors.accentBrass)
            .autocorrectionDisabled()
            .padding(.vertical, theme.metrics.fieldPaddingVertical)
            .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
            .background(fieldBackground)
            .overlay(fieldBorder(isInvalid: viewModel.validationErrors.contains(.nameMissing)))
        }
    }

    private var priceAndDate: some View {
        HStack(alignment: .top, spacing: theme.metrics.listRowGap) {
            VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                Text("Price paid").monoLabel()
                HStack(spacing: 6) {
                    Text("$")
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textQuiet)
                    TextField(
                        "0",
                        value: $viewModel.purchasePrice,
                        format: .number.precision(.fractionLength(0...2))
                    )
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textPrimary)
                        .tint(theme.colors.accentBrass)
                        .keyboardType(.decimalPad)
                }
                .padding(.vertical, theme.metrics.fieldPaddingVertical)
                .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
                .background(fieldBackground)
                .overlay(fieldBorder(isInvalid: viewModel.validationErrors.contains(.priceNegative)
                    || viewModel.validationErrors.contains(.priceMissing)))
            }

            dateField
        }
    }

    /// A plain button wearing the same chrome as every other field, with the
    /// real picker in a popover behind it. A native `.compact` DatePicker
    /// brings its own grey chip, which reads as a system control dropped into
    /// the middle of the form.
    ///
    /// Two digits each, locale-ordered: Design's "14/03/19" is that format in
    /// a day-first locale, and this renders "03/14/19" in a month-first one —
    /// same compactness, right order for whoever's reading it.
    private var dateField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("Date bought").monoLabel()

            Button {
                showsDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Text(
                        viewModel.purchaseDate,
                        format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)
                    )
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)

                    Spacer(minLength: 0)

                    // The mock's small square outline. A flat graphic mark
                    // rather than an SF calendar glyph, per the brief.
                    RoundedRectangle(cornerRadius: 1)
                        .strokeBorder(theme.colors.textLabel, lineWidth: theme.metrics.hairline)
                        .frame(width: 15, height: 15)
                }
                .padding(.vertical, theme.metrics.fieldPaddingVertical)
                .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
                .background(fieldBackground)
                .overlay(fieldBorder(isInvalid: false))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Date bought")
            .accessibilityValue(viewModel.purchaseDate.formatted(date: .long, time: .omitted))
            .popover(isPresented: $showsDatePicker) {
                DatePicker(
                    "Date bought",
                    selection: $viewModel.purchaseDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(theme.colors.accentBrass)
                // A graphical picker reports a tiny ideal width, and the
                // popover honours it — without a floor the calendar collapses
                // into an unusable vertical sliver.
                .frame(minWidth: 320, minHeight: 350)
                .padding(theme.metrics.cardPadding)
                // Without this a popover becomes a full sheet on iPhone, which
                // is far heavier than picking a date warrants.
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var desireCard: some View {
        HStack(spacing: theme.metrics.cardPadding) {
            DesireDial(value: $viewModel.desireToKeep, diameter: 84, isInteractive: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Desire to keep").monoLabel()
                Text(DesireLevel(clamping: viewModel.desireToKeep).summary)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                HStack {
                    Text("Sell").monoLabel(color: theme.colors.accentRustText)
                    Spacer()
                    Text("Keep").monoLabel(color: theme.colors.accentBrass)
                }
                .padding(.top, 2)
            }
        }
        .padding(theme.metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
    }

    // MARK: - Optional fields

    private var moreDetails: some View {
        VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
            Divider().overlay(theme.colors.divider)

            Button {
                withAnimation(.snappy(duration: 0.22)) { showsMoreDetails.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("More details")
                            .font(theme.typography.rowTitle)
                            .foregroundStyle(theme.colors.textPrimary)
                        Text("Optional — add now or later")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textQuiet)
                    }
                    Spacer()
                    Image(systemName: showsMoreDetails ? "minus" : "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(theme.colors.accentBrass)
                }
                // Without this only the glyph reliably takes the tap — the
                // label and the gap between them don't, so the row looks
                // tappable across its width and mostly isn't.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsMoreDetails ? "Hide more details" : "Show more details")

            if showsMoreDetails {
                optionalFields
            }

            Divider().overlay(theme.colors.divider)
        }
    }

    private var optionalFields: some View {
        VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
            PhotoPickerField(photos: $viewModel.photos)

            labelledField("Current value") {
                HStack(spacing: 6) {
                    Text("$")
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textQuiet)
                    TextField(
                        "Not yet estimated",
                        value: $viewModel.currentValue,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textPrimary)
                    .tint(theme.colors.accentBrass)
                    .keyboardType(.decimalPad)
                }
            }

            VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
                Text("Condition").monoLabel()
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(Condition.allCases, id: \.self, content: conditionChip)
                }
            }

            labelledField("Condition notes") {
                plainTextField("Any specifics", text: $viewModel.conditionNotes)
            }
            labelledField("Serial number") {
                plainTextField("If it has one", text: $viewModel.serialNumber, isMono: true)
            }
            labelledField("Bought from") {
                plainTextField("Reverb, a shop, a person", text: $viewModel.purchaseLocation)
            }
            labelledField("Notes") {
                plainTextField("Anything worth remembering", text: $viewModel.notes)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

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
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Save

    private var saveBar: some View {
        VStack(spacing: 10) {
            Divider().overlay(theme.colors.divider)

            Button(action: save) {
                Text(viewModel.isEditing ? "Save changes" : "Save item")
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                            .fill(theme.colors.accentBrass)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, theme.metrics.screenGutter)

            Text(saveCaption)
                .monoLabel(color: validationSummary == nil ? theme.colors.textQuiet : theme.colors.accentRustText)
                .padding(.bottom, 4)
        }
        .padding(.top, 10)
        .background(theme.colors.background)
    }

    /// Design's caption says where the item goes. When something's missing,
    /// that slot says what instead of adding a second message somewhere else.
    private var saveCaption: String {
        validationSummary ?? "Saves to your library on this device"
    }

    private var validationSummary: String? {
        let errors = viewModel.validationErrors
        guard !errors.isEmpty else { return nil }

        var missing: [String] = []
        if errors.contains(.nameMissing) { missing.append("name") }
        if errors.contains(.categoryMissing) { missing.append("category") }
        if errors.contains(.priceMissing) { missing.append("a price") }
        if errors.contains(.priceNegative) { missing.append("a price of zero or more") }
        if errors.contains(.currentValueNegative) { missing.append("a value of zero or more") }

        return "Needs \(missing.formatted(.list(type: .and)))"
    }

    private func save() {
        if viewModel.save() { dismiss() }
    }

    // MARK: - Shared field chrome

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
            .fill(theme.colors.surface)
    }

    private func fieldBorder(isInvalid: Bool) -> some View {
        RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
            .strokeBorder(
                isInvalid ? theme.colors.accentRust : theme.colors.divider,
                lineWidth: theme.metrics.hairline
            )
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

    private func plainTextField(
        _ prompt: String,
        text: Binding<String>,
        isMono: Bool = false
    ) -> some View {
        TextField(
            prompt,
            text: text,
            prompt: Text(prompt).foregroundStyle(theme.colors.textInactive)
        )
        .font(isMono ? theme.typography.monoMeta : theme.typography.body)
        .foregroundStyle(theme.colors.textPrimary)
        .tint(theme.colors.accentBrass)
        .autocorrectionDisabled()
    }
}

#Preview {
    NavigationStack {
        ItemFormView(
            modelContext: ModelContext(
                try! ModelContainer(
                    for: TroveSchema.schema,
                    configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
                )
            )
        )
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
