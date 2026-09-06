import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// Where the Market section is drawn, and what it is allowed to be —
/// the half `MarketSectionState`'s own tests can't see, since a section
/// that no screen composes resolves its states perfectly well.
///
/// Scans, so each one names the mutation it dies to (plan §9's discipline):
/// put the wishlist ghost back and `theWishlistScreenNoLongerCarriesTheGhost`
/// goes red; drop the link's hint and `theLinkSaysItLeavesTheApp` does;
/// make the link a `Button` and `theOutwardLinkIsALinkNotAButton` does;
/// type any copy into the section and `MarketVocabularyTests`' no-space
/// rule does.
@Suite("Market section wiring")
struct MarketWiringTests {
    private static let section = "Trove/Views/Market/MarketSection.swift"
    private static let notice = "Trove/Views/Market/MarketNoticeView.swift"
    private static let picker = "Trove/Views/Market/MarketMatchView.swift"
    private static let slider = "Trove/Views/Market/MarketValueSlider.swift"
    private static let fetching = "Trove/Views/Market/MarketFetchingView.swift"
    private static let valueStep = "Trove/Views/Market/MarketValueStepView.swift"
    private static let detailScreens = [
        ("Trove/Views/Items/ItemDetailView.swift", "private func content(for item: Item) -> some View {"),
        ("Trove/Views/Wishlist/WishlistDetailView.swift", "private func content(for item: WishlistItem) -> some View {"),
    ]

    /// Drawn *from* `content(for:)`, and composed exactly once.
    ///
    /// Both halves are needed and neither is enough: counting over the whole
    /// file would be satisfied by a helper nobody calls (the dead-guard shape
    /// this project has shipped twice), and pinning only the call would be
    /// satisfied by a helper that had stopped building a section. Each screen
    /// wraps the composition in a helper the way it wraps `statPair`,
    /// `desireCard` and `details` — so the scan follows the call rather than
    /// demanding the screens break their own shape.
    @Test func bothDetailScreensComposeTheSectionInsideTheirContent() throws {
        for (file, declaration) in Self.detailScreens {
            let code = try SourceScan.production(file)
            let content = try body(of: declaration, in: code)
            #expect(
                content.contains("marketSection(for: item)"),
                "\(file): content(for:) never draws the Market section"
            )
            let composed = code.ranges(of: "MarketSection(").count
            #expect(composed == 1, "\(file): composes \(composed) Market sections — one screen, one section")
        }
    }

    /// The two screens hand over the view model's state and every intent:
    /// the section derives nothing, and Change match… is Find on Reverb…
    /// over an existing match (plan §6), which no compiler check can pin.
    @Test func bothScreensHandOverTheStateAndEveryIntent() throws {
        for (file, _) in Self.detailScreens {
            let code = try SourceScan.production(file)
            for wiring in [
                "state: viewModel.marketState",
                "activity: viewModel.marketActivity",
                "notice: viewModel.marketNotice",
                "canRefresh: viewModel.canRefresh",
                "canAdopt: viewModel.canAdopt",
                "find: viewModel.findMatch",
                "refresh: viewModel.refresh",
                "changeMatch: viewModel.findMatch",
                "removeMatch: viewModel.removeMatch",
                "year: item.year",
            ] {
                #expect(code.contains(wiring), "\(file): the section isn't given `\(wiring)`")
            }
        }
    }

    /// B5: the section's adopt action **opens the value step** rather than
    /// writing (Amendment B, Decision 34's "one adopt control"). Scanned
    /// inside the `MarketSectionActions(` argument list, not over the file:
    /// `adopt(cents:)` is still called from this screen — by the value
    /// step's own button — so a scan over the whole file would pass with the
    /// section writing directly again.
    ///
    /// This pin replaces the intent list's `viewModel.adopt(cents:` (T022's
    /// interim one-tap adopt): the same wiring, at the place it now lives.
    @Test func theSectionsAdoptActionOpensTheValueStep() throws {
        for (file, _) in Self.detailScreens {
            let code = try SourceScan.production(file)
            let lists = SourceScan.argumentLists(of: "MarketSectionActions", in: code)
            try #require(lists.count == 1, "\(file): composes \(lists.count) section action sets")
            #expect(
                lists[0].contains("adopt: viewModel.openValueStep"),
                "\(file): the section's adopt action isn't `openValueStep`: \(lists[0])"
            )
            #expect(
                !lists[0].contains("adopt(cents:"),
                "\(file): the section's actions write a value straight from the section"
            )
        }
    }

    /// The ghost the section replaces (`010`'s reserved block) is gone —
    /// its view, its bar heights, and both strings it put on screen.
    @Test func theWishlistScreenNoLongerCarriesTheGhost() throws {
        let file = "Trove/Views/Wishlist/WishlistDetailView.swift"
        let code = try SourceScan.production(file)
        for remnant in ["marketPricePlaceholder", "placeholderBarHeights", "Market price", "Not tracked yet"] {
            #expect(!code.contains(remnant), "\(file): the market ghost survives as `\(remnant)`")
        }
        #expect(code.contains("MarketSection("), "the control failed: nothing replaced the ghost")
    }

    /// Criterion 20's link half: a real `Link`, so VoiceOver carries the
    /// `.isLink` trait, and not a `Button` reaching for `openURL` — which
    /// would look identical on screen and read as an in-place action.
    /// The boundary keeps `NavigationLink(` from standing in for it (the
    /// `SettingsWiringTests` regex).
    @Test func theOutwardLinkIsALinkNotAButton() throws {
        let code = try SourceScan.production(Self.section)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        let links = code.ranges(of: link).count
        #expect(links == 1, "the section draws \(links) links — the product link is the one and only")
        #expect(!code.contains("openURL"), "the section opens a URL by hand instead of linking")
    }

    @Test func theLinkSaysItLeavesTheApp() throws {
        let code = try SourceScan.production(Self.section)
        #expect(code.contains("MarketCopy.reverbLinkHint"), "the link carries no hint that it leaves the app")
    }

    /// The section reads as its parts, each labelled — not as one run-on
    /// sentence the way a list row does.
    @Test func theSectionContainsItsPartsRatherThanCombiningThem() throws {
        let code = try SourceScan.production(Self.section)
        #expect(
            code.contains(".accessibilityElement(children: .contain)"),
            "the section root doesn't contain its parts"
        )
        #expect(!code.contains(".combine"), "the section combines its parts into one label")
    }

    @Test func everyActionCarriesTheIdentifierThePlanNames() throws {
        let code = try SourceScan.production(Self.section)
        for identifier in [
            "market.find", "market.refresh", "market.adopt",
            "market.changeMatch", "market.removeMatch", "market.link",
        ] {
            #expect(code.contains(identifier), "no target carries the identifier \(identifier)")
        }
    }

    /// Every word and every accessibility string comes from `MarketCopy`.
    /// `MarketVocabularyTests` proves the section types none of its own;
    /// this proves it reads the ones plan §6 gives it, so a reading, a
    /// notice or a label can't quietly go missing.
    @Test func theSectionReadsEveryStringItShowsFromMarketCopy() throws {
        let code = try SourceScan.production(Self.section)
        for symbol in [
            "MarketCopy.sectionTitle",
            "MarketCopy.sourceLine(title:",
            "MarketCopy.allYearsFallback(year:",
            "MarketCopy.median(cents:",
            "MarketCopy.separator",
            "MarketCopy.listed(count:",
            "MarketCopy.spread(lowCents:",
            "MarketCopy.age(fetchedAt:",
            "MarketCopy.withheld(usedLowCents:",
            "MarketCopy.refreshDue",
            "MarketCopy.notRefreshedHere",
            "MarketCopy.unreachable(fetchedAt:",
            "MarketCopy.unreachableNoFigure",
            "MarketCopy.rateLimited",
            "MarketCopy.productGone",
            "MarketCopy.findOnReverb",
            "MarketCopy.refresh",
            "MarketCopy.useAsMyValue",
            "MarketCopy.useAsEstimatedCost",
            "MarketCopy.changeMatch",
            "MarketCopy.removeMatch",
            "MarketCopy.viewOnReverb",
            "MarketCopy.figureAccessibilityLabel(medianCents:",
            "MarketCopy.countAccessibilityLabel(",
            "MarketCopy.spreadAccessibilityLabel(lowCents:",
            "MarketCopy.ageAccessibilityLabel(fetchedAt:",
            "MarketCopy.refreshWithinHourHint",
        ] {
            #expect(code.contains(symbol), "the section doesn't read \(symbol)")
        }
    }

    // MARK: - The match sheet (T011, plan §6, Q9)

    /// One sheet, two phases (Q9). Four halves, and each is needed: the
    /// presentation is counted so a second sheet over the same flag can't
    /// appear; `onDismiss: viewModel.load` is pinned inside it, since a
    /// picked match writes through the view model and the screen behind
    /// re-reads only on `load()`; the branch is followed into `matchSheet`
    /// so the notice can't be dropped; and the detent selection is pinned —
    /// the phase the mapping observes *and* the mapping's own two lines —
    /// because a notice at the large detent is a different sheet.
    @Test func bothDetailScreensPresentTheOneMatchSheet() throws {
        for (file, _) in Self.detailScreens {
            let code = try SourceScan.production(file)
            let presented = code.ranges(of: ".sheet(isPresented: $viewModel.isFindingMatch, onDismiss: viewModel.load)").count
            #expect(presented == 1, "\(file): presents \(presented) match sheets with the load on dismiss")

            let sheet = try body(of: "private var matchSheet: some View {", in: code)
            for wiring in [
                "viewModel.sheetStep",
                "MarketNoticeView(",
                "viewModel.continueFromNotice",
                "viewModel.declineNotice",
                "MarketMatchView(",
                "viewModel.makeMatchViewModel()",
                "viewModel.setMatch",
                ".presentationDetents([.medium, .large], selection:",
                // The phase, not the whole step (T022's third review): the
                // value step's payload changes on every slider tick, and a
                // detent that re-decides on each of them is the bug this
                // pins shut.
                ".onChange(of: viewModel.sheetStep.phase, initial: true)",
                // The mapping itself, not only the observer: it is written
                // out in both screens, so pinning the two lines is what
                // catches one of them diverging — swap the detents in either
                // and only that screen goes red (T022's fourth review).
                "case .notice, .value: .medium",
                "case .pick, .fetching: .large",
            ] {
                #expect(sheet.contains(wiring), "\(file): the match sheet isn't wired to `\(wiring)`")
            }
        }
    }

    /// B5's four-phase half (Amendment B): the sheet draws *every* phase of
    /// `MarketSheetStep`, each with its own view. Followed into `matchSheet`
    /// rather than over the file, and each phase named by its case as well as
    /// by the view it composes — so a phase falling back to a bare
    /// `ProgressView`, which is exactly what T022 left here on purpose, goes
    /// red instead of rendering a blank sheet in a shipped build.
    @Test func theMatchSheetComposesAllFourPhases() throws {
        for (file, _) in Self.detailScreens {
            let code = try SourceScan.production(file)
            let sheet = try body(of: "private var matchSheet: some View {", in: code)
            for (phase, view) in [
                ("case .notice:", "MarketNoticeView("),
                ("case .pick:", "MarketMatchView("),
                ("case .fetching(let candidate, _):", "MarketFetchingView(candidate: candidate)"),
                ("case .value(let step):", "MarketValueStepView("),
            ] {
                #expect(sheet.contains(phase), "\(file): the sheet has no `\(phase)` branch")
                #expect(sheet.contains(view), "\(file): the sheet's phases don't compose `\(view)`")
            }
            // The value step's three intents, which no compiler check pins
            // to the right view model methods.
            for wiring in [
                "choose: viewModel.setChosen",
                "viewModel.adopt(cents:",
                "notNow: viewModel.dismissValueStep",
            ] {
                #expect(sheet.contains(wiring), "\(file): the value step isn't wired to `\(wiring)`")
            }
        }
    }

    /// The fetching phase keeps the picked card on screen and says what is
    /// running (Decision 33) — the two halves of "the sheet does not go
    /// blank", neither of which the four-phase scan can see from the screens.
    @Test func theFetchingPhaseKeepsTheCardAndSaysWhatIsRunning() throws {
        let code = try SourceScan.production(Self.fetching)
        #expect(code.contains("MarketCandidateCard(candidate:"), "the fetching phase drops the picked card")
        #expect(
            code.contains("MarketCopy.fetchingAskingPrices"),
            "the fetching phase doesn't say that asking prices are being fetched"
        )
        #expect(code.contains("MarketStatusLine("), "the fetching phase doesn't use the picker's status line")
    }

    /// The value step draws Trove's own slider — bound to the view model's
    /// write, since the step is a value and a copy of it would move the knob
    /// and change nothing — and carries the plan's three identifiers.
    @Test func theValueStepComposesTheSliderAndItsTargets() throws {
        let code = try SourceScan.production(Self.valueStep)
        #expect(code.contains("MarketValueSlider(step:"), "the value step draws no slider")
        #expect(
            code.contains("onChange: actions.choose"),
            "the slider's writes don't reach the view model's `setChosen`"
        )
        for identifier in ["market.value.slider", "market.value.use", "market.value.notNow"] {
            #expect(code.contains(identifier), "no target carries the identifier \(identifier)")
        }
    }

    /// Every word the value step shows comes from `MarketCopy`
    /// (`MarketVocabularyTests` proves it types none of its own; this proves
    /// it reads the ones the spec's Copy block gives it), and the figure is
    /// drawn by the section's own pieces so the two surfaces can't drift.
    /// The spread is the **true** low–high, not the slider's trimmed ends
    /// (Decision 36) — pinned by the arguments it is given.
    @Test func theValueStepReadsItsCopyAndDrawsTheSectionsFigure() throws {
        let code = try SourceScan.production(Self.valueStep)
        for symbol in [
            "MarketCopy.valueStepTitle(wanted:",
            "MarketCopy.sourceLine(title:",
            "MarketCopy.valueGuidance",
            "MarketCopy.useAmount(cents:",
            "MarketCopy.noticeNotNow",
            "MarketFigureRow(medianCents: step.medianCents, count: step.count)",
            "MarketSpreadLine(lowCents: step.lowCents, highCents: step.highCents)",
        ] {
            #expect(code.contains(symbol), "the value step doesn't read \(symbol)")
        }
    }

    /// P15's whole point: the notice offers the policy to read, and an
    /// alert couldn't have held it (Q9).
    @Test func theNoticeCarriesALinkToThePrivacyPolicy() throws {
        let code = try SourceScan.production(Self.notice)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        #expect(code.contains(link), "the notice draws no link at all")
        #expect(code.contains("MarketCopy.privacyPolicyURL"), "the notice's link doesn't point at the privacy policy")
        #expect(!code.contains("openURL"), "the notice opens a URL by hand instead of linking")
    }

    /// Decision 28: every candidate carries its own way out to Reverb, so
    /// the person can look before committing. A real `Link` again, and the
    /// hint that says it leaves the app.
    @Test func everyCandidateCardLinksOutToReverb() throws {
        let code = try SourceScan.production(Self.picker)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        let links = code.ranges(of: link).count
        #expect(links == 1, "the picker draws \(links) links — the card's is the one and only")
        #expect(code.contains("ReverbAPI.productURL(slug:"), "the card's link doesn't address the product page")
        #expect(code.contains("MarketCopy.reverbLinkHint"), "the card's link carries no hint that it leaves the app")
    }

    /// Q17: a candidate's thumbnail is fetched by `AsyncImage` through the
    /// OS's shared URL cache — transport, not app storage. Exactly one file
    /// under `Trove/Views` may do it, so a second surface can't start
    /// fetching images without this going red.
    @Test func onlyThePickerFetchesAnImageFromTheNetwork() throws {
        let viewFiles = try SourceScan.swiftFiles(under: "Trove/Views", minimum: 20)
        let fetchers = try viewFiles.filter { try SourceScan.production($0).contains("AsyncImage(") }
        #expect(fetchers == [Self.picker], "the files fetching images are \(fetchers)")
    }

    @Test func everyTargetOnTheSheetCarriesTheIdentifierThePlanNames() throws {
        let noticeCode = try SourceScan.production(Self.notice)
        for identifier in ["market.notice.continue", "market.notice.notNow", "market.notice.privacy"] {
            #expect(noticeCode.contains(identifier), "no target carries the identifier \(identifier)")
        }

        let pickerCode = try SourceScan.production(Self.picker)
        for identifier in ["market.search", "market.candidate", "market.candidate.link"] {
            #expect(pickerCode.contains(identifier), "no target carries the identifier \(identifier)")
        }
    }

    /// Amendment B removed the sheet's Bool outright rather than keeping it
    /// as a derived property to hold the older pins green (plan, "Churn the
    /// wiring scans take"). A property nobody sets is the shape that goes
    /// quietly wrong, so the scan is over all of `Trove/`, not the two
    /// screens: the flag is gone from the app or this is red.
    @Test func theSheetsOldNoticeFlagIsGoneFromTheApp() throws {
        let appFiles = try SourceScan.swiftFiles(under: "Trove", minimum: 20)
        let carrying = try appFiles.filter { try SourceScan.production($0).contains("noticeIsPending") }
        #expect(carrying.isEmpty, "`noticeIsPending` survives in \(carrying) — `sheetStep` replaced it")
        // The control: the scan reads real source, so an empty result can't
        // come from a walk that found nothing. Named files rather than a
        // count (T024): the two view models are the ones that *own* the
        // phase, and a count would drift with every screen that reads it.
        let carryingTheStep = try appFiles.filter { try SourceScan.production($0).contains("sheetStep") }
        for owner in [
            "Trove/ViewModels/ItemDetailViewModel.swift",
            "Trove/ViewModels/WishlistDetailViewModel.swift",
        ] {
            #expect(carryingTheStep.contains(owner), "the walk didn't find `sheetStep` in \(owner)")
        }
    }

    /// B5's slider half (plan Amendment B, spec Decision 34's Design line):
    /// the value slider is **Trove's own control**, not a system `Slider`
    /// dressed in brass — a distinction no render test can draw, since a
    /// tinted system slider would sample much the same.
    ///
    /// The boundary regex is the point: a bare `contains("Slider(")` fires
    /// on `MarketValueSlider(`, which would make the guard permanently red
    /// the moment anything composed it. The character before the word has
    /// to be a non-identifier one.
    @Test func theValueSliderIsTrovesOwnControl() throws {
        let code = try SourceScan.production(Self.slider)
        let systemSlider = try Regex(#"(?:^|[^A-Za-z0-9_])Slider\("#)
        let found = code.ranges(of: systemSlider).count
        #expect(
            found == 0,
            "the value slider is a system `Slider` — the spec's Design line asks for Trove's own control"
        )
        // The control: the pattern does match the word where it stands
        // alone, so an empty result can't come from a regex that matches
        // nothing — and doesn't match the file's own type name.
        #expect("  Slider(value: $x)".firstMatch(of: systemSlider) != nil)
        #expect("  MarketValueSlider(step: step)".firstMatch(of: systemSlider) == nil)
        #expect(code.contains("accessibilityAdjustableAction"), "the slider can't be adjusted by VoiceOver")
    }

    /// The drag mapping is a pure static seam so the snap and the rounding
    /// can be tested directly (`MarketValueSliderTests`); this is the half
    /// that check can't see — that the gesture *uses* it rather than
    /// repeating the arithmetic inline, where it would drift untested. Same
    /// for the VoiceOver step: `adjustableStep` written as a literal in the
    /// action would leave its own test green.
    @Test func theSlidersGestureAndAdjustmentGoThroughTheSeam() throws {
        let code = try SourceScan.production(Self.slider)

        let dragged = SourceScan.closureBodies(after: ".onChanged", in: code)
        try #require(dragged.count == 1, "the slider has \(dragged.count) drag closures — one gesture, one mapping")
        #expect(
            dragged[0].contains("cents(atX:"),
            "the drag closure maps x to cents itself instead of calling the seam: \(dragged[0])"
        )

        let adjusted = SourceScan.closureBodies(after: "accessibilityAdjustableAction", in: code)
        try #require(adjusted.count == 1, "the slider has \(adjusted.count) adjustable actions")
        #expect(
            adjusted[0].contains("adjustableStep("),
            "the adjustable action steps by something other than `adjustableStep`: \(adjusted[0])"
        )
    }

    /// `TrendArrowWiringTests`' brace matcher, for the same reason it has
    /// one: the question is what a single declaration's body contains.
    private func body(of declaration: String, in code: String) throws -> String {
        let start = try #require(code.range(of: declaration), "\(declaration) is gone")
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        Issue.record("\(declaration) never closes")
        return ""
    }
}

/// The link in pixels.
///
/// plan §6 asks for this specifically: whether `.buttonStyle(.plain)` — or
/// anything else in the environment — styles a SwiftUI `Link` is *verified,
/// not assumed*, because a link that silently drew in the system tint would
/// leave every source scan green and every artboard wrong. The
/// `TrendArrowRenderTests` instrument, on the one part of the section whose
/// ink is a design decision rather than a text token.
@Suite("Market link render")
struct MarketLinkRenderTests {
    private let colors = ThemeColors.dark

    /// The rendered ink is the token at full strength, so the tolerance
    /// only covers 8-bit rounding — `TrendArrowRenderTests`' reasoning.
    private let tolerance = 0.02

    @Test func theLinkIsDrawnInTheBrassTheDesignGivesIt() throws {
        let ink = try linkInk()
        #expect(
            Perceptual.distance(ink, colors.accentBrass) < tolerance,
            "the link is not accentBrass — measured \(ink), ΔE \(Perceptual.distance(ink, colors.accentBrass))"
        )
        // The mutation this is really watching for: brass swapped to the
        // ink the readings are set in, which no scan would notice.
        #expect(
            Perceptual.distance(ink, colors.accentBrass) < Perceptual.distance(ink, colors.textPrimary),
            "the link read closer to textPrimary than to brass — measured \(ink)"
        )
    }

    /// The strongest pixel the link draws: the one furthest from the
    /// transparent black the renderer composites onto. Every other pixel is
    /// an antialiased fraction of it.
    private func linkInk() throws -> RGB8 {
        let url = try #require(URL(string: "https://reverb.com/p/example"))
        let image = try #require(renderBitmap(MarketReverbLink(url: url)), "ImageRenderer produced nothing to sample.")
        let bitmap = try #require(Bitmap(image), "Couldn't read the rendered pixels.")
        let backdrop = RGB8(red: 0, green: 0, blue: 0)

        var strongest: RGB8?
        var distance = 0.0
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                let reach = Perceptual.distance(pixel, backdrop)
                if reach > distance {
                    distance = reach
                    strongest = pixel
                }
            }
        }

        return try #require(strongest, "the link drew no ink at all")
    }
}

// MARK: - 002/T013: the dashboard's market line

/// Where the dashboard's market line is drawn, and what it is allowed to
/// be (002 criterion 15, Decision 22, plan §6) — the half
/// `DashboardMarketTests` can't see, since a view model whose line no
/// screen composes still composes a perfect line.
///
/// Each scan names the mutation it dies to: drop the `hasMarketFigures`
/// gate and `theMarketLineIsGatedOnHavingFigures` goes red; type the word
/// "Market" into the screen and `theDashboardTypesNoMarketCopyOfItsOwn`
/// does.
@Suite("Dashboard market line wiring")
struct DashboardMarketWiringTests {
    private static let dashboard = "Trove/Views/Dashboard/DashboardView.swift"

    /// The gate and the line are one construction: the line is drawn inside
    /// `if viewModel.hasMarketFigures`, inside `headline`'s own body.
    /// Scanning the whole file would be satisfied by a gate somewhere else
    /// entirely — or by a helper nobody calls, the dead-guard shape this
    /// project has shipped twice.
    @Test func theMarketLineIsGatedOnHavingFigures() throws {
        let code = try SourceScan.production(Self.dashboard)
        let headline = try #require(
            SourceScan.closureBodies(after: "private var headline: some View", in: code).first,
            "the headline block is gone"
        )
        let gated = SourceScan.closureBodies(after: "if viewModel.hasMarketFigures", in: headline)
        #expect(
            gated.contains { $0.contains("viewModel.marketLine") },
            "headline draws no market line behind `if viewModel.hasMarketFigures`"
        )
    }

    /// The words come from `MarketCopy` through `marketLine`, never from the
    /// screen — so spec P10's vocabulary scan covers them (it reads
    /// `MarketCopy.swift`, not this file).
    @Test func theDashboardTypesNoMarketCopyOfItsOwn() throws {
        let code = try SourceScan.production(Self.dashboard)
        let typed = SourceScan.stringLiterals(in: code).filter { $0.contains("Market") }
        #expect(typed.isEmpty, "the dashboard types market copy of its own: \(typed)")
    }
}
