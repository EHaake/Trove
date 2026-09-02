import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The render oracle for 013 Amendment A's refactor (T018/T019): the Sort By
/// dropdown is about to be re-composed on a shared `DropdownSurface` and
/// `DropdownRow`, and criterion 24 says it must be "unchanged to the eye".
/// That is a pixel claim, so it gets a pixel test rather than a sentence.
///
/// `LegacySortDropdown` below is 010's drawing — today's `SortDropdown`,
/// copied verbatim, private glyph and header included — frozen as the
/// oracle. Old and new are rendered in the same process and the same run,
/// so renderer, OS and font-rasterisation drift cancel out, and the
/// comparison is exact: a tolerance would erase precisely the one-point
/// shift this test exists to catch.
///
/// Lifetime: this file lands at T018 while it is trivially green (both
/// views are the same code), guards T019's refactor, and is **deleted at
/// T019's close-out** with its red-run recorded — after T019 the drawing
/// lives once, and a frozen copy would be a second encoding of it.
///
/// Scope: the surface's drawing, not its position on screen.
@Suite("Sort dropdown render oracle")
struct SortDropdownRenderTests {
    typealias SortOrder = ItemListViewModel.SortOrder

    /// Two states: the manual-order row selected (tinted, checked, and the
    /// REORDER tag), and a plain row selected (tinted and checked, no tag).
    private nonisolated static let states: [SortOrder] = [.custom, .currentValue]

    @Test(arguments: states)
    func theRecomposedDropdownRendersExactlyAsTheLegacyOne(selection: SortOrder) throws {
        let legacy = try bitmap(of: legacyDropdown(selection: selection))
        let production = try bitmap(of: productionDropdown(selection: selection))

        // Dimensions first: `Bitmap.pixel(at:)` returns nil outside bounds,
        // so a size change compared pixel-by-pixel over the smaller image
        // could pass on its overlap.
        try #require(
            legacy.width == production.width && legacy.height == production.height,
            "Size drifted: legacy \(legacy.width)×\(legacy.height), production \(production.width)×\(production.height)"
        )

        let mismatch = firstMismatch(legacy, production)
        #expect(
            mismatch == nil,
            "First differing pixel at \(mismatch.map { "(\($0.x), \($0.y)): legacy \($0.legacy), production \($0.production)" } ?? "-")"
        )
    }

    /// The oracle is only as good as the renderer's repeatability: if two
    /// renders of the same view differ, an equality failure above would
    /// mean nothing.
    @Test(arguments: states)
    func renderingTheSameViewTwiceGivesTheSameBitmap(selection: SortOrder) throws {
        let first = try bitmap(of: productionDropdown(selection: selection))
        let second = try bitmap(of: productionDropdown(selection: selection))

        try #require(first.width == second.width && first.height == second.height)
        let mismatch = firstMismatch(first, second)
        #expect(
            mismatch == nil,
            "Non-deterministic render at \(mismatch.map { "(\($0.x), \($0.y))" } ?? "-")"
        )
    }

    // MARK: - Subjects

    private func productionDropdown(selection: SortOrder) -> some View {
        SortDropdown(
            options: SortOrder.allCases,
            selection: selection,
            label: \.label,
            isManualOrder: { $0 == .custom },
            onSelect: { _ in }
        )
    }

    private func legacyDropdown(selection: SortOrder) -> some View {
        LegacySortDropdown(
            options: SortOrder.allCases,
            selection: selection,
            label: \.label,
            isManualOrder: { $0 == .custom },
            onSelect: { _ in }
        )
    }

    // MARK: - Comparison

    private func bitmap(of view: some View) throws -> Bitmap {
        let image = try #require(renderBitmap(view), "ImageRenderer produced nothing to compare.")
        return try #require(Bitmap(image), "Couldn't read the rendered pixels.")
    }

    private struct Mismatch {
        let x: Int
        let y: Int
        let legacy: RGB8
        let production: RGB8
    }

    /// Walks every pixel and reports the first that differs, with both
    /// values — a count alone says "different", a coordinate says where.
    private func firstMismatch(_ a: Bitmap, _ b: Bitmap) -> Mismatch? {
        for y in 0..<a.height {
            for x in 0..<a.width {
                let point = CGPoint(x: x, y: y)
                guard let pa = a.pixel(at: point), let pb = b.pixel(at: point) else { continue }
                if pa != pb {
                    return Mismatch(x: x, y: y, legacy: pa, production: pb)
                }
            }
        }
        return nil
    }
}

// MARK: - The frozen drawing

/// `SortDropdown` as it stood at `99747d5`, verbatim — the oracle. Do not
/// edit; a change here is a change to the reference, not to the app.
private struct LegacySortDropdown<Option: Identifiable & Equatable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    let isManualOrder: (Option) -> Bool
    let onSelect: (Option) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text("SORT BY")
                .font(ThemeTypography.font(.mono, size: 10))
                .tracking(1.6)
                .foregroundStyle(theme.colors.textQuiet)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 11, leading: 14, bottom: 9, trailing: 14))

            ForEach(options) { option in
                row(for: option)
            }
        }
        .frame(width: 232)
        .background { PlateSurface() }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                .strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
        )
    }

    private func row(for option: Option) -> some View {
        let isSelected = option == selection

        return Button {
            onSelect(option)
        } label: {
            HStack(spacing: 10) {
                Text(label(option))
                    .font(theme.typography.body)
                    .foregroundStyle(isSelected ? theme.colors.accentBrass : theme.colors.textBody)

                Spacer(minLength: 0)

                if isSelected {
                    if isManualOrder(option) {
                        Text("REORDER")
                            .font(ThemeTypography.font(.mono, size: 9.5))
                            .tracking(1.14)
                            .foregroundStyle(theme.colors.textQuiet)
                    }
                    LegacyCheckmarkGlyph()
                        .stroke(
                            theme.colors.accentBrass,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 12, height: 12)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(isSelected ? theme.colors.accentBrassTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            theme.colors.surfaceInset.frame(height: theme.metrics.hairline)
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct LegacyCheckmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.25))
        return path
    }
}
