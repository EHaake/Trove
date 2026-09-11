import SwiftUI

/// The credit line beneath a stock photo (spec criterion 3, criterion 11): the
/// full form "Photo: {author} · {licence} · Wikimedia Commons", whose last
/// segment links to the Commons file page.
///
/// The words come straight from `StockPhotoCopy.credit(author:licenseName:)` —
/// the same plain-text form the PDF export (T013) and VoiceOver use — restyled
/// run by run, so nothing but glue is typed here.
///
/// **One wrapping paragraph (T015b, plan §6 as amended at the T015 device
/// pass).** The `.full` credit is a single `Text` over the `AttributedString`
/// `attributedCredit(_:theme:)` builds: the licence run in mono, the trailing
/// source run carrying `.link`, drawn by the `Text`'s own `.tint`. T007's form
/// — a leading `Text` beside a sibling `Link` in an `HStack` — baseline-aligned
/// the link to line one and garbled when the author wrapped. A link can be a
/// *view* (its own label and hint, but it cannot wrap inside a paragraph) or an
/// *inline run* (it wraps, but carries no per-run accessibility); the credit
/// needs the wrap, so it takes the run and puts the accessibility back with
/// `accessibilityRepresentation`. There is deliberately no `lineLimit`,
/// `truncationMode` or `minimumScaleFactor` here: a long author wraps whole and
/// is never cut, which the licence requires.
///
/// Tapping the source run opens Commons through the environment's default
/// `OpenURLAction` — no `Link` view in the layout, no `Button`, no `openURL`
/// call. For VoiceOver the paragraph is one element presented as a `Link`,
/// carrying the "leaves the app" hint (`StockPhotoCopy.creditLinkHint`) and the
/// `stockphoto.credit.link` identifier plan §6 names for T012. The `Text`
/// carries no `accessibilityLabel` of its own — an override strips the Links
/// rotor from an inline-link `Text` on iOS 17+.
struct StockPhotoCredit: View {
    /// Which credit this is. `.full` is the linked hero credit; `.compact` is
    /// the grid cell's `author · licence` — no link, no "Photo:" prefix — the
    /// `Main` artboard draws under each candidate.
    enum Style { case full; case compact }

    let attribution: StockPhotoAttribution
    var style: Style = .full

    @Environment(\.theme) private var theme

    var body: some View {
        switch style {
        case .full:
            full
        case .compact:
            compact
        }
    }

    /// The hero credit: one paragraph that wraps whole, with the "leaves the
    /// app" glyph after the link run. The glyph is safe to append here because
    /// the accessibility representation replaces the spoken content entirely.
    private var full: some View {
        (Text(Self.attributedCredit(attribution, theme: theme))
            + Self.sourceGlyph(theme: theme))
            .tint(theme.colors.accentBrass)
            .accessibilityRepresentation {
                Link(destination: attribution.sourceURL) {
                    Text(StockPhotoCopy.credit(
                        author: attribution.author, licenseName: attribution.licenseName))
                }
                .accessibilityHint(StockPhotoCopy.creditLinkHint)
                .accessibilityIdentifier("stockphoto.credit.link")
            }
    }

    /// The "leaves the app" glyph appended after the link run, carrying the
    /// credit's own font and ink (T015c).
    ///
    /// Both modifiers are the fix, not decoration. An `Image` inside a `Text`
    /// takes its size from the font that reaches it, and the concatenated
    /// paragraph applies no font of its own — the styled runs carry theirs
    /// inside the `AttributedString`, so the bare glyph fell through to the
    /// environment's Dynamic Type body font. At accessibility XXXL that drew it
    /// at roughly five times the credit's cap height, on a line of its own,
    /// while the theme's fixed-size text beside it did not move at all (the
    /// T015b device pass). Taking `theme.typography.secondary` — the same fixed
    /// size the credit's own runs use — pins it to the text it belongs to. The
    /// ink is the second half: appended as a separate run with no colour, the
    /// glyph drew in the primary text colour, because the paragraph's `.tint`
    /// reaches `.link` runs and nothing else.
    static func sourceGlyph(theme: Theme) -> Text {
        Text(Image(systemName: "arrow.up.right"))
            .font(theme.typography.secondary)
            .foregroundStyle(theme.colors.accentBrass)
    }

    /// The full credit as one styled value: characters exactly
    /// `StockPhotoCopy.credit(author:licenseName:)`, the licence run in mono,
    /// and the trailing `StockPhotoCopy.creditSource` run carrying
    /// `.link = attribution.sourceURL`. That run's own colour is cleared so the
    /// link draws with the `Text`'s tint (the brass the Design pass asks for).
    ///
    /// Pure and static, and styled by ranges found in the assembled string
    /// rather than composed from pieces, so the characters can't drift from the
    /// copy — which is what `StockPhotoBadgeTests` checks. Searching backwards
    /// matters: the author may itself be "Wikimedia Commons" (the no-author
    /// fallback, spec P4), and only the trailing occurrence is the link.
    static func attributedCredit(_ attribution: StockPhotoAttribution, theme: Theme) -> AttributedString {
        var credit = AttributedString(StockPhotoCopy.credit(
            author: attribution.author, licenseName: attribution.licenseName))
        credit.font = theme.typography.secondary
        credit.foregroundColor = theme.colors.textLabelSecondary

        if !attribution.licenseName.isEmpty,
           let license = credit.range(of: attribution.licenseName, options: .backwards) {
            credit[license].font = theme.typography.monoMeta
            credit[license].foregroundColor = theme.colors.textMonoMeta
        }

        if let source = credit.range(of: StockPhotoCopy.creditSource, options: .backwards) {
            credit[source].link = attribution.sourceURL
            credit[source].foregroundColor = nil
        }

        return credit
    }

    /// The grid cell's credit: the author takes the slack and truncates, a
    /// quiet separator, and the licence in mono that never shrinks. No link,
    /// no "Photo:" prefix — the whole cell is the tap target, and the source
    /// link lives on the detail hero (item C of T008's brief). The `lineLimit`
    /// here is T008's deliberate call for the grid, not the hero's rule.
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
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        StockPhotoCredit(
            attribution: StockPhotoAttribution(
                author: "Rama, Wikimedia Commons, Cc-by-sa-2.0-fr",
                licenseName: "CC BY-SA 2.0 FR",
                sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!
            )
        )
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}
