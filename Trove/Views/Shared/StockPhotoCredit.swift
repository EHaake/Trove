import SwiftUI

/// The credit line beneath a stock photo (spec criterion 3, criterion 11): the
/// full, linked form "Photo: {author} · {licence} · Wikimedia Commons", with
/// the last segment a real SwiftUI `Link` to the Commons file page.
///
/// The words come straight from `StockPhotoCopy.credit(author:licenseName:)` —
/// the same plain-text form the PDF export (T013) and VoiceOver use — split on
/// the separator so nothing but glue is typed here. The view restyles the
/// licence run in mono and draws the source segment as the link; the leading
/// text is one concatenated `Text` so it flows as a single line.
///
/// The link mirrors the app's external-link convention (see
/// `MarketMatchView.footer`): a `Link(destination:)` — never a `Button` +
/// `openURL` — with the `arrow.up.right` "leaves the app" glyph
/// (`accessibilityHidden`), a hint that it leaves the app
/// (`StockPhotoCopy.creditLinkHint`), and the `stockphoto.credit.link`
/// identifier plan §6 names for T012.
struct StockPhotoCredit: View {
    /// Which credit this is. `.full` is the linked hero credit (unchanged from
    /// T007); `.compact` is the grid cell's `author · licence` — no link, no
    /// "Photo:" prefix — the `Main` artboard draws under each candidate.
    enum Style { case full; case compact }

    let attribution: StockPhotoAttribution
    var style: Style = .full

    @Environment(\.theme) private var theme

    var body: some View {
        switch style {
        case .full:
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                leadingText
                link
            }
        case .compact:
            compact
        }
    }

    /// The grid cell's credit: the author takes the slack and truncates, a
    /// quiet separator, and the licence in mono that never shrinks. No link,
    /// no "Photo:" prefix — the whole cell is the tap target, and the source
    /// link lives on the detail hero (item C of T008's brief).
    private var compact: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(attribution.author)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.textLabelSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(StockPhotoCopy.creditSeparator)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.textQuiet)
                .padding(.horizontal, Self.compactSeparatorPadding)

            Text(attribution.licenseName)
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textMonoMeta)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// The `·`'s side padding in the compact form (the artboard's `5px`).
    private static let compactSeparatorPadding: CGFloat = 5

    /// "Photo: {author} · {licence} · " — everything up to the linked source,
    /// with the licence run in mono. Split from the assembled plain-text credit
    /// so the prefix and licence come from `StockPhotoCopy`, not typed here.
    private var leadingText: Text {
        let paddedSeparator = " \(StockPhotoCopy.creditSeparator) "
        let plainText = StockPhotoCopy.credit(author: attribution.author, licenseName: attribution.licenseName)
        let segments = plainText.components(separatedBy: paddedSeparator)
        let prefix = segments.first ?? ""
        let license = segments.count > 1 ? segments[1] : ""

        return Text("\(prefix)\(paddedSeparator)")
            .font(theme.typography.secondary)
            .foregroundStyle(theme.colors.textLabelSecondary)
        + Text(license)
            .font(theme.typography.monoMeta)
            .foregroundStyle(theme.colors.textMonoMeta)
        + Text(paddedSeparator)
            .font(theme.typography.secondary)
            .foregroundStyle(theme.colors.textLabelSecondary)
    }

    private var link: some View {
        Link(destination: attribution.sourceURL) {
            HStack(spacing: 2) {
                Text(StockPhotoCopy.creditSource)
                    .font(theme.typography.secondary)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(theme.colors.accentBrass)
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityLabel(StockPhotoCopy.creditSource)
        .accessibilityHint(StockPhotoCopy.creditLinkHint)
        .accessibilityIdentifier("stockphoto.credit.link")
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        StockPhotoCredit(
            attribution: StockPhotoAttribution(
                author: "Jane Photographer",
                licenseName: "CC BY-SA 4.0",
                sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!
            )
        )
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}
