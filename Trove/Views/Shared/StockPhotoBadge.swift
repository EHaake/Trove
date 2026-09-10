import SwiftUI

/// The **Stock photo** capsule that marks a fetched image as representative,
/// never an owned one (spec criterion 3). One shared component, placed by the
/// picker (T008), the carousel (T009) and the rows (T011) — never rebuilt per
/// screen.
///
/// It carries its own near-opaque dark ground so it holds legibly over both a
/// light and a dark image; placement (`top:12 left:12` over the photo) belongs
/// to the caller, the capsule itself is all this view draws.
///
/// The label reads `StockPhotoCopy.badge` ("Stock photo") and renders it in the
/// app's all-caps mono label idiom via `.textCase(.uppercase)` — the stored
/// string is unchanged, the casing is style. Its VoiceOver label is
/// `StockPhotoCopy.badgeAccessibilityLabel` ("Representative stock image").
///
/// Flagged local exception to the theme's "roles only" rule: this chip carries
/// its own ground and border, so its border (ivory 14 %) and glyph (ivory 72 %)
/// have no exact theme token and are drawn as literal opacities on the ink
/// color (`textPrimary`), the way the badge artboard specifies.
struct StockPhotoBadge: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 12, weight: .regular))
                // ivory 72 % — no exact token; flagged local exception (see above).
                .foregroundStyle(theme.colors.textPrimary.opacity(0.72))

            Text(StockPhotoCopy.badge)
                .textCase(.uppercase)
                .font(theme.typography.monoLabel)
                .tracking(theme.metrics.monoLabelTracking)
                .foregroundStyle(theme.colors.textBody)
        }
        .padding(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 9))
        .background {
            // ≈ `background` at 90 % — the chip's own near-opaque dark ground.
            Capsule().fill(theme.colors.background.opacity(0.9))
        }
        .overlay {
            // ivory 14 % — no exact token; flagged local exception (see above).
            Capsule().strokeBorder(theme.colors.textPrimary.opacity(0.14), lineWidth: 1)
        }
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StockPhotoCopy.badgeAccessibilityLabel)
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        StockPhotoBadge()
    }
    .environment(\.theme, .dark)
}
