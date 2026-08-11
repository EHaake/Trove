import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
@testable import Trove

/// A fresh in-memory store holding the real schema — real persistence
/// semantics, no disk, no CloudKit. Each call is an isolated store, so tests
/// can't leak state into one another.
func makeInMemoryContext() throws -> ModelContext {
    ModelContext(try makeInMemoryContainer())
}

/// The container behind `makeInMemoryContext()`, for tests that need a *second*
/// context over the same store.
///
/// Worth having because a same-context refetch is not a persistence check:
/// `ModelContext.fetch` returns objects carrying unsaved changes, so a test
/// that toggles something and refetches passes whether or not `save()` was
/// called. Mutation testing caught exactly that in the Sell Plan's
/// "persists on every change" tests — they read as persistence checks and
/// weren't. A second context sees only what actually reached the store.
func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: TroveSchema.schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: TroveSchema.schema, configurations: configuration)
}

/// The perceptual colour model the design-correctness tests measure against.
///
/// Oklab: a space built so equal steps look like equal steps, which HSV hue
/// degrees emphatically are not — the reason "the hues are evenly spaced" was a
/// misleading way to check the dial's ramp in the first place. ΔE here is plain
/// Euclidean distance in (L, a, b).
///
/// Shared rather than duplicated per suite: the dial checks palette tokens and
/// the gauge checks pixels sampled off a rendered view, and two copies of this
/// matrix drifting apart would make the two sets of thresholds incomparable.
enum Perceptual {
    /// ΔE between two palette colours.
    static func distance(_ first: Color, _ second: Color) -> Double {
        distance(oklab(first), oklab(second))
    }

    /// ΔE between two sampled pixels.
    static func distance(_ first: RGB8, _ second: RGB8) -> Double {
        distance(oklab(first), oklab(second))
    }

    /// ΔE between a sampled pixel and the palette colour it should have come
    /// from — how a render is checked against its own tokens.
    static func distance(_ pixel: RGB8, _ color: Color) -> Double {
        distance(oklab(pixel), oklab(color))
    }

    static func oklab(_ color: Color) -> (Double, Double, Double) {
        // `Color.Resolved` exposes the linearised channels directly, which is
        // exactly what the matrix below wants — no gamma maths to get wrong.
        let resolved = color.resolve(in: EnvironmentValues())
        return oklab(
            linearRed: Double(resolved.linearRed),
            linearGreen: Double(resolved.linearGreen),
            linearBlue: Double(resolved.linearBlue)
        )
    }

    /// Sampled pixels arrive as sRGB bytes, so they need linearising by hand
    /// before the same matrix applies.
    static func oklab(_ pixel: RGB8) -> (Double, Double, Double) {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return oklab(
            linearRed: linear(pixel.red),
            linearGreen: linear(pixel.green),
            linearBlue: linear(pixel.blue)
        )
    }

    private static func oklab(
        linearRed r: Double,
        linearGreen g: Double,
        linearBlue b: Double
    ) -> (Double, Double, Double) {
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

        return (
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    private static func distance(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        sqrt(pow(a.0 - b.0, 2) + pow(a.1 - b.1, 2) + pow(a.2 - b.2, 2))
    }
}

/// One sampled pixel, as 8-bit sRGB.
struct RGB8: Equatable, CustomStringConvertible {
    let red: Int
    let green: Int
    let blue: Int

    var description: String { String(format: "#%02X%02X%02X", red, green, blue) }
}

/// Renders a view at 1× and returns its bitmap.
///
/// `ImageRenderer` sizes content to its ideal size, which is what the layout
/// and colour tests are both asking about. The theme has to be supplied by hand
/// — there's no host app to inherit it from.
@MainActor
func renderBitmap(_ view: some View) -> CGImage? {
    let renderer = ImageRenderer(content: view.environment(\.theme, .dark))
    renderer.scale = 1
    return renderer.cgImage
}

/// Every pixel of a rendered image, in a known sRGB byte layout so individual
/// samples can be indexed by point coordinate.
struct Bitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        width = image.width
        height = image.height

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let raw = context.data else { return nil }

        let buffer = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)
        bytes = Array(UnsafeBufferPointer(start: buffer, count: width * height * 4))
    }

    /// The pixel at a point, or nil if it falls outside the image — a sample
    /// that silently clamped to an edge would measure the wrong thing.
    func pixel(at point: CGPoint) -> RGB8? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }

        let offset = (y * width + x) * 4
        return RGB8(
            red: Int(bytes[offset]),
            green: Int(bytes[offset + 1]),
            blue: Int(bytes[offset + 2])
        )
    }
}
