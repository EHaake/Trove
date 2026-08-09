import SwiftUI

/// The active look of the app, injected through the environment.
///
/// v1 ships `.dark` only (spec.md defers light mode and alternate palettes).
/// The whole point of the shape is that adding one later is
/// `.environment(\.theme, .someOtherTheme)` at the root rather than a sweep
/// through every view — which holds only as long as views read colors, type
/// and spacing from here instead of writing their own.
struct Theme: Sendable {
    let colors: ThemeColors
    let typography: ThemeTypography
    let metrics: ThemeMetrics

    static let dark = Theme(
        colors: .dark,
        typography: .standard,
        metrics: .standard
    )
}

extension EnvironmentValues {
    @Entry var theme: Theme = .dark
}

// MARK: - Shared text treatments

/// The all-caps mono label above form fields and section headers. It appears
/// on essentially every screen in `design/screens/`, and it's three separate
/// decisions (font, tracking, case) that have to agree every time — so it's
/// one modifier rather than three lines repeated per label.
private struct MonoLabelStyle: ViewModifier {
    @Environment(\.theme) private var theme
    let color: Color?

    func body(content: Content) -> some View {
        content
            .font(theme.typography.monoLabel)
            .tracking(theme.metrics.monoLabelTracking)
            .textCase(.uppercase)
            .foregroundStyle(color ?? theme.colors.textLabel)
    }
}

extension View {
    /// - Parameter color: overrides `textLabel`, for the places a label picks
    ///   up an accent (the dial's SELL/KEEP ends, for instance).
    func monoLabel(color: Color? = nil) -> some View {
        modifier(MonoLabelStyle(color: color))
    }
}
