import Foundation
import SwiftData

/// One item to refresh: which row, which product, and how its listings
/// are read.
struct MarketRefreshTarget: Equatable, Sendable {
    let key: MarketSubjectKey
    let productID: Int
    let subject: MarketSubject
    let year: Int?
}

/// Runs one item's refresh (plan §5): the hour budget first, then the
/// product, then its listings, then — only after every await — a re-check
/// that the item still points at that product, the computation, one
/// write through `MarketLocalStore`, and one `save()`. Nothing is written
/// before the computation, so a failed fetch leaves the last figure
/// exactly as it was (spec P8), and nothing is fetched within the hour
/// (spec P7, criterion 9).
///
/// MainActor, as the project defaults: it owns the context writes. The
/// only thing that crosses the `@concurrent` hop is `Sendable` DTOs.
@MainActor
final class MarketRefresher {
    enum Outcome: Equatable {
        case refreshed(MarketReading)
        /// Within the hour of the last refresh — nothing was sent.
        case stillFresh(fetchedAt: Date)
        /// Reverb couldn't be reached, answered its limit, or has no such
        /// product; the last figure is untouched.
        case failed(MarketError)
        /// The item was unmatched or re-matched while the fetch was in
        /// flight (here, or from another device); the result was dropped.
        case superseded
        /// The store refused the write — not a Reverb failure.
        case saveFailed(String)
    }

    static let freshnessWindow: TimeInterval = 60 * 60

    private let modelContext: ModelContext
    private let service: any MarketService
    private let now: () -> Date

    init(modelContext: ModelContext, service: any MarketService, now: @escaping () -> Date = Date.init) {
        self.modelContext = modelContext
        self.service = service
        self.now = now
    }

    func refresh(_ target: MarketRefreshTarget) async -> Outcome {
        let started = now()
        if let existing = try? MarketLocalStore.figure(for: target.key.subjectID, in: modelContext),
           started.timeIntervalSince(existing.fetchedAt) < Self.freshnessWindow {
            return .stillFresh(fetchedAt: existing.fetchedAt)
        }

        let product: MarketProduct
        let listings: MarketListings
        do {
            product = try await service.product(id: target.productID)
            listings = try await service.listings(for: product)
        } catch let error as MarketError {
            return .failed(error)
        } catch {
            return .failed(.malformedResponse)
        }

        // The awaits are where the world can change under us.
        guard let current = currentTarget(for: target.key), current.productID == target.productID else {
            return .superseded
        }

        let reading = MarketFigureComputation.compute(
            listings: listings,
            subject: current.subject,
            year: current.year,
            product: product,
            fetchedAt: now(),
            now: now()
        )
        do {
            try MarketLocalStore.record(reading, product: product, for: current.key, in: modelContext)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            return .saveFailed(error.localizedDescription)
        }
        return .refreshed(reading)
    }

    /// The item as it is right now — its match, condition and year re-read
    /// after the network hop.
    private func currentTarget(for key: MarketSubjectKey) -> MarketRefreshTarget? {
        let id = key.subjectID
        switch key.kind {
        case .owned:
            var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let item = try? modelContext.fetch(descriptor).first, let productID = item.reverbProductID else { return nil }
            return MarketRefreshTarget(key: key, productID: productID, subject: .owned(condition: item.condition), year: item.year)
        case .wanted:
            var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let item = try? modelContext.fetch(descriptor).first, let productID = item.reverbProductID else { return nil }
            return MarketRefreshTarget(key: key, productID: productID, subject: .wanted, year: item.year)
        }
    }

    /// Every matched item, owned first in custom order, then wanted — the
    /// one definition of "matched" (Settings counts through it too).
    static func targets(in context: ModelContext) throws -> [MarketRefreshTarget] {
        let items = try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.reverbProductID != nil }))
            .sorted(by: ManualOrderHelper.areInCustomOrder)
        let wanted = try context.fetch(FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.reverbProductID != nil }))
            .sorted(by: ManualOrderHelper.areInCustomOrder)
        return items.compactMap { item in
            item.reverbProductID.map {
                MarketRefreshTarget(key: MarketSubjectKey(subjectID: item.id, kind: .owned), productID: $0, subject: .owned(condition: item.condition), year: item.year)
            }
        } + wanted.compactMap { item in
            item.reverbProductID.map {
                MarketRefreshTarget(key: MarketSubjectKey(subjectID: item.id, kind: .wanted), productID: $0, subject: .wanted, year: item.year)
            }
        }
    }
}
