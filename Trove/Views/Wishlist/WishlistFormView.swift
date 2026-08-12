import SwiftData
import SwiftUI

/// Add or edit a wishlist item, following
/// `design/screens/Trove Wishlist Form.png`: what you want, its category, what
/// you think it'll cost, photos, and notes.
///
/// Shorter than the item form and with no disclosure — there are only five
/// fields, and none of them is optional enough to hide. Design drew this
/// screen without a photo field; spec.md has since brought wishlist photos
/// into scope, and they use the same `PhotoPickerField` the item form does
/// rather than a second, wishlist-shaped one.
struct WishlistFormView: View {
    @State private var viewModel: WishlistFormViewModel

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    init(modelContext: ModelContext, editing item: WishlistItem? = nil) {
        _viewModel = State(
            initialValue: WishlistFormViewModel(modelContext: modelContext, editing: item)
        )
    }

    private var title: String { viewModel.isEditing ? "Edit wanted item" : "Add wanted item" }

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
                        costField
                        desireField
                        // After the required trio, before notes — the same
                        // order the item form uses among its optional fields,
                        // since the two sit one tab apart.
                        PhotoPickerField(photos: $viewModel.photos)
                        notesField
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
        .onAppear(perform: viewModel.loadCategorySuggestions)
    }

    // MARK: - Fields

    /// Design labels this "WHAT DO YOU WANT" rather than "Name" — the one
    /// place the wishlist form deliberately doesn't mirror the item form,
    /// because the question really is different.
    private var nameField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("What do you want").monoLabel()
            TextField(
                "What do you want",
                text: $viewModel.name,
                prompt: Text("Summicron 35mm f/2").foregroundStyle(theme.colors.textInactive)
            )
            .font(theme.typography.formInput)
            .foregroundStyle(theme.colors.textPrimary)
            .tint(theme.colors.accentBrass)
            .autocorrectionDisabled()
            // A `prompt:` takes the placeholder slot and leaves the title
            // unused, so without this the field is named after the example.
            .accessibilityLabel("What do you want")
            .padding(.vertical, theme.metrics.fieldPaddingVertical)
            .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
            .background(fieldBackground)
            .overlay(fieldBorder(isInvalid: viewModel.validationErrors.contains(.nameMissing)))
        }
    }

    /// The cost gets the hero treatment Design gives it — this is the number
    /// the whole screen is about — with the quick-picks beneath.
    private var costField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("Estimated cost").monoLabel()

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: Currency.symbol(for: "USD"))
                    .font(theme.typography.monoValue)
                    .foregroundStyle(theme.colors.textQuiet)
                TextField(
                    "0",
                    value: $viewModel.estimatedCost,
                    format: .number.precision(.fractionLength(0...2))
                )
                .font(theme.typography.heroFigureSecondary)
                .foregroundStyle(theme.colors.accentBrass)
                .tint(theme.colors.accentBrass)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Estimated cost")
            }
            .padding(.vertical, theme.metrics.fieldPaddingVertical)
            .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
            .background(fieldBackground)
            .overlay(fieldBorder(isInvalid: viewModel.validationErrors.contains(.costMissing)
                || viewModel.validationErrors.contains(.costNegative)))

            presets
        }
    }

    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(WishlistFormViewModel.costPresets, id: \.self) { amount in
                let isSelected = viewModel.isSelected(preset: amount)

                Button {
                    viewModel.estimatedCost = amount
                } label: {
                    Text(Money.cents(from: amount).formattedAsWholeCurrency(currencyCode: "USD"))
                        .font(theme.typography.secondary)
                        .foregroundStyle(isSelected ? theme.colors.accentBrass : theme.colors.textBody)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                                .fill(isSelected ? theme.colors.accentBrassTint : Color.clear)
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
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// Labeled here, unlabeled in list rows — this is where the user sets the
    /// value and learns what the three levels mean, so the word carries its
    /// weight; repeating it down every row of a scrolling list wouldn't.
    private var desireField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("How much do you want it").monoLabel()
            DesireGauge(
                value: $viewModel.desireToOwn,
                segmentSize: CGSize(width: 30, height: 18),
                showsLabel: true,
                isInteractive: true
            )
            .padding(.vertical, theme.metrics.fieldPaddingVertical)
            .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fieldBackground)
            .overlay(fieldBorder(isInvalid: false))
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text("Notes").monoLabel()
            TextField(
                "Notes",
                text: $viewModel.notes,
                prompt: Text("Version, seller, condition you'd accept.")
                    .foregroundStyle(theme.colors.textInactive),
                axis: .vertical
            )
            .lineLimit(4...8)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
            .tint(theme.colors.accentBrass)
            .accessibilityLabel("Notes")
            .padding(.vertical, theme.metrics.fieldPaddingVertical)
            .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
            .background(fieldBackground)
            .overlay(fieldBorder(isInvalid: false))
        }
    }

    // MARK: - Save

    private var saveBar: some View {
        VStack(spacing: 10) {
            Divider().overlay(theme.colors.divider)

            Button(action: save) {
                Text(viewModel.isEditing ? "Save changes" : "Save to wishlist")
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

    /// Design's caption here reads "APPEARS IN SELL PLANS RIGHT AWAY", which
    /// describes the wrong direction — a wishlist item *has* a sell plan, it
    /// doesn't appear in other items'. This says what's true instead.
    private var saveCaption: String {
        validationSummary ?? "Saves to your wishlist on this device"
    }

    private var validationSummary: String? {
        let errors = viewModel.validationErrors
        guard !errors.isEmpty else { return nil }

        var missing: [String] = []
        if errors.contains(.nameMissing) { missing.append("a name") }
        if errors.contains(.categoryMissing) { missing.append("category") }
        if errors.contains(.costMissing) { missing.append("an estimated cost") }
        if errors.contains(.costNegative) { missing.append("a cost of zero or more") }

        return "Needs \(missing.formatted(.list(type: .and)))"
    }

    private func save() {
        if viewModel.save() { dismiss() }
    }

    // MARK: - Shared chrome

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
}

#Preview {
    let container = try! ModelContainer(
        for: TroveSchema.schema,
        configurations: ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
    context.insert(Item(name: "Blues Junior", categoryPath: "Music/Amps"))

    return NavigationStack {
        WishlistFormView(modelContext: context)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}
