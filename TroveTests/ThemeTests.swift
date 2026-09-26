import Foundation
import SwiftUI
import Testing
@testable import Trove

/// Pins every color to the exact value in `design/tokens.md`.
///
/// Seventeen hex values transcribed by hand is seventeen chances to fat-finger
/// a digit, and a wrong one is close enough to right that it survives a glance
/// at the simulator. The expected numbers below are written as separate
/// channel literals rather than hex strings so they can be checked against the
/// token table without re-reading the implementation.
@Suite("Theme color tokens")
struct ThemeColorTokenTests {
    private func rgba(_ color: Color) -> (red: Int, green: Int, blue: Int, opacity: Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (
            Int((Double(resolved.red) * 255).rounded()),
            Int((Double(resolved.green) * 255).rounded()),
            Int((Double(resolved.blue) * 255).rounded()),
            (Double(resolved.opacity) * 100).rounded() / 100
        )
    }

    private let colors = ThemeColors.dark

    @Test func surfaceTokensMatchTheTokenTable() {
        #expect(rgba(colors.background) == (0x17, 0x18, 0x1A, 1.0))
        #expect(rgba(colors.surface) == (0x20, 0x1F, 0x1D, 1.0))
        #expect(rgba(colors.surfaceInset) == (0x26, 0x27, 0x2A, 1.0))
        #expect(rgba(colors.divider) == (0x3A, 0x3B, 0x3E, 1.0))
    }

    /// Every text token is the same ivory at a different opacity, so the
    /// channels are constant and only the alpha varies.
    @Test func textTokensAreTheSameInkAtDescendingOpacity() {
        #expect(rgba(colors.textPrimary) == (0xF2, 0xED, 0xE4, 1.0))
        #expect(rgba(colors.textBody) == (0xF2, 0xED, 0xE4, 0.75))
        #expect(rgba(colors.textLabel) == (0xF2, 0xED, 0xE4, 0.60))
        #expect(rgba(colors.textLabelSecondary) == (0xF2, 0xED, 0xE4, 0.55))
        #expect(rgba(colors.textMonoMeta) == (0xF2, 0xED, 0xE4, 0.45))
        #expect(rgba(colors.textQuiet) == (0xF2, 0xED, 0xE4, 0.40))
        #expect(rgba(colors.textDisabled) == (0xF2, 0xED, 0xE4, 0.35))
        #expect(rgba(colors.textInactive) == (0xF2, 0xED, 0xE4, 0.30))
    }

    @Test func accentTokensMatchTheTokenTable() {
        #expect(rgba(colors.accentBrass) == (0xC7, 0x9A, 0x56, 1.0))
        #expect(rgba(colors.accentBrassHover) == (0xDD, 0xB8, 0x77, 1.0))
        #expect(rgba(colors.accentBrassTint) == (0xC7, 0x9A, 0x56, 0.12))
        #expect(rgba(colors.accentMoss) == (0x52, 0x63, 0x4F, 1.0))
        #expect(rgba(colors.accentMossText) == (0x7E, 0x96, 0x79, 1.0))
        #expect(rgba(colors.accentRust) == (0x9C, 0x4A, 0x34, 1.0))
        #expect(rgba(colors.accentRustText) == (0xB8, 0x67, 0x4F, 1.0))
        #expect(rgba(colors.dialMidpoint) == (0x8F, 0x8C, 0x38, 1.0))
        #expect(rgba(colors.accentBrassDim) == (0x74, 0x61, 0x40, 1.0))
        #expect(rgba(colors.categoryNeutral) == (0x6B, 0x6C, 0x6F, 1.0))
    }

    /// tokens.md is explicit that the text-safe lifts are an accessibility fix,
    /// not decoration, and must not be collapsed into one value per accent.
    @Test func textSafeAccentLiftsAreDistinctFromTheirShapeColors() {
        #expect(colors.accentMossText != colors.accentMoss)
        #expect(colors.accentRustText != colors.accentRust)
    }
}

/// Pins every **light** token (spec `004`) to the exact value in
/// `design/tokens.md`'s light column, mirroring `ThemeColorTokenTests`.
///
/// The expected numbers are transcribed by hand from the tokens.md light
/// column as separate channel literals — not read back from
/// `ThemeColors.light`, which would only prove the source equals itself. A
/// flipped digit in either the source or the pin parts them.
@Suite("Light theme color tokens")
struct LightThemeColorTokenTests {
    private func rgba(_ color: Color) -> (red: Int, green: Int, blue: Int, opacity: Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (
            Int((Double(resolved.red) * 255).rounded()),
            Int((Double(resolved.green) * 255).rounded()),
            Int((Double(resolved.blue) * 255).rounded()),
            (Double(resolved.opacity) * 100).rounded() / 100
        )
    }

    private let colors = ThemeColors.light

    @Test func surfaceTokensMatchTheTokenTable() {
        #expect(rgba(colors.background) == (0xEC, 0xE7, 0xDC, 1.0))
        #expect(rgba(colors.surface) == (0xF7, 0xF2, 0xE9, 1.0))
        #expect(rgba(colors.surfaceInset) == (0xED, 0xE7, 0xDA, 1.0))
        #expect(rgba(colors.divider) == (0xD5, 0xCD, 0xBB, 1.0))
    }

    /// One warm near-black ink at descending opacity — the dark palette's
    /// structure with the ink inverted, so the channels are constant and only
    /// the alpha varies.
    @Test func textTokensAreTheSameInkAtDescendingOpacity() {
        #expect(rgba(colors.textPrimary) == (0x23, 0x20, 0x1B, 1.0))
        #expect(rgba(colors.textBody) == (0x23, 0x20, 0x1B, 0.75))
        #expect(rgba(colors.textLabel) == (0x23, 0x20, 0x1B, 0.60))
        #expect(rgba(colors.textLabelSecondary) == (0x23, 0x20, 0x1B, 0.55))
        #expect(rgba(colors.textMonoMeta) == (0x23, 0x20, 0x1B, 0.45))
        #expect(rgba(colors.textQuiet) == (0x23, 0x20, 0x1B, 0.40))
        #expect(rgba(colors.textDisabled) == (0x23, 0x20, 0x1B, 0.35))
        #expect(rgba(colors.textInactive) == (0x23, 0x20, 0x1B, 0.30))
    }

    @Test func accentTokensMatchTheTokenTable() {
        #expect(rgba(colors.accentBrass) == (0x80, 0x4A, 0x00, 1.0))
        #expect(rgba(colors.accentBrassHover) == (0x9C, 0x5D, 0x0E, 1.0))
        #expect(rgba(colors.accentBrassDim) == (0xC6, 0xA9, 0x7C, 1.0))
        #expect(rgba(colors.accentBrassMid) == (0xA3, 0x79, 0x46, 1.0))
        #expect(rgba(colors.accentBrassTint) == (0x80, 0x4A, 0x00, 0.12))
        #expect(rgba(colors.accentMoss) == (0x88, 0x99, 0x79, 1.0))
        #expect(rgba(colors.accentMossText) == (0x3E, 0x51, 0x37, 1.0))
        #expect(rgba(colors.accentRust) == (0xD4, 0x7D, 0x5B, 1.0))
        #expect(rgba(colors.accentRustText) == (0x8E, 0x3A, 0x24, 1.0))
        #expect(rgba(colors.dialMidpoint) == (0x44, 0x6A, 0x22, 1.0))
        #expect(rgba(colors.categoryNeutral) == (0x7C, 0x7D, 0x80, 1.0))
    }

    /// The extruded-plate alphas and the gauge track — pinned too, so "every
    /// light token is pinned" is literally true (spec `004` criterion 9).
    @Test func plateAndGaugeAlphasMatchTheTokenTable() {
        #expect(rgba(colors.plateHighlight) == (0xFF, 0xFF, 0xFF, 0.70))
        #expect(rgba(colors.plateEdgeShadow) == (0x00, 0x00, 0x00, 0.12))
        #expect(rgba(colors.plateCastShadow) == (0x00, 0x00, 0x00, 0.10))
        #expect(rgba(colors.gaugeTrack) == (0x23, 0x20, 0x1B, 0.16))
    }

    /// The text-safe lifts remain distinct from their shape colours — on a
    /// light ground the lift darkens the accent rather than lightening it, but
    /// it must still be its own value, not collapsed onto the shape colour.
    @Test func textSafeAccentLiftsAreDistinctFromTheirShapeColors() {
        #expect(colors.accentMossText != colors.accentMoss)
        #expect(colors.accentRustText != colors.accentRust)
    }
}

/// "Light mode is colour-only" (plan.md Q4) as a checked claim rather than a
/// comment: `Theme.light` differs from `Theme.dark` in its colours and nothing
/// else. `ThemeMetrics`/`ThemeTypography` gained `Equatable` for exactly this.
@Suite("Theme composition")
struct ThemeCompositionTests {
    @Test func lightSharesDarksMetrics() {
        #expect(Theme.light.metrics == Theme.dark.metrics)
    }

    @Test func lightSharesDarksTypography() {
        #expect(Theme.light.typography == Theme.dark.typography)
    }

    /// The claim would be vacuous if the two themes' colours were also equal —
    /// then "colour-only" difference could mean "no difference". They aren't.
    @Test func lightAndDarkColoursDiffer() {
        #expect(Theme.light.colors.surface != Theme.dark.colors.surface)
    }
}

/// plan.md claims colors are "never hardcoded per-view" and that swapping the
/// active `Theme` is all a future light mode needs. That claim is only true
/// while it stays true, and it degrades the moment one view reaches for a
/// literal — so it gets checked rather than asserted, per CLAUDE.md.
///
/// **One recorded exception** (`018` Decisions 15 and 17): the glass header
/// controls are system controls, and their label takes the system's label
/// colour — `.primary`, which follows the appearance on its own — rather
/// than the root brass tint or any theme colour. `systemLabelExemptions`
/// names each such text by file; both scans honour it, a line is let
/// through only if it is clean once the named text is taken out, so nothing
/// else in that file and that text in no other file gets past, and an entry
/// that no longer matches its file fails the scan that would otherwise
/// flag it rather than lingering.
@Suite("No hardcoded colors in views")
struct NoHardcodedColorsTests {
    /// `Color.clear` is absence of color rather than a palette choice, so it's
    /// allowed; everything else on this list is a real violation.
    private static let systemColorNames = [
        "red", "blue", "green", "yellow", "orange", "purple", "pink", "brown",
        "gray", "grey", "black", "white", "cyan", "mint", "teal", "indigo",
        "primary", "secondary", "accentColor",
    ]

    /// Decisions 15 and 17 (018): glass header controls are system controls;
    /// their label takes the system's label colour, which follows the
    /// appearance. The glass style paints its label with the button's tint,
    /// so the colour is the tint; the glyph's bars are colour views so they
    /// draw at the tint's full strength.
    private static let systemLabelExemptions: [String: [String]] = [
        "SortMenu.swift": [".tint(.primary)", "Color.primary"],
    ]

    private static let colorTakingModifiers = [
        "foregroundStyle", "foregroundColor", "fill", "background", "tint",
        "stroke", "strokeBorder",
    ]

    private var viewsDirectory: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent() // TroveTests/
            .deletingLastPathComponent() // repo root
            .appending(path: "Trove/Views")
    }

    private func swiftFilesToCheck() throws -> [URL] {
        let directory = viewsDirectory

        // Fail loudly rather than vacuously passing if the sources can't be
        // reached — a scan over zero files would look green forever.
        #expect(
            FileManager.default.fileExists(atPath: directory.path()),
            "Can't reach \(directory.path()) — this test would pass over nothing."
        )

        let enumerator = try #require(
            FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        )
        let files = enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            // The Theme is where literals are supposed to live.
            .filter { !$0.path().contains("/Views/Shared/Theme/") }

        #expect(files.isEmpty == false, "Found no view sources to scan.")
        return files
    }

    /// The leading `\b` matters: without it this matched any identifier ending
    /// in "Color(" — `DesireDial.arcColor(for:in:)`, or a plain
    /// `.foregroundColor(theme.colors.x)` — and reported them as literals.
    /// `Color(` still has to be flagged wherever it's genuinely constructed,
    /// which the word boundary leaves intact: the character before it is
    /// always a space, dot or paren in real calls.
    @Test func noViewConstructsAColorDirectly() throws {
        let names = Self.systemColorNames.joined(separator: "|")
        let constructed = try Regex(#"\bColor\("#)
        let named = try Regex(#"Color\.(\#(names))\b"#)

        let (violations, stale) = try scan { text in
            text.firstMatch(of: constructed) != nil || text.firstMatch(of: named) != nil
        }

        #expect(
            violations.isEmpty,
            "Views must read colors from Theme, not build them:\n\(violations.joined(separator: "\n"))"
        )
        for entry in stale {
            Issue.record("exemption \(entry) no longer used — no line in the file carries it, so the entry lets nothing through and should go (018 Decisions 15 and 17)")
        }
    }

    @Test func noViewPassesASystemColorToAColorTakingModifier() throws {
        let names = Self.systemColorNames.joined(separator: "|")
        let modifiers = Self.colorTakingModifiers.joined(separator: "|")
        let shorthand = try Regex(#"(\#(modifiers))\(\s*\.(\#(names))\b"#)

        let (violations, stale) = try scan { $0.firstMatch(of: shorthand) != nil }

        #expect(
            violations.isEmpty,
            "Views must read colors from Theme, not use system colors:\n\(violations.joined(separator: "\n"))"
        )
        for entry in stale {
            Issue.record("exemption \(entry) no longer used — no line in the file carries it, so the entry lets nothing through and should go (018 Decisions 15 and 17)")
        }
    }

    /// Every view line `flags` reports, less the lines `systemLabelExemptions`
    /// lets through: a flagged line passes only if it is clean once its
    /// file's exempted texts are taken out of it, so an exempted text never
    /// carries another colour through on the same line. `stale` is every
    /// entry this scan would itself flag (the entry's text trips `flags`)
    /// that no flagged line in its file carried — the other scan is
    /// responsible for the rest.
    private func scan(flags: (String) -> Bool) throws -> (violations: [String], stale: [String]) {
        var violations: [String] = []
        var used: Set<String> = []
        for file in try swiftFilesToCheck() {
            let name = file.lastPathComponent
            let exemptions = Self.systemLabelExemptions[name] ?? []
            let source = try String(contentsOf: file, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let text = String(line)
                guard flags(text) else { continue }
                var rest = text
                for entry in exemptions where rest.contains(entry) {
                    rest = rest.replacing(entry, with: "")
                    used.insert("\(name): \(entry)")
                }
                if flags(rest) {
                    violations.append("\(name):\(offset + 1): \(text.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        let stale = Self.systemLabelExemptions.keys.sorted().flatMap { name in
            (Self.systemLabelExemptions[name] ?? [])
                .filter { flags($0) }
                .map { "\(name): \($0)" }
                .filter { !used.contains($0) }
        }
        return (violations, stale)
    }
}
