import Foundation
import SwiftData

/// The one writer of plan state (plan Q4, §4), the shape and the contract
/// `ItemSaleStore` and `WishlistPurchaseStore` hold for a sale and a
/// purchase: creating a plan, deleting one, and the one-time carry-over all go
/// through these statics, so "a plan is a stored date, deleting it touches no
/// item and no sold-toward record, and a checked row is never re-planned" is
/// one type's contract rather than several screens' agreement.
///
/// **Callers save**, the `ItemSaleStore`/`WishlistPurchaseStore` shape — except `runCarryOver`,
/// which is its own intent with no other caller (the closure
/// `SyncMonitor.onSettled` runs) and so saves for itself.
///
/// MainActor by the project default, like `ItemSaleStore`: it writes through
/// the caller's `ModelContext`.
enum SellPlanStore {
    /// The plan exists from this instant (spec: "created when selecting
    /// Create a sell plan"). False, writing nothing, on a bought entry;
    /// true without rewriting the date when a plan already exists.
    ///
    /// Stamps `sellPlanCheckedAt` when nil, so any plan-state write settles
    /// the row. The caller saves.
    @discardableResult
    static func create(for wanted: WishlistItem, at now: Date) -> Bool {
        guard !wanted.isBought else { return false }
        if wanted.sellPlanCreatedAt == nil {
            wanted.sellPlanCreatedAt = now
        }
        if wanted.sellPlanCheckedAt == nil {
            wanted.sellPlanCheckedAt = now
        }
        return true
    }

    /// Decision 9, P3: the plan and the current selection go; the
    /// sold-toward record, every item, and the entry itself stay.
    ///
    /// Stamps `sellPlanCheckedAt` when nil — a defence rather than a path
    /// normal use reaches — so a later carry-over cannot re-plan the row from
    /// the sold-toward history it keeps. The caller saves.
    static func delete(planOf wanted: WishlistItem, at now: Date) {
        wanted.sellPlanCreatedAt = nil
        wanted.plannedSaleItems = []
        if wanted.sellPlanCheckedAt == nil {
            wanted.sellPlanCheckedAt = now
        }
    }

    /// P10: every unchecked entry with a selection or a sold-toward
    /// history gets a plan dated `now`; every unchecked entry is stamped
    /// checked. Returns how many plans it made. The caller saves.
    ///
    /// A bought row qualifies by its sold-toward history alone, since `015`
    /// released its selection — `awaitsCarryOver` is the one predicate. A
    /// checked row is never fetched, so a deleted plan never comes back.
    static func carryOver(in context: ModelContext, at now: Date) throws -> Int {
        let unchecked = try context.fetch(FetchDescriptor<WishlistItem>(
            predicate: #Predicate<WishlistItem> { $0.sellPlanCheckedAt == nil }
        ))
        var made = 0
        for wanted in unchecked {
            if wanted.awaitsCarryOver {
                wanted.sellPlanCreatedAt = now
                made += 1
            }
            wanted.sellPlanCheckedAt = now
        }
        return made
    }

    /// `carryOver`, then one save **only if `context.hasChanges`** — the
    /// closure `SyncMonitor.onSettled` runs, on every settle. On any failure
    /// — a failed fetch inside `carryOver` or a refused save — it rolls back,
    /// which discards *every* pending change on the main context, not only
    /// its own (the house caveat; the app saves each intent immediately, so
    /// there is normally nothing else).
    static func runCarryOver(in context: ModelContext, now: Date) {
        do {
            _ = try carryOver(in: context, at: now)
            if context.hasChanges {
                try context.save()
            }
        } catch {
            context.rollback()
        }
    }
}
