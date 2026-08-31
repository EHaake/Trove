import SwiftUI

/// The list screens' search box, per `design/screens/Trove Item List.png`: a
/// filled field sitting under the header and above the category chips, inside
/// the fixed block so it stays reachable while the rows scroll.
///
/// Design's placeholder reads "Search name, brand, serial". There is no brand
/// in the schema — the same gap `ItemRow`'s meta line works around — so the
/// placeholder names only the fields that are really searched. Promising brand
/// search in the one place the user would test it is worse than the gap.
///
/// Shared rather than written per screen: the wishlist list gets the same
/// control, and the two have to look and behave identically.
struct SearchField: View {
    var placeholder: String = "Search"
    @Binding var text: String

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.colors.textQuiet)

            TextField(
                placeholder,
                text: $text,
                prompt: Text(placeholder).foregroundStyle(theme.colors.textInactive)
            )
            .focused($isFocused)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
            .tint(theme.colors.accentBrass)
            // Serial numbers are case-sensitive-looking strings the user is
            // copying off a body plate; autocapitalising the first character
            // would fight every one of them.
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            // The placeholder covers an empty field, and then disappears the
            // moment anything is typed — leaving a field announcing its
            // contents with no name attached.
            .accessibilityLabel(placeholder)

            // Not in the mock, which only ever drew the empty state. Getting
            // back to the full list otherwise means holding backspace.
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.colors.textQuiet)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.metrics.fieldPaddingHorizontal)
        .frame(height: theme.metrics.searchFieldHeight)
        .extrudedPlate()
        .contentShape(Rectangle())
        // The field is 40pt tall and the glyphs inside it are small, so the
        // whole box takes the tap rather than just the text baseline.
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    @Previewable @State var empty = ""
    @Previewable @State var typed = "leica"

    return ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 16) {
            SearchField(placeholder: "Search name or serial", text: $empty)
            SearchField(placeholder: "Search name or serial", text: $typed)
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}
