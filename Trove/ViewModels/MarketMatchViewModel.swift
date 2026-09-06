import Foundation
import Observation

/// The candidate picker's half of the one match sheet (spec 002 criterion
/// 3, plan §6): a query, a phase, and one intent that searches Reverb for
/// products by name.
///
/// It is handed a *seed* rather than reading the item itself — the detail
/// view models make one of these through `makeMatchViewModel()`, seeded
/// with the item's name and nothing else, because the name is the whole of
/// what criterion 3 allows to leave the device. A view model that held the
/// item could grow a category or a condition into the query without anyone
/// noticing; this one has nothing else to send.
///
/// Searching happens on submit and once on appear (Q10) — never as the
/// person types, which would send fragments of the name as separate
/// requests.
@Observable
final class MarketMatchViewModel {
    /// What the sheet is showing. `empty` carries the query it found
    /// nothing for, since the copy names it back to the person.
    enum Phase: Equatable {
        case idle
        case searching
        case results([MarketCandidate])
        case empty(String)
        case failed(Failure)
    }

    /// The two failures the picker distinguishes: the rate limit says to
    /// come back later (spec P7), and everything else reads as "couldn't
    /// reach Reverb" (P8). The picker has no figure standing behind it, so
    /// there is nothing else for a failure to say.
    enum Failure: Equatable {
        case rateLimited
        case unreachable
    }

    /// The search box's text — bound by the view, and the only state here
    /// the person edits.
    var query: String
    private(set) var phase: Phase = .idle

    private let service: any MarketService

    /// The reentry guard. A submit while a search is in flight is dropped
    /// rather than queued: the second result would land on top of the
    /// first in whatever order the two returned.
    private var isSearching = false

    init(seed: String, service: any MarketService) {
        self.query = seed
        self.service = service
    }

    /// Searches for the trimmed query. A blank one reaches nothing and
    /// leaves the sheet idle — the seeded search on an unnamed item, and
    /// the person clearing the field and hitting return.
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
            let candidates = try await service.searchProducts(named: trimmed)
            phase = candidates.isEmpty ? .empty(trimmed) : .results(candidates)
        } catch {
            phase = .failed(Self.failure(for: error))
        }
    }

    /// Only the rate limit has its own line; every other error — including
    /// anything that isn't a `MarketError` at all — is unreachable.
    private static func failure(for error: any Error) -> Failure {
        guard let market = error as? MarketError else { return .unreachable }
        switch market {
        case .rateLimited: return .rateLimited
        case .productNotFound, .unreachable, .serverError, .malformedResponse: return .unreachable
        }
    }
}
