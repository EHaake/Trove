import SwiftUI

/// What the five market intents do, handed over as one value so the two
/// detail screens wire the section the same way and the compiler checks
/// that they did (plan §6). Change match… is `find` over an existing
/// match — the view models make it one intent, and the two identifiers
/// stay separate only because they are separate targets on screen.
struct MarketSectionActions {
    let find: () -> Void
    /// `async` because the refresh awaits the network; the button drives it
    /// from a `Task`, which is the only place this view does anything but
    /// draw.
    let refresh: () async -> Void
    let adopt: () -> Void
    let changeMatch: () -> Void
    let removeMatch: () -> Void
}

/// The Market block on both detail screens (spec 002, plan §6; the visual
/// is `design/elements/002-market-values/`, artboards `Main`,
/// `ItemUnmatched`, `ItemNeverRefreshed`, `ItemWithheld`, `ItemStale`,
/// `ItemAllYears`, `ItemJustRefreshed`, `ItemFailure`, `WishlistCurrent`
/// and the `MarketStates` component sheet).
///
/// One unbroken `DetailSection` in the DETAILS/NOTES rhythm rather than a
/// plated card: the two cards above are the screen's weight, and Reverb's
/// asking price must never out-shout the person's own figure (spec P1).
///
/// Every state it can be in comes from the view model as
/// `MarketSectionState` — nothing here decides what a reading *is*, only
/// how it is set. Every word comes from `MarketCopy`; this file may not
/// contain a string literal with a space in it, and `MarketVocabularyTests`
/// holds it to that, so no copy can reach the screen without passing the
/// vocabulary scan.
///
/// `now` is a parameter rather than `Date.now` read inside, so the age
/// lines are pinnable by a test and by the render harness.
struct MarketSection: View {
    let state: MarketSectionState
    var activity: MarketActivity?
    var notice: MarketNotice?
    /// The item's own year (spec Decision 29) — the source line's third
    /// part, and the year the all-years line names when it has no other.
    var year: Int?
    /// A wanted item adopts an *estimated cost* and reads the "used"
    /// wording; an owned one adopts its value (spec P6, plan Q7).
    let isWanted: Bool
    let canRefresh: Bool
    let canAdopt: Bool
    var now: Date = .now
    let actions: MarketSectionActions

    @Environment(\.theme) private var theme

    /// The section's own rhythm, from `tokens.md`'s Market table: the gap
    /// between reading rows, the tighter one under the source line, the
    /// tap target every action carries, and the overhangs that keep those
    /// 44pt targets from stretching the rhythm they sit in.
    fileprivate static let rowGap: CGFloat = 12
    fileprivate static let tightGap: CGFloat = 4
    fileprivate static let hitHeight: CGFloat = 44
    fileprivate static let linkGap: CGFloat = 5
    fileprivate static let linkOverhang: CGFloat = 8
    fileprivate static let textButtonOverhang: CGFloat = 6
    fileprivate static let proseLineSpacing: CGFloat = 3

    var body: some View {
        DetailSection(title: MarketCopy.sectionTitle) {
            VStack(alignment: .leading, spacing: Self.rowGap) {
                switch state {
                case .unmatched:
                    findButton
                case .matched(let display):
                    matched(display)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // `.contain`, not `.combine`: criterion 20 asks for the figure, the
        // count, the spread and the age to read as parts of one section,
        // each with its own label, rather than as a single run-on sentence
        // the way a list row reads.
        .accessibilityElement(children: .contain)
    }

    // MARK: - Matched

    @ViewBuilder
    private func matched(_ display: MarketMatchDisplay) -> some View {
        sourceBlock(display)
        reading(display)
        if let webURL = display.webURL {
            MarketReverbLink(url: webURL)
        }
        if let noticeLine {
            Text(noticeLine)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.accentRustText)
                .lineSpacing(Self.proseLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        actionRows
    }

    /// "On Reverb · {title} · {year}", and — only over a figure that is
    /// actually shown — the all-years line beneath it (Amendment A). A
    /// withheld reading after the same fallback says "too few listings in
    /// this condition" already; stacking both would say it twice.
    private func sourceBlock(_ display: MarketMatchDisplay) -> some View {
        VStack(alignment: .leading, spacing: Self.tightGap) {
            quietLine(MarketCopy.sourceLine(title: display.title, year: year))
            if case .current(let figure) = display.reading,
               figure.isAllYearsFallback,
               let narrowedYear = figure.yearFilter ?? year {
                quietLine(MarketCopy.allYearsFallback(year: narrowedYear, wanted: isWanted))
            }
        }
    }

    @ViewBuilder
    private func reading(_ display: MarketMatchDisplay) -> some View {
        switch display.reading {
        case .none:
            quietLine(MarketCopy.notRefreshedHere, font: theme.typography.body)

        case .current(let figure):
            if let medianCents = figure.medianCents {
                figureRow(medianCents: medianCents, count: figure.count)
            }
            HStack(alignment: .firstTextBaseline, spacing: Self.rowGap) {
                if let lowCents = figure.lowCents, let highCents = figure.highCents {
                    Text(MarketCopy.spread(lowCents: lowCents, highCents: highCents))
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(theme.colors.textMonoMeta)
                        .monospacedDigit()
                        .accessibilityLabel(
                            MarketCopy.spreadAccessibilityLabel(lowCents: lowCents, highCents: highCents)
                        )
                }
                Spacer(minLength: theme.metrics.fieldGap)
                ageLine(fetchedAt: figure.fetchedAt)
            }

        case .withheld(let figure):
            sentence(MarketCopy.withheld(usedLowCents: figure.usedLowCents, wanted: isWanted))
            // The age keeps its place at the right edge even with no
            // spread to sit beside, so a withheld reading still says when
            // it was taken (the artboard's empty left cell).
            HStack {
                Spacer(minLength: theme.metrics.fieldGap)
                ageLine(fetchedAt: figure.fetchedAt)
            }

        case .stale(let fetchedAt):
            HStack(alignment: .firstTextBaseline, spacing: Self.rowGap) {
                sentence(MarketCopy.refreshDue)
                Spacer(minLength: theme.metrics.fieldGap)
                ageLine(fetchedAt: fetchedAt)
            }
        }
    }

    /// `$1,450 · 12 listed` as three elements: the figure in the PAID
    /// cell's mono register (never brass, never Archivo — those belong to
    /// the person's own number), and the dot hidden from VoiceOver so the
    /// count reads as its own phrase.
    private func figureRow(medianCents: Int, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.metrics.fieldGap) {
            Text(MarketCopy.median(cents: medianCents))
                .font(theme.typography.monoValue)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
                .accessibilityLabel(MarketCopy.figureAccessibilityLabel(medianCents: medianCents))
            Text(MarketCopy.separator)
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textMonoMeta)
                .accessibilityHidden(true)
            Text(MarketCopy.listed(count: count))
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textMonoMeta)
                .accessibilityLabel(MarketCopy.countAccessibilityLabel(count))
        }
    }

    private func ageLine(fetchedAt: Date) -> some View {
        Text(MarketCopy.age(fetchedAt: fetchedAt, at: now))
            .font(theme.typography.monoMeta)
            .foregroundStyle(theme.colors.textQuiet)
            .fixedSize()
            .accessibilityLabel(MarketCopy.ageAccessibilityLabel(fetchedAt: fetchedAt, at: now))
    }

    private func quietLine(_ text: String, font: Font? = nil) -> some View {
        Text(text)
            .font(font ?? theme.typography.secondary)
            .foregroundStyle(theme.colors.textLabelSecondary)
            .lineSpacing(Self.proseLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A reading that says something instead of showing a figure.
    private func sentence(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textBody)
            .lineSpacing(Self.proseLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var noticeLine: String? {
        guard let notice else { return nil }
        switch notice {
        case .unreachable(let lastFetchedAt):
            guard let lastFetchedAt else { return MarketCopy.unreachableNoFigure }
            return MarketCopy.unreachable(fetchedAt: lastFetchedAt, at: now)
        case .rateLimited:
            return MarketCopy.rateLimited
        case .productGone:
            return MarketCopy.productGone
        }
    }

    // MARK: - Actions

    private var actionRows: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            HStack(spacing: theme.metrics.fieldGap) {
                refreshButton
                if showsAdopt { adoptButton }
            }
            matchActions
        }
    }

    /// Whether the adopt button has a place in the row — a property of the
    /// *reading*, not of `canAdopt`, so a refresh in flight dims the button
    /// rather than removing it and relaying the row out mid-tap.
    private var showsAdopt: Bool {
        guard case .matched(let display) = state, case .current = display.reading else { return false }
        return true
    }

    private var isRefreshing: Bool { activity == .refreshing }

    private var findButton: some View {
        Button(action: actions.find) {
            outlinedChrome(Text(MarketCopy.findOnReverb).font(theme.typography.button), fills: false)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("market.find")
    }

    /// Outlined, because it fetches rather than writing anything of the
    /// person's (the button rule in `tokens.md`). Disabled inside the hour
    /// with the hint that says why — every state that disables it also
    /// draws an age line, so it never reads as broken (plan Q8).
    private var refreshButton: some View {
        Button {
            Task { await actions.refresh() }
        } label: {
            outlinedChrome(
                HStack(spacing: theme.metrics.fieldGap) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(refreshInk)
                    }
                    Text(MarketCopy.refresh).font(theme.typography.button)
                },
                fills: !showsAdopt,
                ink: refreshInk,
                border: refreshBorder
            )
        }
        .buttonStyle(.plain)
        .disabled(!canRefresh)
        .accessibilityHint(refreshHint)
        .accessibilityIdentifier("market.refresh")
    }

    /// The only filled button in the section: it is the only one that
    /// writes the person's own number (`tokens.md`'s button rule).
    private var adoptButton: some View {
        Button(action: actions.adopt) {
            Text(isWanted ? MarketCopy.useAsEstimatedCost : MarketCopy.useAsMyValue)
                .font(theme.typography.buttonProminent)
                .foregroundStyle(theme.colors.background)
                .padding(.horizontal, theme.metrics.cardPadding)
                .frame(maxWidth: .infinity, minHeight: Self.hitHeight)
                .background(
                    RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                        .fill(theme.colors.accentBrass)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canAdopt)
        .accessibilityIdentifier("market.adopt")
    }

    /// Two plain text buttons, not a menu: two items don't earn a menu, and
    /// a menu here would put a destructive-ish action one tap further away
    /// than the design draws it. `MenuPolicyTests` stays untouched.
    private var matchActions: some View {
        HStack(spacing: theme.metrics.fieldGap) {
            textButton(
                MarketCopy.changeMatch,
                ink: theme.colors.accentBrass,
                identifier: "market.changeMatch",
                action: actions.changeMatch
            )
            Spacer(minLength: theme.metrics.fieldGap)
            textButton(
                MarketCopy.removeMatch,
                ink: theme.colors.accentRustText,
                identifier: "market.removeMatch",
                action: actions.removeMatch
            )
        }
        .padding(.vertical, -Self.textButtonOverhang)
    }

    private func textButton(
        _ title: String,
        ink: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.buttonCompact)
                .foregroundStyle(ink)
                .frame(minHeight: Self.hitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// The outlined button's chrome. `fills` is the artboards' `flex`: the
    /// button hugs its label when something sits beside it and grows to the
    /// row when it stands alone.
    private func outlinedChrome(
        _ label: some View,
        fills: Bool,
        ink: Color? = nil,
        border: Color? = nil
    ) -> some View {
        label
            .foregroundStyle(ink ?? theme.colors.accentBrass)
            .padding(.horizontal, theme.metrics.cardPadding)
            .frame(maxWidth: fills ? .infinity : nil, minHeight: Self.hitHeight)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(border ?? theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
            )
            // An outline leaves the interior transparent, and a transparent
            // interior isn't hit-testable — the lesson `findItemsToSell`
            // records on the wishlist screen.
            .contentShape(Rectangle())
    }

    private var refreshInk: Color {
        if isRefreshing { return theme.colors.accentBrass.opacity(0.6) }
        return canRefresh ? theme.colors.accentBrass : theme.colors.textDisabled
    }

    private var refreshBorder: Color {
        if isRefreshing { return theme.colors.accentBrass.opacity(0.5) }
        return canRefresh ? theme.colors.accentBrass : theme.colors.textPrimary.opacity(0.16)
    }

    /// Only the within-the-hour refusal has something to explain: while a
    /// refresh is in flight the spinner says it, and an unmatched item
    /// draws no Refresh at all.
    private var refreshHint: String {
        !canRefresh && !isRefreshing ? MarketCopy.refreshWithinHourHint : ""
    }
}

/// The link out to the matched product (spec criterion 4, Decision 28's
/// sibling on the picker's cards).
///
/// A SwiftUI `Link`, so VoiceOver announces it with the `.isLink` trait and
/// the hint says where it goes — a `Button` calling `openURL` would look
/// identical and read as an in-place action. Its own type so the render
/// test can sample its ink alone: whether `.buttonStyle(.plain)` or the
/// environment's tint would have styled it is measured, not assumed.
struct MarketReverbLink: View {
    let url: URL

    @Environment(\.theme) private var theme

    var body: some View {
        Link(destination: url) {
            HStack(spacing: MarketSection.linkGap) {
                Text(MarketCopy.viewOnReverb)
                    .font(theme.typography.buttonCompact)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(theme.colors.accentBrass)
            .frame(minHeight: MarketSection.hitHeight)
            .contentShape(Rectangle())
        }
        .padding(.vertical, -MarketSection.linkOverhang)
        .accessibilityLabel(MarketCopy.viewOnReverb)
        .accessibilityHint(MarketCopy.reverbLinkHint)
        .accessibilityIdentifier("market.link")
    }
}
