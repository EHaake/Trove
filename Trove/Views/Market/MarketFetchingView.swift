import SwiftUI

/// The match sheet's third phase — the picked candidate's listings being
/// fetched (spec Decision 33, plan Amendment B; there is no artboard for
/// it: it is the picker's own card and status line, held still).
///
/// A pick now runs that product's refresh inside the same sheet, and the
/// sheet must not go blank while it does. So this shows exactly what was
/// picked — `MarketCandidateCard`, plated as the picker plates it — under
/// the picker's bar and inside the picker's padding, with the picker's
/// status-line pattern reading "Fetching asking prices…". The card comes
/// first and the line beneath it: the card answers "what did I tap?", the
/// line answers "what is happening now?".
///
/// No Cancel: the fetch has no cancel intent, and the swipe-down the detail
/// screens already handle is the way out — an outcome landing after it
/// updates the section and never re-presents the sheet (plan Amendment B,
/// the landing rule). Nothing here is a control at all.
///
/// Every word comes from `MarketCopy`; this file may not contain a string
/// literal with a space in it, and `MarketVocabularyTests` holds it to that.
struct MarketFetchingView: View {
    let candidate: MarketCandidate

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: MarketMatchView.contentGap) {
                    MarketCandidateCard(candidate: candidate)
                        .extrudedPlate()
                    MarketStatusLine(text: MarketCopy.fetchingAskingPrices)
                    Spacer()
                }
                .padding(.horizontal, theme.metrics.screenGutter)
                .padding(.top, MarketMatchView.topPadding)
                .padding(.bottom, theme.metrics.screenGutter)
            }
            .navigationTitle(MarketCopy.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    MarketFetchingView(
        candidate: MarketCandidate(
            id: 126_161,
            slug: "fender-american-professional-ii-telecaster",
            title: "Fender American Professional II Telecaster",
            brand: "Fender",
            imageURL: nil,
            usedLowCents: 110_000,
            usedTotal: 12
        )
    )
    .environment(\.theme, .dark)
}
