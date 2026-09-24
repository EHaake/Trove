import SwiftUI

/// Category entry: a text field for the path plus chips for paths already in
/// use, filtered as the user types.
///
/// Design's mock shows chips alone, but the spec requires free typing — the
/// user builds their own hierarchy, and a chip row can't create a category
/// that doesn't exist yet. So both: the field is how a new path gets made, the
/// chips are the autocomplete, and tapping one fills the field.
///
/// Takes its suggestions rather than fetching them, so it stays a plain view
/// with no store access; the owning form supplies them from
/// `CategoryPathHelper`.
struct CategoryPickerField: View {
    var label: String = "Category"
    var placeholder: String = "Photography/Cameras"
    let suggestions: [String]
    @Binding var categoryPath: String
    /// Draws the same rust border the other required fields use when a save
    /// was rejected. Without it a form can name category as missing while the
    /// field itself looks perfectly fine.
    var isInvalid: Bool = false

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    /// Separate from `isFocused` on purpose. The text field only exists while
    /// editing, and focus can't be given to a view that isn't in the hierarchy
    /// yet — setting `isFocused` from the read-out silently did nothing.
    @State private var isEditingPath = false

    /// Filtered through the same rule the item and wishlist list filters use,
    /// so "matches what I typed" means one thing across the app.
    ///
    /// One exception: once the field holds an existing path exactly, the user
    /// has picked rather than searched, so the full set comes back and
    /// switching category stays one tap. Narrowing to the single chip they
    /// just tapped would mean clearing the field to change their mind, and the
    /// mock shows every chip with one highlighted.
    private var matches: [String] {
        guard !isExactMatch else { return suggestions }
        return suggestions.filter { CategoryPathHelper.path($0, matchesPrefix: categoryPath) }
    }

    /// The same leaf-with-disambiguation rule the item list's filter chips
    /// use, so a category is labelled identically wherever it appears.
    ///
    /// Computed over every suggestion rather than the filtered subset: a label
    /// that widened from "Amps" to "Music/Amps" as the user typed — because
    /// the colliding path dropped out of the matches — would be worse than
    /// either form on its own.
    private var chipLabels: [String: String] {
        CategoryPathHelper.displayLabels(for: suggestions)
    }

    private var isExactMatch: Bool {
        suggestions.contains { $0.caseInsensitiveCompare(categoryPath) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(label).monoLabel()

            // A set value reads back as a breadcrumb; typing gets the real
            // field, slashes and all. Tapping the read-out returns to editing.
            if showsReadOut {
                readOut
            } else {
                textField
            }

            if !matches.isEmpty {
                // One scrolling row, matching the item list's filter chips.
                // Wrapping made the field's height jump around as the user
                // typed and the match count changed.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(matches, id: \.self) { path in
                                chip(path).id(path)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                    // Editing an existing item opens with its category already
                    // set, and alphabetically that chip is often off to the
                    // right — where a single row hides it and wrapping didn't.
                    .onAppear {
                        guard let selected = matches.first(where: {
                            $0.caseInsensitiveCompare(categoryPath) == .orderedSame
                        }) else { return }
                        proxy.scrollTo(selected, anchor: .center)
                    }
                }
            }
        }
        // Hand focus over once the field actually exists. Lives on the
        // container, which survives the swap, rather than on the field.
        .onChange(of: isEditingPath) { _, isEditing in
            guard isEditing else { return }
            isFocused = true
        }
        // Finishing edits returns to the breadcrumb.
        .onChange(of: isFocused) { _, focused in
            guard !focused else { return }
            isEditingPath = false
        }
    }

    private var showsReadOut: Bool {
        Self.showsReadOut(
            isEditingPath: isEditingPath,
            isFocused: isFocused,
            categoryPath: categoryPath
        )
    }

    /// Whether the breadcrumb shows in place of the text field.
    ///
    /// `isFocused` is the part that isn't obvious, and leaving it out was a
    /// real bug that T044's click-through caught. An empty field shows the
    /// *text field* — there's no breadcrumb to render — so tapping it focuses
    /// the field directly and never goes through `isEditingPath`. The first
    /// character then made the path non-empty, this flipped to `true`, and
    /// SwiftUI tore the focused field out from under the user mid-word. Every
    /// keystroke after the first went nowhere, which broke the one thing this
    /// field exists for: typing a category that doesn't exist yet.
    ///
    /// A focused field is never swapped out. Static and separate so the rule
    /// can be tested, since the bug is in the rule rather than in the drawing.
    static func showsReadOut(isEditingPath: Bool, isFocused: Bool, categoryPath: String) -> Bool {
        guard !isEditingPath, !isFocused else { return false }
        return !categoryPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var readOut: some View {
        Button {
            isEditingPath = true
        } label: {
            CategoryPathLabel(path: categoryPath)
                .font(theme.typography.formInput)
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, theme.metrics.fieldPaddingVertical)
                .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
                .background(PlateSurface())
                .overlay(stateBorder)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(categoryPath.split(separator: "/").joined(separator: ", "))")
        .accessibilityHint("Edit")
    }

    private var textField: some View {
        TextField(
            label,
            text: $categoryPath,
            prompt: Text(placeholder).foregroundStyle(theme.colors.textInactive)
        )
        .focused($isFocused)
        .font(theme.typography.formInput)
        .foregroundStyle(theme.colors.textPrimary)
        .tint(theme.colors.accentBrass)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        // The `prompt:` above takes the placeholder slot, which leaves the
        // field with no accessibility label — VoiceOver would read the example
        // path as though it were the field's name. The read-out already sets
        // its own; this is the editing half.
        .accessibilityLabel(label)
        .padding(.vertical, theme.metrics.fieldPaddingVertical)
        .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
        .background(PlateSurface())
        .overlay(stateBorder)
    }

    /// Focus wins over the invalid state — once the user is fixing the field,
    /// telling them it's still wrong is noise.
    ///
    /// `nil` in the resting state since `010`: the plate's bevel does the
    /// separating every other field's does, so a border here would say
    /// "something is going on with this field" when nothing is. What's left
    /// is state — brass for focus, rust for invalid — matching the rule the
    /// two form screens' own fields follow.
    private var borderColor: Color? {
        if isFocused { return theme.colors.accentBrass }
        return isInvalid ? theme.colors.accentRust : nil
    }

    @ViewBuilder
    private var stateBorder: some View {
        if let borderColor {
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .strokeBorder(borderColor, lineWidth: theme.metrics.hairline)
        }
    }

    private func chip(_ path: String) -> some View {
        let isSelected = path.caseInsensitiveCompare(categoryPath) == .orderedSame

        return Button {
            categoryPath = path
            isFocused = false
            isEditingPath = false
        } label: {
            CategoryPathLabel(
                path: chipLabels[path] ?? path,
                separatorColor: isSelected ? theme.colors.accentBrass : theme.colors.textQuiet
            )
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
}

#Preview("Empty") {
    CategoryPickerFieldPreview(initialPath: "")
}

#Preview("Typing") {
    CategoryPickerFieldPreview(initialPath: "photo")
}

#Preview("Selected") {
    CategoryPickerFieldPreview(initialPath: "Photography/Cameras")
}

private struct CategoryPickerFieldPreview: View {
    let initialPath: String
    @State private var path: String = ""

    private static let samplePaths = [
        "Photography/Cameras",
        "Photography/Lenses",
        "Music/Guitars/Electric",
        "Music/Amps",
        "Audio/Headphones",
        "Accessories",
    ]

    var body: some View {
        ZStack {
            Theme.dark.colors.background.ignoresSafeArea()
            CategoryPickerField(suggestions: Self.samplePaths, categoryPath: $path)
                .padding(Theme.dark.metrics.screenGutter)
        }
        .environment(\.theme, .dark)
        .onAppear { path = initialPath }
    }
}
