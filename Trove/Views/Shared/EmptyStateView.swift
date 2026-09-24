import SwiftUI

/// What a screen shows when it has nothing to show: a mark, a headline, a line
/// of explanation, and usually something to do about it.
///
/// One component for every empty state in the app — both lists, the dashboard,
/// and the Sell Plan's candidate pool — because they're the same shape and
/// should read as the same idea. The differences that matter are the words and
/// the mark, which is exactly what the caller supplies.
///
/// **Centred, unlike everything else in the app.** The rest of Trove is
/// left-aligned, and this deliberately isn't: content pinned to the top-left of
/// an otherwise blank screen reads as a screen that failed to finish loading,
/// while a centred block reads as a state someone designed. `SellPlanView`'s
/// "this item is gone" already did this before there was a component to share.
///
/// The voice is `design/brief.md`'s: "empty states are an invitation to act,
/// not an apology". Nothing here says sorry, and every case that has an action
/// offers it rather than describing it.
struct EmptyStateView: View {
    /// The glyph above the headline.
    enum Mark {
        case system(String)
        /// One of the tab icons in `Assets.xcassets`, used when the point is
        /// "this screen is empty" rather than "this filter found nothing" —
        /// the screen's own mark says which screen you're on.
        case asset(String)

        /// The mark all four "catching up with iCloud" states share.
        ///
        /// Named once because `Image(systemName:)` draws nothing at all for a
        /// symbol that doesn't exist — the same silent failure `TabIconTests`
        /// exists for — and four copies of a string is four chances to get it
        /// wrong. `EmptyStateMarkTests` checks this one resolves.
        static let stillSyncing = Mark.system("icloud.and.arrow.down")
    }

    struct Action {
        let label: String
        /// Filled brass for adding — the same treatment the forms give "Save
        /// item", because it's the action the brief says these screens exist to
        /// point at. Outlined for undoing a narrowing: still an invitation, but
        /// it shouldn't out-shout the add button on a neighbouring screen.
        var isProminent: Bool = false
        let perform: () -> Void
    }

    let mark: Mark
    let headline: String
    var detail: String?
    var action: Action?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.metrics.cardPadding) {
            markView
                .foregroundStyle(theme.colors.textInactive)
                .padding(.bottom, 4)

            Text(headline)
                .font(theme.typography.emptyStateTitle)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.center)

            if let detail {
                Text(detail)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textQuiet)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    // Long enough to read as a sentence, short enough not to
                    // run the full width of the screen at the centre of it.
                    .frame(maxWidth: 300)
            }

            if let action {
                button(action).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.metrics.screenGutter)
        // Sits a little above true centre: optically centred beats
        // mathematically centred when there's a tab bar weighting the bottom.
        .padding(.bottom, theme.metrics.sectionGap * 2)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 34, weight: .light))
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 38, height: 38)
        }
    }

    private func button(_ action: Action) -> some View {
        Button(action: action.perform) {
            Text(action.label)
                .font(theme.typography.body)
                .foregroundStyle(action.isProminent ? theme.colors.background : theme.colors.accentBrass)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background {
                    if action.isProminent {
                        Capsule().fill(theme.colors.accentBrass)
                    } else {
                        Capsule().strokeBorder(
                            theme.colors.accentBrass,
                            lineWidth: theme.metrics.hairline
                        )
                    }
                }
                // The outlined variant draws no fill, so without this its
                // padding took no tap (009 T014a).
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Nothing added") {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        EmptyStateView(
            mark: .asset("TabItems"),
            headline: "No gear yet",
            detail: "Everything you add shows up here, with what you paid and what it's worth now.",
            action: .init(label: "Add an item", isProminent: true) {}
        )
    }
    .environment(\.theme, .dark)
}

#Preview("Search found nothing") {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        EmptyStateView(
            mark: .system("magnifyingglass"),
            headline: "No matches for \u{201C}nikon\u{201D}",
            detail: "Names and serial numbers are what's searched.",
            action: .init(label: "Clear search") {}
        )
    }
    .environment(\.theme, .dark)
}
