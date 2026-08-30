import SwiftUI

/// `010`'s "extruded plate" treatment (tokens.md's "Row treatment" table):
/// the flat `surface` rectangle gains a 1px ivory top edge, a 1px dark
/// bottom edge, and a soft cast shadow. The border is gone on purpose — the
/// bevel does the separating. Depth comes entirely from alphas layered over
/// the existing `surface`, never a rendered material, which is what keeps
/// this inside `brief.md`'s amended skeuomorphism boundary.
///
/// Shared because every card in the app is one treatment, not several: list
/// rows, detail cards, the dashboard's figures, the search field, photo
/// heroes and every form field all draw this. The rule the `010` review
/// settled on is simply "any rectangle whose background differs from the
/// screen's" — so a new card gets the plate by default, and *not* having it
/// is what needs a reason.
///
/// This type is the plate as a drawable surface; `.extrudedPlate()` is the
/// same thing as a wrapper. Both exist because the form screens hand their
/// field chrome to `.background(_:)` and compose a validity border on top —
/// they need the plate as a thing, not as a modifier.
struct PlateSurface: View {
    @Environment(\.theme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
            .fill(theme.colors.surface)
            .overlay(alignment: .top) {
                theme.colors.plateHighlight.frame(height: theme.metrics.hairline)
            }
            .overlay(alignment: .bottom) {
                theme.colors.plateEdgeShadow.frame(height: theme.metrics.hairline)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
            // tokens.md's `0 2px 6px` — SwiftUI's blur radius is half the CSS
            // pixel blur, hence 3.
            .shadow(color: theme.colors.plateCastShadow, radius: 3, x: 0, y: 2)
    }
}

struct ExtrudedPlate: ViewModifier {
    func body(content: Content) -> some View {
        content.background { PlateSurface() }
    }
}

/// The plate's inner bevel alone — no corner radius, no cast shadow.
///
/// For cells that sit *inside* a plate rather than being one: the item
/// detail's WORTH NOW / PAID pair is two bevelled cells split by a hairline
/// seam, clipped and shadowed once as a unit. Rounding and shadowing each
/// cell separately would draw a shadow through the seam.
struct PlateBevel: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background {
                theme.colors.surface
                    .overlay(alignment: .top) {
                        theme.colors.plateHighlight.frame(height: theme.metrics.hairline)
                    }
                    .overlay(alignment: .bottom) {
                        theme.colors.plateEdgeShadow.frame(height: theme.metrics.hairline)
                    }
            }
    }
}

extension View {
    /// The extruded-plate card/row background — see `ExtrudedPlate`.
    func extrudedPlate() -> some View { modifier(ExtrudedPlate()) }

    /// The plate's bevel without its radius or shadow — see `PlateBevel`.
    func plateBevel() -> some View { modifier(PlateBevel()) }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 10) {
            Text("An extruded plate")
                .foregroundStyle(Theme.dark.colors.textPrimary)
                .padding(Theme.dark.metrics.rowPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .extrudedPlate()
        }
        .padding(24)
    }
    .environment(\.theme, .dark)
}
