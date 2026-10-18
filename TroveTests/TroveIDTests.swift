import Foundation
import SwiftData
import Testing
@testable import Trove

/// 021/T001 (G1, plan §1): the Trove ID is `id`, and these are the store's
/// half of the claims that rests on — a code assigned **before insert** (the
/// kept-code path an import takes) is what a second context reads back, and
/// the store does not refuse two rows sharing one (CloudKit forbids
/// `@Attribute(.unique)`, so nothing makes it). The edit, sale, return, Copy
/// and purchase legs live beside the suites that already exercise those
/// writers: `ItemFormViewModelEditTests`, `WishlistFormSaveTests`,
/// `ItemSaleStoreTests`, `ItemDuplicationTests`, `WishlistDuplicationTests`
/// and `WishlistPurchaseStoreTests`.
///
/// The known codes are literals, never `UUID()`, so a row that silently
/// kept its initializer's fresh default instead reads as a different code.
@Suite("The Trove ID")
struct TroveIDTests {
    private let itemCode = UUID(uuidString: "6F1C2A4E-0B7D-4E21-9C3A-5D8E7F102A11")!
    private let entryCode = UUID(uuidString: "A2D94B70-3E15-4C8F-B6A1-0F9E8D7C6B22")!

    /// Mutation: the `save()` dropped → the second context finds nothing.
    @Test func aCodeAssignedBeforeInsertIsWhatASecondContextReadsBack() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster")
        item.id = itemCode
        let wanted = WishlistItem(name: "D-18")
        wanted.id = entryCode
        context.insert(item)
        context.insert(wanted)
        try context.save()

        let elsewhere = ModelContext(container)
        let code = itemCode
        let entry = entryCode
        let items = try elsewhere.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == code }))
        let entries = try elsewhere.fetch(FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == entry }))
        #expect(items.map(\.name) == ["Telecaster"])
        #expect(entries.map(\.name) == ["D-18"])
    }

    /// The fact plan R2 and T001a are built on: two rows given the same code
    /// both persist — the store neither refuses the second nor folds it into
    /// the first. If this goes red without a mistake in the test, the store
    /// is stricter than the plan assumes.
    @Test func twoRowsSharingACodeBothPersist() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        for name in ["Telecaster", "Jazzmaster"] {
            let item = Item(name: name)
            item.id = itemCode
            context.insert(item)
        }
        for name in ["D-18", "Vox AC15"] {
            let wanted = WishlistItem(name: name)
            wanted.id = entryCode
            context.insert(wanted)
        }
        try context.save()

        let elsewhere = ModelContext(container)
        let items = try elsewhere.fetch(FetchDescriptor<Item>())
        let entries = try elsewhere.fetch(FetchDescriptor<WishlistItem>())
        #expect(Set(items.map(\.name)) == ["Telecaster", "Jazzmaster"])
        #expect(items.allSatisfy { $0.id == itemCode })
        #expect(Set(entries.map(\.name)) == ["D-18", "Vox AC15"])
        #expect(entries.allSatisfy { $0.id == entryCode })
    }
}
