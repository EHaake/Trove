import SwiftUI

/// The **Stock photo** mark that flags a fetched image as representative,
/// never an owned one (spec criterion 3). One shared component, placed by the
/// picker (T008), the carousel (T009) and the rows (T011) — never rebuilt per
/// screen.
///
/// Two styles, one component:
/// - `.full` — the labeled capsule (glyph + "STOCK PHOTO"), for the hero and
///   the detail carousel where there is room for words.
/// - `.mark` — a tiny glyph-only corner square, for list-row thumbnails where
///   the capsule would swamp a 52pt slot (the approved list-row artboard).
///
/// Both carry their own near-opaque dark ground so they hold legibly over both a
/// light and a dark image; placement over the photo belongs to the caller, the
/// mark itself is all this view draws.
///
/// The full label reads `StockPhotoCopy.badge` ("Stock photo") and renders it in
/// the app's all-caps mono label idiom via `.textCase(.uppercase)` — the stored
/// string is unchanged, the casing is style. Its VoiceOver label is
/// `StockPhotoCopy.badgeAccessibilityLabel` ("Representative stock image"). The
/// `.mark` variant is `.accessibilityHidden(true)`: the list row it sits on
/// carries the spoken announcement, so the mark must not add a second element.
///
/// Flagged local exception to the theme's "roles only" rule: this chip carries
/// its own ground and border, so its border (ivory 14 %/16 %) and glyph
/// (ivory 72 %) have no exact theme token and are drawn as literal opacities on
/// the ink color (`textPrimary`), the way the badge artboard specifies.
struct StockPhotoBadge: View {
    enum Style { case full; case mark }

    var style: Style = .full

    @Environment(\.theme) private var theme

    var body: some View {
        switch style {
        case .full: fullBadge
        case .mark: markBadge
        }
    }

    private var fullBadge: some View {
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

    /// The glyph-only corner mark for list rows: a 16×16 rounded square (3pt
    /// radius) holding only the photo-on-photo glyph. Sized to sit at the
    /// thumbnail's top-left corner (the caller insets it 4pt). Hidden from
    /// accessibility — the row announces the stock image itself.
    private var markBadge: some View {
        Image(systemName: "photo.on.rectangle")
            .font(.system(size: 10, weight: .regular))
            // ivory 72 % — no exact token; flagged local exception (see above).
            .foregroundStyle(theme.colors.textPrimary.opacity(0.72))
            .frame(width: 16, height: 16)
            .background {
                // ≈ `background` at 90 % — the mark's own near-opaque dark ground.
                RoundedRectangle(cornerRadius: 3).fill(theme.colors.background.opacity(0.9))
            }
            .overlay {
                // ivory 16 % — the mark's border (note: 16 %, not the full
                // badge's 14 %); no exact token, flagged local exception.
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(theme.colors.textPrimary.opacity(0.16), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 16) {
            StockPhotoBadge()
            StockPhotoBadge(style: .mark)
        }
    }
    .environment(\.theme, .dark)
}
