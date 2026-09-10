import SwiftUI

/// The stock-photo candidate picker — the second phase of the sheet (spec 005
/// criterion 2, plan §6; the visuals are
/// `design/elements/005-stock-photos/Main`, `PickerSearching`, `PickerEmpty`,
/// `PickerFailed` and `PickerDownloading`).
///
/// Searching happens on submit, and once on appear with the query the view
/// model was seeded with — the item's name. There is deliberately no
/// as-you-type search (spec P1, criterion 10): it would send fragments of the
/// name to Wikimedia as separate requests.
///
/// Candidate thumbnails are drawn by `AsyncImage`, straight from Wikimedia's
/// URL through the OS's shared URL cache — transport, never app storage, and
/// the one place in `Trove/Views/Photos` that fetches an image over the
/// network. The whole cell is the tap target; picking it downloads the
/// storage-size image.
///
/// Every word comes from `StockPhotoCopy`; this file contains no string
/// literal with a space in it. The host `.sheet` (T009/T010) applies the
/// detents and presents this `NavigationStack` content.
struct PhotoPickerSheetView: View {
    @State private var viewModel: PhotoFetchViewModel
    private let pick: (StockPhotoCandidate) async -> Void
    private let cancel: () -> Void

    @Environment(\.theme) private var theme

    /// The view model is made by the host screen, so the seed and the service
    /// both come from there. Held in `@State`, so the sheet's body being
    /// re-evaluated doesn't throw away a search in flight.
    init(
        viewModel: PhotoFetchViewModel,
        pick: @escaping (StockPhotoCandidate) async -> Void,
        cancel: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.pick = pick
        self.cancel = cancel
    }

    /// The artboard's own measures: the gap under the search field, the grid's
    /// column/row gaps and content padding, the cell corner and the credit gap.
    private static let contentGap: CGFloat = 14
    private static let topPadding: CGFloat = 6
    private static let gridColumnGap: CGFloat = 12
    private static let gridRowGap: CGFloat = 16
    private static let gridContentBottom: CGFloat = 24
    private static let cellRadius: CGFloat = 2
    private static let cellCreditGap: CGFloat = 7

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: Self.gridColumnGap),
         GridItem(.flexible(), spacing: Self.gridColumnGap)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.colors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Self.contentGap) {
                    SearchField(placeholder: StockPhotoCopy.searchPlaceholder, text: $viewModel.query)
                        .accessibilityIdentifier("stockphoto.search")

                    phase
                }
                .padding(.horizontal, theme.metrics.screenGutter)
                .padding(.top, Self.topPadding)
                .padding(.bottom, theme.metrics.screenGutter)
            }
            .navigationTitle(StockPhotoCopy.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(StockPhotoCopy.cancel, action: cancel)
                        .foregroundStyle(theme.colors.accentBrass)
                }
            }
        }
        // Submit, not change: the search field's return key is the only thing
        // that starts a search after the seeded one (spec P1).
        .onSubmit(of: .text) { Task { await viewModel.search() } }
        .task { await viewModel.search() }
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
            grid(candidates)

        case .empty:
            EmptyStateView(
                mark: .system("magnifyingglass"),
                headline: StockPhotoCopy.emptyState,
                action: .init(label: StockPhotoCopy.searchAgain, perform: search)
            )

        case .failed:
            EmptyStateView(
                mark: .system("magnifyingglass"),
                headline: StockPhotoCopy.failure,
                action: .init(label: StockPhotoCopy.searchAgain, perform: search)
            )
        }
    }

    private func search() {
        Task { await viewModel.search() }
    }

    /// `MarketStatusLine`'s shape, drawn inline: 005 is self-contained from the
    /// Market file, so the small spinner and quiet mono line are here rather
    /// than reused from `MarketStatusLine`.
    private var statusLine: some View {
        HStack(spacing: theme.metrics.fieldGap) {
            ProgressView()
                .controlSize(.small)
                .tint(theme.colors.accentBrass)
            Text(StockPhotoCopy.searching)
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textQuiet)
        }
    }

    /// The results grid — 2 columns, ellipsis-truncating each cell's credit,
    /// with a grid-level downloading spinner while a pick is fetching. (A
    /// grid-level spinner rather than the artboard's per-cell dimming — the
    /// simpler, correct version the brief allows; noted in the report.)
    private func grid(_ candidates: [StockPhotoCandidate]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Self.gridRowGap) {
                ForEach(candidates) { cell($0) }
            }
            .padding(.bottom, Self.gridContentBottom)
        }
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if viewModel.isDownloading {
                ProgressView()
                    .controlSize(.large)
                    .tint(theme.colors.accentBrass)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.colors.background.opacity(0.58))
            }
        }
    }

    /// One candidate: the square fill-cropped image and, beneath it, the
    /// compact `author · licence` credit. The whole cell is the tap target;
    /// tapping downloads the storage-size image (`pick`).
    private func cell(_ candidate: StockPhotoCandidate) -> some View {
        Button {
            Task { await pick(candidate) }
        } label: {
            VStack(alignment: .leading, spacing: Self.cellCreditGap) {
                image(candidate)
                StockPhotoCredit(attribution: candidate.attribution, style: .compact)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stockphoto.candidate")
    }

    /// `RowThumbnail`'s slot over a URL: a square sized to the column, fill-
    /// cropped, over a `surfaceInset` ground with the same photo-glyph
    /// placeholder while there is nothing to draw. The `surfaceInset` shape
    /// fits to a square of the column's width; the `AsyncImage` fills it and
    /// clips. The one `AsyncImage` under `Trove/Views/Photos` — transport,
    /// never storage.
    private func image(_ candidate: StockPhotoCandidate) -> some View {
        Rectangle()
            .fill(theme.colors.surfaceInset)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                AsyncImage(url: candidate.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(theme.colors.textInactive)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cellRadius))
            .accessibilityLabel(candidate.title)
    }
}
