import Foundation
import Testing
@testable import Trove

/// G3: `SellPlanCopy`'s table, pinned whole by literal (the `PurchaseCopyTests`
/// model) — every string in plan §3, both forms of each counted string, and
/// the delete message's one varying clause.
@Suite("Sell plan copy")
struct SellPlanCopyTests {
    // MARK: - The tab and the entry point

    @Test func theTabAndItsSides() {
        #expect(SellPlanCopy.tab == "Plans")
        #expect(SellPlanCopy.active == "Active")
        #expect(SellPlanCopy.completed == "Completed")
        #expect(SellPlanCopy.sideSwitchLabel == "Active or completed")
    }

    @Test func theEntryPointsWords() {
        #expect(SellPlanCopy.createPlan == "Create a sell plan")
        #expect(SellPlanCopy.noPlanSubtitle == "Browse your lowest desire-to-keep items")
        #expect(SellPlanCopy.viewPlan == "View your sell plan")
    }

    // MARK: - A row's lines

    @Test func theCountedLinesInBothForms() {
        #expect(SellPlanCopy.setAside(1) == "1 item set aside")
        #expect(SellPlanCopy.setAside(3) == "3 items set aside")
        #expect(SellPlanCopy.soldToward(1) == "1 sold toward it")
        #expect(SellPlanCopy.soldToward(4) == "4 sold toward it")
        #expect(SellPlanCopy.soldTowardPast(1) == "1 was sold toward it")
        #expect(SellPlanCopy.soldTowardPast(2) == "2 were sold toward it")
        #expect(SellPlanCopy.activeCount(1) == "1 active sell plan")
        #expect(SellPlanCopy.activeCount(5) == "5 active sell plans")
    }

    @Test func theFixedRowWords() {
        #expect(SellPlanCopy.nothingSetAside == "Nothing set aside yet")
        #expect(SellPlanCopy.covered == "Covered")
        #expect(SellPlanCopy.nothingSoldToward == "Nothing was sold toward it.")
    }

    /// The date is the device's own abbreviated form — `SaleCopyTests`'
    /// shape — so the literal pinned is the word around it.
    @Test func theBoughtLine() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let day = date.formatted(date: .abbreviated, time: .omitted)
        #expect(SellPlanCopy.bought(on: date) == "Bought \(day)")
    }

    // MARK: - Deleting a plan

    @Test func theDeleteConfirmationsWords() {
        #expect(SellPlanCopy.overflowNoun == "sell plan")
        #expect(SellPlanCopy.deleteTitle(for: "Summicron 35mm f/2") == "Delete the sell plan for Summicron 35mm f/2?")
        #expect(SellPlanCopy.deleteConfirm == "Delete")
        #expect(SellPlanCopy.deleteCancel == "Keep")
        #expect(SellPlanCopy.deleteMessage(isCompleted: false)
            == "Nothing you own or sold is touched, and it stays on your wishlist. What sold toward it stays on the record. This can't be undone.")
        #expect(SellPlanCopy.deleteMessage(isCompleted: true)
            == "Nothing you own or sold is touched, and the item you bought stays in your collection. What sold toward it stays on the record. This can't be undone.")
    }

    /// The guard against `WishlistDeleteCopy`'s recorded drift (plan §3): the
    /// two renderings, split into sentences, differ in exactly one — the one
    /// carrying the clause. The literals above pin the words; this pins the
    /// shape, so a shared sentence reworded on one side goes red here even if
    /// both literals were updated to match.
    ///
    /// Mutation: reword "This can't be undone." in the completed branch only
    /// → two sentences differ and this fails.
    @Test func theTwoDeleteMessagesDifferInExactlyOneSentence() {
        let active = sentences(SellPlanCopy.deleteMessage(isCompleted: false))
        let completed = sentences(SellPlanCopy.deleteMessage(isCompleted: true))

        #expect(active.count == 3)
        #expect(completed.count == active.count)
        let differing = zip(active, completed).filter { $0 != $1 }
        #expect(differing.count == 1)
        #expect(differing.first?.0 == "Nothing you own or sold is touched, and it stays on your wishlist.")
    }

    private func sentences(_ text: String) -> [String] {
        text.components(separatedBy: ". ")
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
    }

    // MARK: - The dashboard card and the empty states

    @Test func theDashboardCardsWords() {
        #expect(SellPlanCopy.cardHeader == "Sell plans")
        #expect(SellPlanCopy.cardHint == "Shows your active sell plans")
    }

    @Test func theEmptyStatesWords() {
        #expect(SellPlanCopy.noPlansHeadline == "No sell plans yet")
        #expect(SellPlanCopy.noPlansDetail
            == "A plan starts from something on your wishlist. Open it and tap Create a sell plan.")
        #expect(SellPlanCopy.nothingWantedHeadline == "Nothing on your wishlist")
        #expect(SellPlanCopy.nothingWantedDetail
            == "A sell plan starts with something you want. Add it to your wishlist first.")
        #expect(SellPlanCopy.nothingCompletedHeadline == "Nothing completed yet")
        #expect(SellPlanCopy.nothingCompletedDetail == "A plan lands here when you mark its item bought.")
        #expect(SellPlanCopy.stillSyncingDetail
            == "Your plans are on their way to this device. They'll appear here as they arrive.")
    }
}
