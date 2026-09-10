import Foundation
import Observation

/// Which phase the stock-photo sheet is showing (spec Decision 14, plan §6):
/// the one-time notice in front of the picker, or the picker itself. Two
/// phases only — unlike the market sheet's four — because the download and the
/// value step have no place here: the pick's bytes are handed straight to the
/// host's `store(_:)`. Mirrors `MarketSheetStep`'s shape, trimmed to the two
/// the photo flow needs.
enum PhotoSheetStep: Equatable, Sendable {
    case notice
    case pick
}

/// The stock-photo picker's view model (spec 005 criterion 2, plan §4): a
/// query, a phase, and two intents — search Wikimedia Commons for photos by
/// name, and download the chosen one.
///
/// It is handed a *seed* rather than reading the item itself — the host view
/// models (T009/T010) make one seeded with the item's name and nothing else,
/// because the name is the whole of what criterion 2 (spec P1) allows to leave
/// the device. A view model that held the item could grow a category into the
/// query without anyone noticing; this one has nothing else to send. Mirrors
/// `MarketMatchViewModel`.
///
/// Searching happens on submit and once on appear (spec P1, criterion 10) —
/// never as the person types, which would send fragments of the name as
/// separate requests.
@Observable
final class PhotoFetchViewModel {
    /// What the sheet is showing. `empty` carries the query it found nothing
    /// for, since the copy names it back to the person. Unlike 002, `failed`
    /// carries no associated value: the stock picker has one failure message
    /// (`StockPhotoCopy.failure`), because it has no figure standing behind it.
    enum Phase: Equatable {
        case idle
        case searching
        case results([StockPhotoCandidate])
        case empty(String)
        case failed
    }

    /// The search box's text — bound by the view, and the only state here the
    /// person edits.
    var query: String
    private(set) var phase: Phase = .idle
    /// True while a chosen candidate's bytes are being fetched, for the grid's
    /// downloading spinner.
    private(set) var isDownloading = false

    private let service: any StockPhotoService

    /// The reentry guard. A submit while a search is in flight is dropped
    /// rather than queued: the second result would land on top of the first in
    /// whatever order the two returned.
    private var isSearching = false

    init(seed: String, service: any StockPhotoService) {
        self.query = seed
        self.service = service
    }

    /// Searches for the trimmed query. A blank one reaches nothing and leaves
    /// the sheet idle — the seeded search on an unnamed item, and the person
    /// clearing the field and hitting return. `imageTooLarge` can't arise from
    /// a search, so mapping every thrown error to `.failed` satisfies the
    /// plan's "every non-`imageTooLarge` error → `.failed`".
    func search() async {
        guard !isSearching else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            return
        }

        isSearching = true
        phase = .searching
        defer { isSearching = false }

        do {
            let candidates = try await service.searchPhotos(named: trimmed)
            phase = candidates.isEmpty ? .empty(trimmed) : .results(candidates)
        } catch {
            phase = .failed
        }
    }

    /// Downloads the chosen candidate's storage-size bytes and hands them back
    /// with its attribution. The host (T009/T010) decides what to do with the
    /// result; this view model only fetches. A failed download returns `nil`.
    func download(_ candidate: StockPhotoCandidate) async -> StockPhotoDownload? {
        isDownloading = true
        defer { isDownloading = false }

        do {
            let data = try await service.imageData(from: candidate.storageURL)
            return StockPhotoDownload(imageData: data, attribution: candidate.attribution)
        } catch {
            return nil
        }
    }
}
