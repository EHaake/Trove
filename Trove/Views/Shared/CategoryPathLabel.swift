import SwiftUI

/// A category path read out as a breadcrumb — `Music → Amps` rather than
/// `Music/Amps`.
///
/// The slash is storage and typing syntax; it isn't how a path should read
/// back to someone. This is display only: the text field still takes literal
/// slashes, and what's saved is still slash-delimited.
///
/// Works on partial paths too, so a disambiguated chip label like
/// `Music/Amps` renders the same way as a full one.
struct CategoryPathLabel: View {
    let path: String
    /// The arrow sits quieter than the segments either side of it, so the
    /// words stay the thing being read.
    var separatorColor: Color?

    @Environment(\.theme) private var theme

    private var segments: [String] {
        path.split(separator: "/").map(String.init)
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(separatorColor ?? theme.colors.textQuiet)
                }
                Text(segment)
            }
        }
        .accessibilityElement(children: .ignore)
        // Read as a path, not as a string of disconnected words.
        .accessibilityLabel(segments.joined(separator: ", "))
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 14) {
            CategoryPathLabel(path: "Photography/Cameras")
            CategoryPathLabel(path: "Music/Guitars/Electric")
            CategoryPathLabel(path: "Accessories")
        }
        .font(Theme.dark.typography.formInput)
        .foregroundStyle(Theme.dark.colors.textPrimary)
    }
    .environment(\.theme, .dark)
}
