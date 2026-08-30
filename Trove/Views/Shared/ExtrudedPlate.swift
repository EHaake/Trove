import SwiftUI

/// `010`'s "extruded plate" treatment (tokens.md's "Row treatment" table):
/// the flat `surface` rectangle gains a 1px ivory top edge, a 1px dark
/// bottom edge, and a soft cast shadow. The border is gone on purpose — the
/// bevel does the separating. Depth comes entirely from alphas layered over
/// the existing `surface`, never a rendered material, which is what keeps
/// this inside `brief.md`'s amended skeuomorphism boundary.
///
/// Shared because the list rows and the detail screens' cards are one
/// treatment, not two — tokens.md says it applies uniformly, resting or
/// swiped open.
struct ExtrudedPlate: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: theme.metrics.cardRadius)
                    .fill(theme.colors.surface)
                    .overlay(alignment: .top) {
                        theme.colors.plateHighlight
                            .frame(height: theme.metrics.hairline)
                    }
                    .overlay(alignment: .bottom) {
                        theme.colors.plateEdgeShadow
                            .frame(height: theme.metrics.hairline)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
                    // tokens.md's `0 2px 6px` — SwiftUI's blur radius is half
                    // the CSS pixel blur, hence 3.
                    .shadow(color: theme.colors.plateCastShadow, radius: 3, x: 0, y: 2)
            }
    }
}

extension View {
    /// The extruded-plate card/row background — see `ExtrudedPlate`.
    func extrudedPlate() -> some View { modifier(ExtrudedPlate()) }
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
