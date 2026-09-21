import Testing
@testable import Trove

/// T007, G21. The purchase sheet's load-bearing wiring, pinned as source
/// scans — `SaleFormWiringTests`' shape, for the same reason: no unit test can
/// tap a date in a popover or press a toolbar button, so what a test *can*
/// catch is a view body quietly changing out from under the spec. These are
/// facts about the body only. The sheet's *behaviour* — what the comparison
/// line says, what validation refuses, what a purchase carries — is
/// `PurchaseFormViewModelTests`' and is deliberately not restated here.
///
/// Each scan `#require`s its anchor before asserting anything about it, so a
/// renamed or deleted call fails loudly here rather than passing over nothing.
@Suite("Wishlist purchase sheet wiring")
struct WishlistPurchaseWiringTests {
    private nonisolated static let sheet = "Trove/Views/Wishlist/PurchaseFormView.swift"
    private nonisolated static let list = "Trove/Views/Wishlist/WishlistView.swift"
    private nonisolated static let detail = "Trove/Views/Wishlist/WishlistDetailView.swift"
    private nonisolated static let plan = "Trove/Views/Wishlist/SellPlanView.swift"

    /// The three screens that can mark an entry bought. Not the sheet: it
    /// hands a `Purchase` to its host and learns nothing about what became
    /// of it.
    private nonisolated static let purchaseHosts = [list, detail, plan]

    /// The spec's field order, twice over: the five elements are *declared* in
    /// that order, and the sheet's one column *composes* them in that order —
    /// two different edits, and either alone would move the comparison line
    /// out from under the price it comments on.
    ///
    /// Mutation: swap any two of the five, in either place → red.
    @Test func theFiveElementsAppearInTheSpecsOrder() throws {
        let code = try SourceScan.production(Self.sheet)

        try expectAscending(
            [
                "PurchaseCopy.purchasePriceLabel",
                "PurchaseCopy.purchaseDateLabel",
                "viewModel.comparisonLine",
                "PurchaseCopy.boughtFromLabel",
                "PurchaseCopy.conditionLabel",
            ],
            in: code,
            what: "the sheet's fields, declared"
        )

        let columns = SourceScan.closureBodies(
            after: "VStack(alignment: .leading, spacing: theme.metrics.sectionGap)",
            in: code
        )
        try #require(columns.count == 1, "the sheet builds \(columns.count) form columns, expected exactly 1")
        let column = try #require(columns.first)

        try expectAscending(
            ["priceAndDate", "comparison", "boughtFromField", "conditionField"],
            in: column,
            what: "the sheet's fields, composed"
        )
    }

    /// The sheet writes nothing and borrows nothing: it hands a `Purchase`
    /// to its host, so no store and no context appear here (the rule
    /// `SaleFormView` holds), and its words are its own — a `SaleCopy` string
    /// or a note field would be the sale sheet leaking into its twin, which
    /// this spec's non-goals rule out in both directions.
    ///
    /// Mutation: name any of the four → red.
    @Test func theSheetNamesNoSaleCopyNoNoteAndNothingThatWrites() throws {
        let code = try SourceScan.production(Self.sheet)

        #expect(
            !code.contains("SaleCopy"),
            "the purchase sheet reads SaleCopy — every word here comes from PurchaseCopy"
        )
        #expect(
            !code.contains("Note"),
            "the purchase sheet has a note field — the spec's four fields are the whole sheet"
        )
        #expect(
            !code.contains("ModelContext") && !code.contains("modelContext"),
            "the purchase sheet reaches a ModelContext — the host records the purchase, this view doesn't"
        )
        #expect(
            !code.contains("WishlistPurchaseStore"),
            "the purchase sheet writes through WishlistPurchaseStore — the host records the purchase, this view doesn't"
        )
    }

    /// Confirming asks the view model first: the toolbar button runs
    /// `record`, and `record` guards on `viewModel.purchase()` — returning
    /// rather than handing anything out when it comes back nil, which is how
    /// an invalid sheet stays open with the rust border on.
    ///
    /// Mutation: have `record` call `confirm` without the guard, or ahead of
    /// it → red.
    @Test func confirmingHandsThePurchaseOutPastTheViewModelsGuard() throws {
        let code = try SourceScan.production(Self.sheet)

        let confirmButtons = SourceScan.argumentLists(of: "Button", in: code)
            .filter { $0.contains("viewModel.confirmLabel") }
        try #require(
            confirmButtons.count == 1,
            "the sheet builds \(confirmButtons.count) confirm buttons, expected exactly 1"
        )
        let confirmButton = try #require(confirmButtons.first)
        #expect(
            confirmButton.contains("action: record"),
            "the confirm button doesn't run `record`:\n\(confirmButton)"
        )

        let bodies = SourceScan.closureBodies(after: "private func record()", in: code)
        try #require(bodies.count == 1, "the sheet declares \(bodies.count) `record` functions, expected exactly 1")
        let record = try #require(bodies.first)

        let guardWord = try #require(record.range(of: "guard"), "`record` doesn't guard:\n\(record)")
        let asks = try #require(
            record.range(of: "viewModel.purchase()"),
            "`record` never asks the view model for a purchase:\n\(record)"
        )
        let handsOut = try #require(
            record.range(of: "confirm("),
            "`record` never hands a purchase to its host:\n\(record)"
        )

        #expect(guardWord.lowerBound < asks.lowerBound, "`viewModel.purchase()` isn't the guard's own call:\n\(record)")
        #expect(
            asks.upperBound < handsOut.lowerBound,
            "`record` hands a purchase out before asking the view model for one:\n\(record)"
        )
        #expect(
            record.contains("else { return }"),
            "`record`'s guard doesn't return — an invalid sheet must stay open:\n\(record)"
        )
    }

    /// The two identifiers T012's device pass and any later UI test drive the
    /// sheet by. Whole literals, not substrings: a scan for
    /// `contains("purchase.sheet.comparison")` is satisfied by
    /// `"purchase.sheet.comparisonX"`, so a renamed identifier would slip
    /// past it — measured, not guessed. Mutation: rename or delete either →
    /// red.
    @Test func theIdentifiersArePresent() throws {
        let code = try SourceScan.production(Self.sheet)
        let literals = Set(SourceScan.stringLiterals(in: code))
        #expect(literals.contains("purchase.sheet.price"), "the price field's identifier is missing or renamed")
        #expect(
            literals.contains("purchase.sheet.comparison"),
            "the comparison line's identifier is missing or renamed"
        )
    }

    /// T012a, the person's decision at the device pass: the sheet carries
    /// **no navigation title**. It read "Mark as bought", the confirm button
    /// reads "Mark as bought", and in one inline bar the title truncated to
    /// "Mark as bo…" on all three hosts; the person's call was that the title
    /// is the redundant one. The absence is the rule now, so it needs a guard
    /// — this is a fact about the view body that no view-model test can
    /// observe, and `PurchaseFormViewModel.title` no longer exists for one to
    /// look at. The display mode is required alongside it, because dropping
    /// *that* too would give the bar a large-title layout with empty space
    /// where a title isn't, which is a different screen from the one the
    /// person approved.
    ///
    /// Mutation: put any `.navigationTitle(…)` back → red; drop
    /// `.navigationBarTitleDisplayMode(.inline)` → red.
    @Test func theSheetCarriesNoNavigationTitle() throws {
        let code = try SourceScan.production(Self.sheet)

        #expect(
            !code.contains("navigationTitle"),
            "the purchase sheet names a navigation title again — T012a removed it as redundant with the confirm button, which says the same words and truncated it to \"Mark as bo\u{2026}\""
        )
        #expect(
            code.contains(".navigationBarTitleDisplayMode(.inline)"),
            "the purchase sheet's bar isn't inline — without a title, a large-title bar holds empty space where the title isn't"
        )
    }

    /// Q9, the one deliberate divergence from the twin: the purchase date is
    /// **unbounded**. `SaleFormView`'s picker carries `in: ...viewModel.latestDate`
    /// because a sale in the future is not a sale; this sheet fills
    /// `Item.purchaseDate`, whose own editor takes any date at all. The bound
    /// is a fact about the popover's own control, which no view-model test can
    /// observe — `PurchaseFormViewModelTests` can only show that a future date
    /// validates, not that it is selectable.
    ///
    /// Mutation: paste a bound back in → red.
    @Test func theDatePickerIsUnbounded() throws {
        let code = try SourceScan.production(Self.sheet)

        let pickers = SourceScan.argumentLists(of: "DatePicker", in: code)
        try #require(pickers.count == 1, "the sheet builds \(pickers.count) DatePickers, expected exactly 1")
        let picker = try #require(pickers.first)

        #expect(
            picker.contains("selection: $viewModel.date"),
            "the picker doesn't write the view model's date:\n\(picker)"
        )
        #expect(
            !picker.contains("in:"),
            "the purchase date picker carries a bound — Q9 leaves it unbounded, as Item.purchaseDate's own editor is:\n\(picker)"
        )
    }

    /// The three things the spec says *about* the comparison line, which G21
    /// pinned the presence and position of but none of: criterion 6's "shows
    /// nothing when they are equal" — which holds only if the view asks the
    /// optional rather than defaulting it, since `Text(viewModel.comparisonLine
    /// ?? "")` would place an empty line's padding and still satisfy every
    /// other scan here — plan §7's "no colour branch", the spec's "not
    /// colour-coded as gain or loss", since an observation that turns red or
    /// green is a verdict, and the Design requirement that it stay **quiet**,
    /// "supporting text, not a figure competing with the price field". The
    /// swipe's `!contains("accentRust")` leg, three tests down, is the same
    /// shape for the same reason.
    ///
    /// The quiet leg is T011b's, the person's decision at the Phase 2 pause
    /// overturning plan §7's `.monoLabel(color:)`: that modifier uppercases
    /// and letterspaces, which drew the line in the identical treatment as the
    /// PURCHASE PRICE label above it. Sentence case is the rule now, and
    /// `monoLabel` is the one way to lose it — so the leg names it, alongside
    /// the house pairing for quiet supporting prose that replaced it. Case is
    /// applied by a modifier, not by the string, so `PurchaseCopy`'s own tests
    /// cannot see this; only the body can.
    ///
    /// Mutations: rewrite as `Text(viewModel.comparisonLine ?? "")` → red;
    /// colour it with any accent → red; put `.monoLabel(color:)` back → red.
    @Test func theComparisonLineIsConditionalOnTheOptionalAndCarriesNoAccent() throws {
        let code = try SourceScan.production(Self.sheet)

        let bodies = SourceScan.closureBodies(after: "private var comparison: some View", in: code)
        try #require(bodies.count == 1, "the sheet declares \(bodies.count) comparison lines, expected exactly 1")
        let comparison = try #require(bodies.first)

        #expect(
            comparison.contains("if let line = viewModel.comparisonLine"),
            "the comparison line isn't conditional on the optional, so equal figures would still place a line (criterion 6):\n\(comparison)"
        )
        #expect(
            !comparison.contains("accent"),
            "the comparison line wears an accent colour — it is an observation, not a verdict on gain or loss (plan \u{00A7}7):\n\(comparison)"
        )
        #expect(
            !comparison.contains("monoLabel"),
            "the comparison line wears the all-caps letterspaced label treatment, so it reads as a second PURCHASE PRICE label rather than an observation (T011b):\n\(comparison)"
        )
        #expect(
            comparison.contains(".font(theme.typography.secondary)")
                && comparison.contains(".foregroundStyle(theme.colors.textQuiet)"),
            "the comparison line isn't the house pairing for quiet supporting prose \u{2014} secondary on textQuiet (T011b):\n\(comparison)"
        )
    }

    // MARK: - The list's swipe (G15)

    /// G15, criterion 1 from the list's side: the wishlist row's one leading
    /// swipe is Edit, **Buy**, Copy in that order — Edit still nearest the
    /// edge, so a full swipe still edits — the middle button stages the row
    /// for the purchase sheet rather than the form sheet, says `markAsBought`
    /// to VoiceOver while reading "Buy" on screen (plan Q14), and wears the
    /// brass mid-tone and the bag glyph; the trailing swipe is still the
    /// delete alone, naming nothing about buying.
    ///
    /// The three buttons are cut apart at their own `Button` keywords rather
    /// than scanned over the whole block, so *which* button carries which
    /// word, target and tint is what's pinned — a block containing all three
    /// words in any arrangement would otherwise pass. `ItemListSidesWiringTests`'
    /// twin, since `014` settled this shape on the Items list.
    ///
    /// Mutations: swap the Buy and Copy buttons → red; the middle button
    /// writing `itemBeingEdited` → red.
    @Test func theWishlistRowsLeadingSwipeOffersEditThenBuyThenCopy() throws {
        let code = try SourceScan.production(Self.list)

        let trailing = SourceScan.closureBodies(after: ".swipeActions(edge: .trailing)", in: code)
        try #require(trailing.count == 1, "the wishlist rows carry \(trailing.count) trailing swipe blocks, expected exactly 1")
        #expect(
            !trailing[0].contains("PurchaseCopy"),
            "the trailing swipe names PurchaseCopy — buying belongs on the leading swipe, the delete stays alone (criterion 1): \(trailing[0])"
        )

        let blocks = SourceScan.closureBodies(after: ".swipeActions(edge: .leading)", in: code)
        try #require(blocks.count == 1, "the wishlist rows carry \(blocks.count) leading swipe blocks, expected exactly 1")
        let leading = try #require(blocks.first)

        let starts = leading.ranges(of: "Button").map(\.lowerBound)
        try #require(
            starts.count == 3,
            "the leading swipe carries \(starts.count) buttons, expected 3 — Edit, Buy, Copy"
        )
        let buttons = starts.indices.map { index -> String in
            let end = index + 1 < starts.count ? starts[index + 1] : leading.endIndex
            return String(leading[starts[index]..<end])
        }

        #expect(
            buttons[0].contains("Text(\"Edit\")"),
            "the button nearest the edge isn't Edit — a full swipe would stop editing (criterion 1): \(buttons[0])"
        )
        #expect(buttons[0].contains("itemBeingEdited = item"), "the first button doesn't open the form sheet: \(buttons[0])")

        #expect(
            buttons[1].contains("Text(PurchaseCopy.swipeBuy)"),
            "the middle button doesn't read the swipe's own word: \(buttons[1])"
        )
        #expect(
            buttons[1].contains("itemBeingBought = item"),
            "the middle button doesn't stage the row for the purchase sheet: \(buttons[1])"
        )
        #expect(
            buttons[1].contains(".accessibilityLabel(PurchaseCopy.markAsBought)"),
            "the Buy button doesn't say the menu row's own name to VoiceOver (plan Q14): \(buttons[1])"
        )
        #expect(buttons[1].contains("Image(\"ActionBuy\")"), "the Buy button wears no bag glyph: \(buttons[1])")
        #expect(
            buttons[1].contains(".tint(theme.colors.accentBrassMid)"),
            "the Buy button isn't the brass mid-tone — the one brass that reads mid in both appearances (plan Q14): \(buttons[1])"
        )
        #expect(
            !buttons[1].contains("accentRust"),
            "the Buy button is rust, which stays the one consequential colour on a swiped-open row: \(buttons[1])"
        )

        #expect(buttons[2].contains("Text(\"Copy\")"), "the last button isn't Copy: \(buttons[2])")
        #expect(buttons[2].contains("viewModel.duplicate"), "the last button doesn't duplicate: \(buttons[2])")
    }

    /// G15's other half: the purchase sheet is hosted here, once, over the
    /// row's own entry — the `.sheet(item:)` shape the Items list uses for the
    /// sale sheet (014 plan §5), so two rows can never both be being bought —
    /// seeded by the view model's factory rather than a `PurchaseFormViewModel`
    /// built in the view, confirming through `markBought` and clearing the
    /// staging on both exits. The write stays the view model's: the screen
    /// never names the store itself (plan Q4).
    ///
    /// Mutation: drop `itemBeingBought = nil` from the confirm closure → red
    /// (the sheet would stay up over a bought entry).
    @Test func thePurchaseSheetIsHostedOnceOverTheStagedRow() throws {
        let code = try SourceScan.production(Self.list)

        #expect(
            code.ranges(of: ".sheet(item: $itemBeingBought").count == 1,
            "the list presents \(code.ranges(of: ".sheet(item: $itemBeingBought").count) purchase sheets, expected exactly 1"
        )
        #expect(
            code.contains(".sheet(item: $itemBeingBought, onDismiss: viewModel.load)"),
            "the purchase sheet doesn't re-read the list on dismiss, so a bought entry would linger on the wishlist"
        )

        let bodies = SourceScan.closureBodies(after: ".sheet(item: $itemBeingBought", in: code)
        try #require(bodies.count == 1, "the purchase sheet opens \(bodies.count) spans, expected exactly 1")
        let sheet = try #require(bodies.first)

        #expect(sheet.contains("PurchaseFormView("), "the purchase sheet composes something other than the shared purchase form: \(sheet)")
        #expect(
            sheet.contains("viewModel.makePurchaseFormViewModel(for: item)"),
            "the sheet seeds its own form instead of the view model's, which is what keeps every host's defaults equal: \(sheet)"
        )
        #expect(
            sheet.contains("viewModel.markBought(item, purchase: purchase)"),
            "the sheet confirms into something other than `markBought`: \(sheet)"
        )
        #expect(
            sheet.ranges(of: "itemBeingBought = nil").count == 2,
            "the sheet clears its staging \(sheet.ranges(of: "itemBeingBought = nil").count) times, expected 2 — confirm and cancel both close it"
        )

        #expect(
            !code.contains("WishlistPurchaseStore"),
            "the list names the purchase store directly — the write belongs behind the view model"
        )
    }

    // MARK: - The wanted entry's page (G17, G19)

    /// G17, criterion 2: **Mark as bought…** is offered from the page's menu
    /// and from nowhere else on the page. The word is counted over the whole
    /// file and required to appear exactly once, then that one occurrence is
    /// shown to sit inside the `DetailOverflowMenu(` argument list — so a
    /// button added to `content(for:)` takes the count to 2 and fails here,
    /// which is the half of criterion 2 that says what the page *doesn't*
    /// have. `SoldStateWiringTests` pins the rows themselves.
    ///
    /// Mutations: add a page button naming the word → the count goes to 2 →
    /// red; move the word out of the menu → the second leg red; drop the row
    /// → the count is 0 → red.
    @Test func theMenuIsTheOnlyPlaceThePageOffersMarkAsBought() throws {
        let code = try SourceScan.production(Self.detail)

        let mentions = code.ranges(of: "PurchaseCopy.markAsBought").count
        try #require(
            mentions == 1,
            "the page names PurchaseCopy.markAsBought \(mentions) times, expected exactly 1 — the menu row is the whole offer, the page itself carries no button (criterion 2)"
        )

        let menus = SourceScan.argumentLists(of: "DetailOverflowMenu", in: code)
            .filter { $0.contains("noun:") }
        try #require(menus.count == 1, "the page composes \(menus.count) overflow menus, expected exactly 1")
        let menu = try #require(menus.first)

        #expect(
            menu.contains("PurchaseCopy.markAsBought"),
            "the page's one mention of Mark as bought… isn't in its menu — criterion 2 puts it there and nowhere else:\n\(menu)"
        )
    }

    /// G17's other half: the sheet the row opens is the shared purchase form,
    /// presented once, seeded by the view model exactly as the list's and the
    /// Sell Plan's are, and confirmed through `markBought` — the write stays
    /// the view model's, so the page never names the store.
    ///
    /// Cancelling lowers the binding (criterion 4: cancelling changes nothing
    /// at all). Without it the sheet does not close at all, since
    /// `isPresented` stays true — and nothing else in the project asserts it.
    ///
    /// Mutations: seed a `PurchaseFormViewModel` in the view → red; confirm
    /// into anything but `markBought` → red; present the sheet twice → the
    /// `#require` fails; drop `isMarkingBought = false` from the cancel
    /// closure → red.
    @Test func thePurchaseSheetIsPresentedOnceOverTheEntryThePageHolds() throws {
        let code = try SourceScan.production(Self.detail)

        let sheets = SourceScan.closureBodies(after: ".sheet(isPresented: $isMarkingBought", in: code)
        try #require(
            sheets.count == 1,
            "the page presents \(sheets.count) purchase sheets, expected exactly 1"
        )
        let sheet = try #require(sheets.first)

        #expect(
            sheet.contains("PurchaseFormView("),
            "the purchase sheet composes something other than the shared purchase form:\n\(sheet)"
        )
        #expect(
            sheet.contains("viewModel.makePurchaseFormViewModel()"),
            "the sheet seeds its own form instead of the view model's, which is what keeps every host's defaults equal:\n\(sheet)"
        )
        #expect(
            sheet.contains("viewModel.markBought(purchase: purchase)"),
            "the sheet confirms into something other than `markBought`, the one path into the store:\n\(sheet)"
        )

        let cancels = SourceScan.closureBodies(after: "cancel:", in: sheet)
        try #require(cancels.count == 1, "the sheet carries \(cancels.count) cancel closures, expected exactly 1")
        #expect(
            cancels[0].contains("isMarkingBought = false"),
            "cancelling doesn't lower the binding, so the sheet would not close at all (criterion 4):\n\(cancels[0])"
        )

        #expect(
            !code.contains("WishlistPurchaseStore"),
            "the page names the purchase store directly — the write belongs behind the view model"
        )
    }

    /// G19, R2: a page already on the stack when its entry is bought gets
    /// itself out of the way. `.onAppear` reloads *first* — `load()` is what
    /// sets `hasBeenBought` — and pops only under that flag, so the ordering
    /// is pinned as well as the presence: a guard read before the reload
    /// would test the value the screen was pushed with.
    ///
    /// Mutations: drop the guard (back to `.onAppear(perform: viewModel.load)`)
    /// → red; dismiss unconditionally → the guard's body is gone → red; read
    /// `hasBeenBought` before `load()` → the ordering leg red.
    @Test func thePageDismissesItselfOnAppearOnceItsEntryIsBought() throws {
        let code = try SourceScan.production(Self.detail)

        let appearances = SourceScan.closureBodies(after: ".onAppear", in: code)
        try #require(
            appearances.count == 1,
            "the page carries \(appearances.count) .onAppear closures, expected exactly 1"
        )
        let appear = try #require(appearances.first)

        let reload = try #require(
            appear.range(of: "viewModel.load()"),
            "the page's .onAppear no longer reloads:\n\(appear)"
        )
        let flag = try #require(
            appear.range(of: "viewModel.hasBeenBought"),
            "the page's .onAppear doesn't read hasBeenBought — a page pushed onto a bought entry would stay up (R2):\n\(appear)"
        )
        #expect(
            reload.upperBound < flag.lowerBound,
            "the guard reads hasBeenBought before load() has set it:\n\(appear)"
        )

        let guarded = SourceScan.closureBodies(after: "if viewModel.hasBeenBought", in: appear)
        try #require(
            guarded.count == 1,
            "the .onAppear has \(guarded.count) `if viewModel.hasBeenBought` branches, expected exactly 1"
        )
        #expect(
            guarded[0].contains("dismiss()"),
            "the bought branch doesn't dismiss the page (R2):\n\(guarded[0])"
        )
    }

    // MARK: - The Sell Plan (G18)

    /// G18, criterion 3: the plan offers **Mark as bought…** from one bar
    /// button in its top-right corner, and only while the entry the plan
    /// belongs to is still there — the screen draws `missingItem` when it has
    /// gone, and an ungated button would be tappable over no subject. The
    /// gate's span is what the button is required to sit *inside*, so a button
    /// moved out of it fails here rather than passing on the words alone.
    ///
    /// The button reads the **word** "Buy" (`PurchaseCopy.swipeBuy`), not a
    /// glyph — T012a, the person's decision at the device pass: a bare outline
    /// bag alone in a toolbar most often means *cart*, on the one screen in
    /// the app whose whole subject is selling. The word is the swipe's own
    /// short form rather than a second constant for one action. Pinned here as
    /// the rule, both halves — the word present and no glyph at all — rather
    /// than loosened to tolerate either spelling.
    ///
    /// Mutations: drop the gate → no `viewModel.wishlistItem != nil` span →
    /// red; move the button out of the gate → the span is empty of it → red;
    /// drop the identifier T012 drives it by → red; put `Image(systemName:
    /// "bag")` back in place of the word → both new legs red.
    @Test func theSellPlanOffersMarkAsBoughtOnlyWhileItsEntryIsStillThere() throws {
        let code = try SourceScan.production(Self.plan)

        let mentions = code.ranges(of: "PurchaseCopy.markAsBought").count
        try #require(
            mentions == 1,
            "the plan names PurchaseCopy.markAsBought \(mentions) times, expected exactly 1 — one bar button is the whole offer (criterion 3)"
        )

        let toolbars = SourceScan.closureBodies(after: ".toolbar", in: code)
        try #require(toolbars.count == 1, "the plan carries \(toolbars.count) toolbars, expected exactly 1")
        let toolbar = try #require(toolbars.first)

        let gates = SourceScan.closureBodies(after: "if viewModel.wishlistItem != nil", in: toolbar)
        try #require(
            gates.count == 1,
            "the plan's toolbar carries \(gates.count) `viewModel.wishlistItem != nil` gates, expected exactly 1 — an ungated button would confirm a purchase of nothing when the entry has gone"
        )
        let gate = try #require(gates.first)

        #expect(
            gate.contains("ToolbarItem(placement: .topBarTrailing)"),
            "the gated button isn't the top-right bar item the wanted entry's \u{2026} occupies:\n\(gate)"
        )

        let actions = SourceScan.closureBodies(after: "Button", in: gate)
        try #require(actions.count == 1, "the gate holds \(actions.count) buttons, expected exactly 1 — a bar button, not a menu")
        #expect(
            actions[0].contains("isMarkingBought = true"),
            "the plan's button doesn't open the purchase sheet:\n\(actions[0])"
        )

        #expect(
            gate.contains("Text(PurchaseCopy.swipeBuy)"),
            "the plan's button doesn't wear the word Buy \u{2014} T012a replaced the bag glyph with it, since a bare outline bag alone in a toolbar reads as *cart* on the one screen whose subject is selling:\n\(gate)"
        )
        #expect(
            !gate.contains("Image("),
            "the plan's button carries a glyph again \u{2014} T012a made it the word alone:\n\(gate)"
        )
        #expect(
            gate.contains(".accessibilityLabel(PurchaseCopy.markAsBought)"),
            "the plan's button doesn't say Mark as bought\u{2026} to VoiceOver — a bare glyph says nothing:\n\(gate)"
        )

        let literals = Set(SourceScan.stringLiterals(in: gate))
        #expect(
            literals.contains("purchase.sellPlan"),
            "the plan's button carries no identifier for T012's device pass to drive it by:\n\(gate)"
        )
    }

    /// G18's other half, R2: the plan hosts the shared purchase form once —
    /// beside the sale sheet it already presents, not instead of it — seeded
    /// by the view model exactly as the list's and the page's are, and a
    /// purchase that *took* pops this screen, since the plan's subject is no
    /// longer wanted. `dismiss()` is required inside the `markBought` branch
    /// rather than anywhere in the closure, so dismissing unconditionally
    /// fails here too: a refused save rolls back, leaving the entry and its
    /// plan exactly as they were, and the person should stay on a screen that
    /// is still correct rather than be popped off it. Staying put is half of
    /// what the person is told; since T012b the other half is the refusal
    /// alert `everyPurchaseHostShowsTheRefusalAlert` pins, reading
    /// `purchaseFailureMessage` — before it, the reason was recorded in a
    /// property no view read and a refusal was silent.
    ///
    /// Cancelling lowers the binding (criterion 4: cancelling changes nothing
    /// at all). Without it the sheet does not close at all, since
    /// `isPresented` stays true — and nothing else in the project asserts it.
    ///
    /// Mutations: drop the `dismiss()` → red; host the sheet twice → red;
    /// dismiss outside the branch → red; drop `isMarkingBought = false` from
    /// the cancel closure → red.
    @Test func thePlansPurchaseSheetIsHostedOnceAndPopsTheScreenOnlyOnceItTakes() throws {
        let code = try SourceScan.production(Self.plan)

        let hosts = code.ranges(of: ".sheet(isPresented: $isMarkingBought").count
        try #require(hosts == 1, "the plan presents \(hosts) purchase sheets, expected exactly 1")

        let sheets = SourceScan.closureBodies(after: ".sheet(isPresented: $isMarkingBought", in: code)
        let sheet = try #require(sheets.first)

        #expect(
            sheet.contains("PurchaseFormView("),
            "the purchase sheet composes something other than the shared purchase form:\n\(sheet)"
        )
        #expect(
            sheet.contains("viewModel.makePurchaseFormViewModel()"),
            "the sheet seeds its own form instead of the view model's, which is what keeps every host's defaults equal:\n\(sheet)"
        )

        let confirms = SourceScan.closureBodies(after: "confirm:", in: sheet)
        try #require(confirms.count == 1, "the sheet carries \(confirms.count) confirm closures, expected exactly 1")
        let confirm = try #require(confirms.first)

        let took = SourceScan.closureBodies(after: "if viewModel.markBought(purchase: purchase)", in: confirm)
        try #require(
            took.count == 1,
            "confirming runs \(took.count) `viewModel.markBought(purchase:)` branches, expected exactly 1 — the one path into the store, and the only thing that may pop this screen"
        )
        #expect(
            took[0].contains("dismiss()"),
            "a purchase that took doesn't pop the plan, so the person would be left on a plan for something they now own (R2):\n\(confirm)"
        )

        let cancels = SourceScan.closureBodies(after: "cancel:", in: sheet)
        try #require(cancels.count == 1, "the sheet carries \(cancels.count) cancel closures, expected exactly 1")
        #expect(
            cancels[0].contains("isMarkingBought = false"),
            "cancelling doesn't lower the binding, so the sheet would not close at all (criterion 4):\n\(cancels[0])"
        )

        #expect(
            !code.contains("WishlistPurchaseStore"),
            "the plan names the purchase store directly — the write belongs behind the view model"
        )
    }

    // MARK: - The refusal alert (T012b)

    /// Every host that can mark an entry bought can say that it didn't
    /// (T012b). A view-body fact and nothing else: what the message *says*,
    /// and which property it comes from, is behaviour that
    /// `WishlistDetailViewModelTests.everyHostRefusesToBuyAnEntryTwice`
    /// asserts by refusing a purchase for real. What no view-model test can
    /// see is whether any view ever renders it — which is exactly the state
    /// all three screens were in before this task: the reason was recorded
    /// and nothing read it, so a refused purchase closed the sheet in
    /// silence.
    ///
    /// Mutations: delete the alert from any one host → that host's case goes
    /// red; present it off `exportFailureMessage` or the Sell Plan's
    /// `saveFailureMessage` → red; drop the `set:` half so OK cannot lower
    /// it → red.
    @Test(arguments: purchaseHosts)
    func everyPurchaseHostShowsTheRefusalAlert(path: String) throws {
        let code = try SourceScan.production(path)

        let alerts = SourceScan.argumentLists(of: ".alert", in: code)
            .filter { $0.contains("PurchaseCopy.failureTitle") }
        try #require(
            alerts.count == 1,
            "\(path) presents \(alerts.count) refusal alerts, expected exactly 1 — a refused purchase must not be silent"
        )
        let alert = alerts[0]

        #expect(
            alert.contains("viewModel.purchaseFailureMessage != nil"),
            "\(path)'s refusal alert is presented off something other than the host's own purchase failure:\n\(alert)"
        )
        #expect(
            alert.contains("viewModel.purchaseFailureMessage = nil"),
            "\(path)'s refusal alert never clears the message, so OK would leave it pending and it would show again:\n\(alert)"
        )
        // The message closure sits *outside* the argument list's parentheses,
        // so `alert` above cannot hold it — and a whole-file scan for it is
        // no scan at all here, since `WishlistView` carries four alerts and
        // `WishlistDetailView` two: a neighbouring alert's message would
        // satisfy it while this one said nothing (T012e). Scoped instead to
        // the first `message:` closure after this alert's arguments, which
        // is this alert's own — a trailing closure follows its call
        // immediately — and required to arrive before any later `.alert(`,
        // so a refusal alert with no message of its own cannot borrow the
        // next one's.
        let tail = String(code[try #require(code.range(of: alert), "\(path)").upperBound...])
        let messageLabel = try #require(
            tail.range(of: "message:"),
            "\(path)'s refusal alert has no message at all — a refusal the person cannot read"
        )
        if let nextAlert = tail.range(of: ".alert(") {
            try #require(
                messageLabel.lowerBound < nextAlert.lowerBound,
                "\(path)'s refusal alert carries no message closure — the next one found belongs to the alert after it"
            )
        }
        let message = try #require(
            SourceScan.closureBodies(after: "message:", in: tail).first,
            "\(path)'s refusal alert has an unterminated message closure"
        )
        #expect(
            message.contains("Text(viewModel.purchaseFailureMessage ?? PurchaseCopy.failureMessage)"),
            "\(path) doesn't show the host's own message, only the generic one — the already-bought sentence is the refusal a person actually meets:\n\(message)"
        )
    }

    // MARK: - Private

    /// Each token present, and each one's first appearance after the last —
    /// first appearance, so a later mention can't stand in for the missing
    /// one.
    private func expectAscending(_ tokens: [String], in source: String, what: String) throws {
        var offsets: [Int] = []
        for token in tokens {
            let range = try #require(source.range(of: token), "\(what): `\(token)` is missing")
            offsets.append(source.distance(from: source.startIndex, to: range.lowerBound))
        }

        for index in offsets.indices.dropFirst() {
            #expect(
                offsets[index] > offsets[index - 1],
                "\(what): `\(tokens[index])` comes before `\(tokens[index - 1])` — expected \(tokens)"
            )
        }
    }
}
