import Testing
import UIKit
@testable import Trove

/// The tab icons fail the way custom fonts do — silently, and looking like
/// nothing more than "the design isn't applied yet". Same reasoning as
/// `FontRegistrationTests`, so the same treatment.
///
/// Two ways to lose them without a compiler error. Misname an asset and
/// `Tab(_:image:value:)` draws an empty slot: three unlabelled gaps in the bar,
/// no warning. Lose the template intent and the glyph renders in the black it
/// was authored in — invisible against `background`, and identical to the
/// misnamed case at a glance.
///
/// **Uses `UIImage` deliberately**, a flagged exception under CLAUDE.md's
/// SwiftUI-only rule. `Image` has no way to ask whether an asset resolved or
/// how it renders; `UIImage(named:in:with:)` is the only API that can answer
/// either, the same shape of gap as `UIImage(data:)` in `PhotoSelection`.
/// Confined to this test file.
@Suite("Tab icons")
struct TabIconTests {
    /// The names `ContentView` passes to `Tab(_:image:value:)`.
    ///
    /// `nonisolated` because `@Test(arguments:)` evaluates its arguments
    /// outside the actor, and this target defaults to `MainActor` isolation.
    private nonisolated static let assetNames = ["TabDashboard", "TabItems", "TabWishlist"]

    private func icon(_ name: String) -> UIImage? {
        UIImage(named: name, in: .main, with: nil)
    }

    @Test(arguments: assetNames)
    func theAssetResolves(name: String) throws {
        #expect(
            icon(name) != nil,
            "No asset named \"\(name)\" — the tab draws an empty slot, not a failure"
        )
    }

    /// The tint on `TabView` is what colours these, in both states. A glyph
    /// that isn't template-rendered ignores it and keeps its authored black.
    @Test(arguments: assetNames)
    func theAssetIsTemplateRendered(name: String) throws {
        let image = try #require(icon(name), "No asset named \"\(name)\"")

        #expect(
            image.renderingMode == .alwaysTemplate,
            """
            \(name) renders as \(image.renderingMode), not alwaysTemplate. \
            Set "template-rendering-intent" to "template" in its Contents.json, \
            or it draws in its authored colour and ignores the brass tint.
            """
        )
    }

    /// Three distinct marks, not one asset wired up three times. Catches a
    /// copy-paste in `Contents.json` that the two checks above can't see —
    /// each would resolve, each would be a template, and the bar would show
    /// the same glyph three times.
    @Test func theThreeIconsAreThreeDifferentMarks() throws {
        let data = try Self.assetNames.map { name in
            let image = try #require(icon(name), "No asset named \"\(name)\"")
            return try #require(image.pngData(), "\(name) has no raster representation")
        }

        #expect(Set(data).count == data.count, "Two or more tabs are showing the same mark")
    }
}

/// The swipe actions' glyphs, guarded exactly as the tab icons above are and
/// for the same two silent failures: a misnamed asset draws an empty slot in
/// a swiped-open row, and a glyph that lost its template intent keeps the
/// black it was authored in — invisible on `accentRust`'s or
/// `accentBrassMid`'s fill, and indistinguishable from the misnamed case at a
/// glance. `TabIconTests`' own list is the tab bar's, so this is a sibling
/// suite rather than four more names in it.
///
/// `ActionSell` (014 G22) is the newest of them and the reason this suite
/// exists; the three that shipped in `001` come along because the same two
/// failures were never guarded for them either.
@Suite("Action icons")
struct ActionIconTests {
    /// The names `ItemListView`'s and the wishlist's swipe actions pass to
    /// `Image(_:)`. `nonisolated` for the same reason as the tab list above.
    private nonisolated static let assetNames = ["ActionEdit", "ActionDuplicate", "ActionDelete", "ActionSell"]

    private func icon(_ name: String) -> UIImage? {
        UIImage(named: name, in: .main, with: nil)
    }

    @Test(arguments: assetNames)
    func theAssetResolves(name: String) throws {
        #expect(
            icon(name) != nil,
            "No asset named \"\(name)\" — the swipe action draws an empty slot, not a failure"
        )
    }

    @Test(arguments: assetNames)
    func theAssetIsTemplateRendered(name: String) throws {
        let image = try #require(icon(name), "No asset named \"\(name)\"")

        #expect(
            image.renderingMode == .alwaysTemplate,
            """
            \(name) renders as \(image.renderingMode), not alwaysTemplate. \
            Set "template-rendering-intent" to "template" in its Contents.json, \
            or it draws in its authored black on the swipe button's fill.
            """
        )
    }

    /// Four distinct marks, not one asset wired up four times — the
    /// copy-paste in `Contents.json` that both checks above would pass.
    @Test func theFourIconsAreFourDifferentMarks() throws {
        let data = try Self.assetNames.map { name in
            let image = try #require(icon(name), "No asset named \"\(name)\"")
            return try #require(image.pngData(), "\(name) has no raster representation")
        }

        #expect(Set(data).count == data.count, "Two or more swipe actions are showing the same mark")
    }
}
