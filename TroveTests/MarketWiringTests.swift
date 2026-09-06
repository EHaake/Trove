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
                "viewModel.adopt(cents:",
                "changeMatch: viewModel.findMatch",
                "removeMatch: viewModel.removeMatch",
                "year: item.year",
            ] {
                #expect(code.contains(wiring), "\(file): the section isn't given `\(wiring)`")
            }
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
        let fetching = try Self.filesUnderViews().filter { try SourceScan.production($0).contains("AsyncImage(") }
        #expect(fetching == [Self.picker], "the files fetching images are \(fetching)")
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
        let carrying = try Self.allAppSwiftFiles().filter { try SourceScan.production($0).contains("noticeIsPending") }
        #expect(carrying.isEmpty, "`noticeIsPending` survives in \(carrying) — `sheetStep` replaced it")
        // The control: the scan reads real source, so an empty result can't
        // come from a walk that found nothing.
        let carryingTheStep = try Self.allAppSwiftFiles().filter { try SourceScan.production($0).contains("sheetStep") }
        #expect(carryingTheStep.count >= 4, "the walk found `sheetStep` in only \(carryingTheStep.count) files")
    }

    /// The same walk `ExportWiringTests` uses — asserted non-trivial so a
    /// moved source root fails loudly instead of scanning nothing.
    private static func allAppSwiftFiles(file: StaticString = #filePath) throws -> [String] {
        let root = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove")
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var paths: [String] = []
        while let url = walker?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                paths.append("Trove/" + url.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }
        try #require(paths.count > 20, "source walk found only \(paths.count) files — wrong root?")
        return paths.sorted()
    }

    /// Every `.swift` under `Trove/Views`, as repo-relative paths — walked
    /// rather than listed, so a new view file is covered the day it lands.
    private static func filesUnderViews(file: StaticString = #filePath) throws -> [String] {
        let root = URL(filePath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        let views = root.appending(path: "Trove/Views")
        let found = FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { $0.path().replacingOccurrences(of: root.path().hasSuffix("/") ? root.path() : root.path() + "/", with: "") }
        return (found ?? []).sorted()
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
