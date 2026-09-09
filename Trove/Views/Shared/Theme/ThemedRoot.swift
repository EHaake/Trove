import SwiftUI

/// The thin root wrapper that turns the appearance choice into the two
/// modifiers the app used to hardcode: the injected `\.theme` palette and the
/// `.preferredColorScheme` that keeps system-drawn chrome (keyboards, pickers,
/// selection) matching it (plan.md §4, Q5).
///
/// It reads `@Environment(\.colorScheme)` so that under `.system` a device
/// flip re-renders it live (criterion 3), and because `AppearanceStore` is
/// `@Observable`, a choice change in Settings re-renders it with no relaunch
/// (criterion 4). `ContentView` is untouched — it still reads
/// `@Environment(\.theme)`, now supplied here instead of by `TroveApp`.
///
/// Only `.system` consults `colorScheme`: an explicit `.light`/`.dark` choice
/// resolves its palette without it, so the theme never depends on
/// `.preferredColorScheme` feeding back into this view's own `colorScheme`
/// (`AppearanceChoice+Theme.swift`, plan.md Q1).
struct ThemedRoot<Content: View>: View {
    @Bindable var appearanceStore: AppearanceStore
    @Environment(\.colorScheme) private var systemColorScheme
    private let content: Content

    init(appearanceStore: AppearanceStore, @ViewBuilder content: () -> Content) {
        self.appearanceStore = appearanceStore
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.theme, appearanceStore.choice.resolvedTheme(systemColorScheme: systemColorScheme))
            .preferredColorScheme(appearanceStore.choice.preferredColorScheme)
    }
}
