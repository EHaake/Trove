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
    }

    /// tokens.md is explicit that the text-safe lifts are an accessibility fix,
    /// not decoration, and must not be collapsed into one value per accent.
    @Test func textSafeAccentLiftsAreDistinctFromTheirShapeColors() {
        #expect(colors.accentMossText != colors.accentMoss)
        #expect(colors.accentRustText != colors.accentRust)
    }
}

/// plan.md claims colors are "never hardcoded per-view" and that swapping the
/// active `Theme` is all a future light mode needs. That claim is only true
/// while it stays true, and it degrades the moment one view reaches for a
/// literal — so it gets checked rather than asserted, per CLAUDE.md.
@Suite("No hardcoded colors in views")
struct NoHardcodedColorsTests {
    /// `Color.clear` is absence of color rather than a palette choice, so it's
    /// allowed; everything else on this list is a real violation.
    private static let systemColorNames = [
        "red", "blue", "green", "yellow", "orange", "purple", "pink", "brown",
        "gray", "grey", "black", "white", "cyan", "mint", "teal", "indigo",
        "primary", "secondary", "accentColor",
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

        var violations: [String] = []
        for file in try swiftFilesToCheck() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let text = String(line)
                if text.firstMatch(of: constructed) != nil || text.firstMatch(of: named) != nil {
                    violations.append("\(file.lastPathComponent):\(offset + 1): \(text.trimmingCharacters(in: .whitespaces))")
                }
            }
        }

        #expect(
            violations.isEmpty,
            "Views must read colors from Theme, not build them:\n\(violations.joined(separator: "\n"))"
        )
    }

    @Test func noViewPassesASystemColorToAColorTakingModifier() throws {
        let names = Self.systemColorNames.joined(separator: "|")
        let modifiers = Self.colorTakingModifiers.joined(separator: "|")
        let shorthand = try Regex(#"(\#(modifiers))\(\s*\.(\#(names))\b"#)

        var violations: [String] = []
        for file in try swiftFilesToCheck() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let text = String(line)
                if text.firstMatch(of: shorthand) != nil {
                    violations.append("\(file.lastPathComponent):\(offset + 1): \(text.trimmingCharacters(in: .whitespaces))")
                }
            }
        }

        #expect(
            violations.isEmpty,
            "Views must read colors from Theme, not use system colors:\n\(violations.joined(separator: "\n"))"
        )
    }
}
