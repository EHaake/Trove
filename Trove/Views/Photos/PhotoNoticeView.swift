import SwiftUI

/// The one-time notice that stands in front of the stock-photo picker the
/// first time Find a photo… is used on this device (spec 005 criterion 1,
/// §5; plan §6; the visual is
/// `design/elements/005-stock-photos/PickerNotice`).
///
/// A sheet's first phase rather than an alert, because an alert can hold no
/// link, and the first phase of the *same* sheet the picker uses, so no
/// presentation binding is written mid-flight — 002's `MarketNoticeView`
/// shape, with 005's copy.
///
/// **Continue is the only thing that acknowledges it.** Not now — and the
/// swipe-down the host screens treat as Not now — leave the flag alone, so the
/// notice comes back next time. This view decides none of that: it calls the
/// two closures it is handed and nothing else. The once-only gating is the
/// host's (T009/T010).
///
/// Every word comes from `StockPhotoCopy`; this file contains no string
/// literal with a space in it.
struct PhotoNoticeView: View {
    let continueAction: () -> Void
    let declineAction: () -> Void

    @Environment(\.theme) private var theme

    /// The artboard's own padding and rhythm (002's notice exactly): `22 … 32`,
    /// the section gap from the prose to the buttons, `4px` prose-to-link.
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

    /// The body, then the privacy link. A SwiftUI `Link` is a view and cannot
    /// flow inside a `Text`, so it sits on its own line under the prose, as
    /// `MarketNoticeView` does — a real `Link`, never a markdown link inside
    /// the string.
    private var prose: some View {
        VStack(alignment: .leading, spacing: Self.linkGap) {
            Text(StockPhotoCopy.noticeBody)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textBody)
                .lineSpacing(Self.proseLineSpacing)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: StockPhotoCopy.privacyPolicyURL) {
                Text(StockPhotoCopy.noticeLinkTitle)
                    .font(theme.typography.button)
                    .foregroundStyle(theme.colors.accentBrass)
                    .frame(minHeight: MarketButtons.hitHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("stockphoto.notice.privacy")
        }
    }

    /// Continue filled — it is the one that writes the device's flag — and Not
    /// now outlined, each 48pt tall (the artboard), stacked. The chrome is the
    /// generic, word-free market chrome, reused across surfaces (item D).
    private var buttons: some View {
        VStack(spacing: theme.metrics.fieldGap) {
            Button(action: continueAction) {
                Text(StockPhotoCopy.noticeContinue)
                    .font(theme.typography.buttonProminent)
                    .marketFilledChrome(minHeight: MarketButtons.noticeHeight)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stockphoto.notice.continue")

            Button(action: declineAction) {
                Text(StockPhotoCopy.noticeNotNow)
                    .font(theme.typography.button)
                    .marketOutlinedChrome(fills: true, minHeight: MarketButtons.noticeHeight)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stockphoto.notice.notNow")
        }
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        PhotoNoticeView(continueAction: {}, declineAction: {})
    }
    .environment(\.theme, .dark)
}
