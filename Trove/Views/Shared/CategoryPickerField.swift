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

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

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

    private var isExactMatch: Bool {
        suggestions.contains { $0.caseInsensitiveCompare(categoryPath) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(label).monoLabel()

            textField

            if !matches.isEmpty {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(matches, id: \.self, content: chip)
                }
                .padding(.top, 2)
            }
        }
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
        .padding(.vertical, theme.metrics.fieldPaddingVertical)
        .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .fill(theme.colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                .strokeBorder(
                    isFocused ? theme.colors.accentBrass : theme.colors.divider,
                    lineWidth: theme.metrics.hairline
                )
        )
    }

    private func chip(_ path: String) -> some View {
        let isSelected = path.caseInsensitiveCompare(categoryPath) == .orderedSame

        return Button {
            categoryPath = path
            isFocused = false
        } label: {
            Text(path)
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
