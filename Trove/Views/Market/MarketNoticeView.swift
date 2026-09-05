import SwiftUI

/// The one-time notice that stands in front of the picker the first time a
/// match is found on this device (spec Decision 14, P15; plan §6, Q5; the
/// visual is `design/elements/002-market-values/PickerNotice`).
///
/// A sheet rather than an alert, because an alert can hold no link (Q9),
/// and the first phase of the *same* sheet the picker uses, so no
/// presentation binding is written mid-flight.
///
/// **Continue is the only thing that acknowledges it.** Not now — and the
/// swipe-down the detail screens treat as Not now — leave the flag alone,
/// so the notice comes back next time. This view decides none of that: it
/// calls the view model's two intents and nothing else.
///
/// Every word comes from `MarketCopy`; this file may not contain a string
/// literal with a space in it, and `MarketVocabularyTests` holds it to that.
struct MarketNoticeView: View {
    let continueAction: () -> Void
    let declineAction: () -> Void

    @Environment(\.theme) private var theme

    /// The artboard's own padding and rhythm: `22 24 32`, `24px` from the
    /// prose to the buttons, `8px` between them.
    private static let topPadding: CGFloat = 22
    private static let bottomPadding: CGFloat = 32
    private static let proseLineSpacing: CGFloat = 4
    private static let linkGap: CGFloat = 4

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                prose
                buttons
            }
            .padding(.top, Self.topPadding)
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.bottom, Self.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .contain)
    }

    /// The body, then the privacy link. The artboard runs the link inline
    /// at the end of the paragraph; a SwiftUI `Link` is a view and cannot
    /// flow inside a `Text`, and the alternative — a markdown link inside
    /// the string — would put the copy's shape in `MarketCopy` and lose the
    /// real `Link` this must be (criterion 20's `.isLink` trait, the same
    /// reasoning as `MarketReverbLink`).
    private var prose: some View {
        VStack(alignment: .leading, spacing: Self.linkGap) {
            Text(MarketCopy.noticeBody)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textBody)
                .lineSpacing(Self.proseLineSpacing)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: MarketCopy.privacyPolicyURL) {
                Text(MarketCopy.noticeLinkTitle)
                    .font(theme.typography.button)
                    .foregroundStyle(theme.colors.accentBrass)
                    .frame(minHeight: MarketButtons.hitHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("market.notice.privacy")
        }
    }

    /// Continue filled — it is the one that writes the device's flag —
    /// and Not now outlined, each 48pt tall (the artboard), stacked.
    private var buttons: some View {
        VStack(spacing: theme.metrics.fieldGap) {
            Button(action: continueAction) {
                Text(MarketCopy.noticeContinue)
                    .font(theme.typography.buttonProminent)
                    .marketFilledChrome(minHeight: MarketButtons.noticeHeight)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("market.notice.continue")

            Button(action: declineAction) {
                Text(MarketCopy.noticeNotNow)
                    .font(theme.typography.button)
                    .marketOutlinedChrome(fills: true, minHeight: MarketButtons.noticeHeight)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("market.notice.notNow")
        }
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        MarketNoticeView(continueAction: {}, declineAction: {})
    }
    .environment(\.theme, .dark)
}
