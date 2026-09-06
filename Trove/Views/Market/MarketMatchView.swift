import SwiftUI

/// The candidate picker — the second phase of the match sheet (spec 002
/// criterion 3, plan §6, Q10; the visuals are
/// `design/elements/002-market-values/PickerResults`, `PickerSearching`,
/// `PickerEmpty` and `PickerFailed`).
///
/// Searching happens on submit, and once on appear with the query the view
/// model was seeded with — the item's name. There is deliberately no
/// as-you-type search: it would send fragments of the name to Reverb as
/// separate requests, which criterion 3 does not allow.
///
/// Candidate thumbnails are drawn by `AsyncImage`, straight from Reverb's
/// URL through the OS's shared URL cache (P14, Q17) — transport, never app
/// storage, and the one place in `Trove/Views` that fetches an image. The
/// card's body picks; its footer links out (Decision 28), so a person can
/// check a candidate on Reverb before committing to it.
///
/// Every word comes from `MarketCopy`; this file may not contain a string
/// literal with a space in it, and `MarketVocabularyTests` holds it to that.
struct MarketMatchView: View {
    @State private var viewModel: MarketMatchViewModel
    /// Async since Amendment B: the pick now runs that product's refresh in
    /// the same sheet (spec Decision 33), so the card's button awaits it.
    private let pick: (MarketCandidate) async -> Void
    private let cancel: () -> Void

    @Environment(\.theme) private var theme

    /// The view model is made by the detail screen's own (its
    /// `makeMatchViewModel()`), so the seed and the service both come from
    /// there. Held in `@State`, so the sheet's body being re-evaluated
    /// doesn't throw away a search in flight.
    init(
        viewModel: MarketMatchViewModel,
        pick: @escaping (MarketCandidate) async -> Void,
        cancel: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.pick = pick
        self.cancel = cancel
    }

    /// The artboard's own measures: the gap under the search field, the
    /// card's 64pt thumbnail, the 2pt lift of the reading off the brand,
    /// the footer's 40pt target and the glyph's gap.
    private static let contentGap: CGFloat = 14
    private static let topPadding: CGFloat = 6
    private static let thumbnailSide: CGFloat = 64
    private static let cardTextGap: CGFloat = 4
    private static let readingLift: CGFloat = 2
    private static let footerHeight: CGFloat = 40
    private static let linkGap: CGFloat = 5
    private static let glyphSize: CGFloat = 11

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Self.contentGap) {
                    SearchField(placeholder: MarketCopy.searchPlaceholder, text: $viewModel.query)
                        .accessibilityIdentifier("market.search")

                    phase
                }
                .padding(.horizontal, theme.metrics.screenGutter)
                .padding(.top, Self.topPadding)
                .padding(.bottom, theme.metrics.screenGutter)
            }
            .navigationTitle(MarketCopy.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MarketCopy.cancel, action: cancel)
                        .foregroundStyle(theme.colors.accentBrass)
                }
            }
        }
        // Submit, not change: the search field's return key is the only
        // thing that starts a search after this one (Q10).
        .onSubmit(of: .text, search)
        .task { await viewModel.search() }
    }

    private func search() {
        Task { await viewModel.search() }
    }

    @ViewBuilder
    private var phase: some View {
        switch viewModel.phase {
        case .idle:
            Spacer()

        case .searching:
            statusLine
            Spacer()

        case .results(let candidates):
            ScrollView {
                LazyVStack(spacing: theme.metrics.listRowGap) {
                    ForEach(candidates) { card($0) }
                }
                // The plate's cast shadow falls outside the card's own
                // bounds, and a `ScrollView` clips at its edges.
                .padding(.vertical, Self.readingLift)
            }
            .scrollDismissesKeyboard(.immediately)

        case .empty(let query):
            EmptyStateView(
                mark: .system("magnifyingglass"),
                headline: MarketCopy.noCandidates(query: query),
                detail: MarketCopy.noCandidatesDetail
            )

        case .failed(let failure):
            EmptyStateView(
                mark: .system("magnifyingglass"),
                headline: message(for: failure),
                action: .init(label: MarketCopy.tryAgain, perform: search)
            )
        }
    }

    /// The rate limit says to come back later; everything else says Reverb
    /// couldn't be reached. Neither has a figure standing behind it here,
    /// so neither dates itself the way the section's line does.
    private func message(for failure: MarketMatchViewModel.Failure) -> String {
        switch failure {
        case .rateLimited: MarketCopy.rateLimited
        case .unreachable: MarketCopy.unreachableNoFigure
        }
    }

    /// `PhotoPickerField`'s status line, in the mono meta register the
    /// `PickerSearching` artboard sets it in.
    private var statusLine: some View {
        HStack(spacing: theme.metrics.fieldGap) {
            ProgressView()
                .controlSize(.small)
                .tint(theme.colors.accentBrass)
            Text(MarketCopy.searching)
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textQuiet)
        }
    }

    // MARK: - A candidate

    /// The body picks, the footer links out — one card, two targets, split
    /// by the artboard's hairline.
    private func card(_ candidate: MarketCandidate) -> some View {
        VStack(spacing: 0) {
            Button {
                Task { await pick(candidate) }
            } label: {
                cardBody(candidate)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("market.candidate")

            footer(candidate)
        }
        .extrudedPlate()
    }

    private func cardBody(_ candidate: MarketCandidate) -> some View {
        HStack(alignment: .top, spacing: theme.metrics.rowContentGap) {
            thumbnail(candidate)

            VStack(alignment: .leading, spacing: Self.cardTextGap) {
                // Never truncated: the title is how the person tells two
                // variants of the same instrument apart (criterion 3).
                Text(candidate.title)
                    .font(theme.typography.rowTitle)
                    .foregroundStyle(theme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let brand = candidate.brand, !brand.isEmpty {
                    Text(brand)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.colors.textLabelSecondary)
                }

                Text(MarketCopy.candidateReading(usedLowCents: candidate.usedLowCents, usedTotal: candidate.usedTotal))
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.colors.textMonoMeta)
                    .monospacedDigit()
                    .padding(.top, Self.readingLift)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.metrics.rowPadding)
        .contentShape(Rectangle())
    }

    /// `RowThumbnail`'s slot, over a URL instead of a stored photo: fixed
    /// square, the same inset placeholder while there is nothing to draw,
    /// and hidden from VoiceOver — the title and brand beside it say what
    /// the candidate is.
    private func thumbnail(_ candidate: MarketCandidate) -> some View {
        AsyncImage(url: candidate.imageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                theme.colors.surfaceInset
                Image(systemName: "photo")
                    .font(.system(size: Self.thumbnailSide * 0.3, weight: .light))
                    .foregroundStyle(theme.colors.textInactive)
            }
        }
        .frame(width: Self.thumbnailSide, height: Self.thumbnailSide)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius))
        .accessibilityHidden(true)
    }

    /// Decision 28: every candidate carries its own way out to Reverb, so a
    /// person can look at the product before committing the match. A real
    /// `Link`, for the reason `MarketReverbLink` records.
    private func footer(_ candidate: MarketCandidate) -> some View {
        VStack(spacing: 0) {
            theme.colors.surfaceInset
                .frame(height: theme.metrics.hairline)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Link(destination: ReverbAPI.productURL(slug: candidate.slug)) {
                    HStack(spacing: Self.linkGap) {
                        Text(MarketCopy.viewOnReverb)
                            .font(theme.typography.buttonCompact)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: Self.glyphSize, weight: .medium))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(theme.colors.accentBrass)
                    .frame(minHeight: Self.footerHeight)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(MarketCopy.viewOnReverb)
                .accessibilityHint(MarketCopy.reverbLinkHint)
                .accessibilityIdentifier("market.candidate.link")
            }
            .padding(.horizontal, theme.metrics.rowPadding)
        }
    }
}
