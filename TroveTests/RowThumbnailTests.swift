import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Trove

/// Guards the two claims `RowThumbnail` makes that a reader would otherwise
/// have to take on trust — plan.md states both as prose.
///
/// Same instinct as the CloudKit schema test and the desire dial's colour
/// guards: "every row keeps the same left edge whether or not it has a photo"
/// is a visual claim, and a visual claim is still a claim. Rendering the view
/// and measuring it is the check; reading the source and agreeing with it
/// isn't.
@Suite("Row thumbnail")
struct RowThumbnailTests {
    // MARK: - The reserved slot

    /// The standing rule for list-style screens: the slot is the same size
    /// with a photo and without, so a scroll has one left edge to read down.
    @Test func theSlotIsTheSameSizeWithAPhotoAndWithout() throws {
        let photo = Photo(imageData: try makePNGData(red: 0, green: 200, blue: 0))

        let empty = try renderedSize(RowThumbnail(photos: []))
        let filled = try renderedSize(RowThumbnail(photos: [photo]))

        #expect(empty == filled)
        // 52, tokens.md's `010` row treatment — the plate tightened the rows
        // and the slot with them (was 72).
        #expect(empty == CGSize(width: 52, height: 52))
    }

    /// A photo whose data won't decode falls back to the placeholder rather
    /// than collapsing — the same state as having no photo at all, which is
    /// the case a `if let image` written slightly differently would drop.
    @Test func anUndecodablePhotoStillOccupiesTheSlot() throws {
        let corrupt = Photo(imageData: Data([0xDE, 0xAD, 0xBE, 0xEF]))

        let size = try renderedSize(RowThumbnail(photos: [corrupt]))

        #expect(size == CGSize(width: 52, height: 52))
    }

    @Test(arguments: [44.0, 72.0, 96.0])
    func theSlotHonoursTheSideItWasGiven(side: Double) throws {
        let size = try renderedSize(RowThumbnail(photos: [], side: side))

        #expect(size == CGSize(width: side, height: side))
    }

    // MARK: - Which photo shows

    /// The thumbnail is the photo the user put first, not whichever the
    /// relationship handed back. SwiftData guarantees no ordering, so a row
    /// reading `photos.first` would show a different picture between launches
    /// — and would look right in every test that passed photos already sorted.
    ///
    /// So this passes them deliberately out of order: green is `sortOrder` 0
    /// but sits second in the array, red is `sortOrder` 1 and sits first.
    @Test func theThumbnailShowsTheFirstPhotoInTheUsersOrderNotTheArraysOrder() throws {
        let green = Photo(imageData: try makePNGData(red: 0, green: 200, blue: 0), sortOrder: 0)
        let red = Photo(imageData: try makePNGData(red: 200, green: 0, blue: 0), sortOrder: 1)

        let pixel = try centrePixel(of: try render(RowThumbnail(photos: [red, green])))

        #expect(pixel.green > 150, "Expected the sortOrder-0 photo; got \(pixel)")
        #expect(pixel.red < 100, "Expected the sortOrder-0 photo; got \(pixel)")
    }

    // MARK: - The stock mark (T011)

    /// A stock-only row draws the mark; an owned-leading row draws none, even
    /// when a stock photo trails (spec criterion 3, Decision 4a). Both rows
    /// render the same bright leading image, so the mark's dark ground is the
    /// only difference — found by locating the darkest pixel in the stock render
    /// (which must be the mark) and confirming that same spot is bright in the
    /// owned-leading render.
    ///
    /// **Mutation:** gate the overlay on `photos.contains { $0.source ==
    /// .fetched }` instead of `PhotoSelection.leadsWithStock` → the
    /// owned-leading corner goes dark → the `owned is bright` expectation red.
    @Test func theStockMarkRidesAStockLeadingRowButNotAnOwnedLeadingOne() throws {
        let brightPNG = try makePNGData(red: 255, green: 255, blue: 255)

        let stockOnly = [
            Photo.fetched(imageData: brightPNG, attribution: stockAttribution, sortOrder: 0)
        ]
        // Owned leads (sortOrder 0), stock trails (sortOrder 1) — passed out of
        // array order so the predicate must sort by sortOrder, not position.
        let ownedLeading = [
            Photo.fetched(imageData: brightPNG, attribution: stockAttribution, sortOrder: 1),
            Photo(imageData: brightPNG, source: .device, sortOrder: 0),
        ]

        let stockImage = try render(RowThumbnail(photos: stockOnly))
        let ownedImage = try render(RowThumbnail(photos: ownedLeading))

        // The darkest pixel of the stock render is the mark's ground.
        let mark = try darkestPixel(of: stockImage)
        #expect(mark.brightness < 350, "Expected the stock mark's dark ground; got \(mark)")

        // The same location in the owned-leading render is the bright image —
        // no mark there, because an owned photo leads.
        let ownedAtMark = try pixel(of: ownedImage, x: mark.x, y: mark.y)
        #expect(ownedAtMark.red + ownedAtMark.green + ownedAtMark.blue > 600,
                "Expected the bright leading image (no mark); got \(ownedAtMark)")
    }
}

/// A stock attribution for building `.fetched` photos in these tests.
private let stockAttribution = StockPhotoAttribution(
    author: "A",
    licenseName: "CC BY-SA 4.0",
    sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:A.jpg")!
)

// MARK: - Rendering helpers

/// Renders a view at 1× and returns its bitmap.
///
/// `ImageRenderer` sizes content to its ideal size, which is exactly what
/// these tests are asking about. The theme has to be supplied by hand — there
/// is no host app to inherit it from.
private func render(_ view: some View) throws -> CGImage {
    let renderer = ImageRenderer(content: view.environment(\.theme, .dark))
    renderer.scale = 1
    return try #require(renderer.cgImage, "ImageRenderer produced nothing to measure.")
}

private func renderedSize(_ view: some View) throws -> CGSize {
    let image = try render(view)
    return CGSize(width: image.width, height: image.height)
}

/// A real, decodable PNG in a solid colour.
///
/// Built with CoreGraphics and ImageIO rather than `UIImage`: per CLAUDE.md the
/// one sanctioned UIKit bridge is `Image(imageData:)` in the app target, and a
/// test reaching for `UIImage` to *make* its fixture would quietly add a
/// second.
private func makePNGData(red: Int, green: Int, blue: Int, side: Int = 8) throws -> Data {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: side * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(
        red: CGFloat(red) / 255,
        green: CGFloat(green) / 255,
        blue: CGFloat(blue) / 255,
        alpha: 1
    )
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    let image = try #require(context.makeImage())

    let output = NSMutableData()
    let destination = try #require(
        CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return output as Data
}

/// Reads every pixel into a raw RGBA buffer, running `body` with a sampler
/// closure. Coordinates are (x, y) from the buffer's own origin — the flip
/// between Quartz and buffer memory doesn't matter here, because callers compare
/// the *same* buffer coordinate across two renders.
private func withPixels(
    of image: CGImage,
    _ body: (_ width: Int, _ height: Int, _ sample: (Int, Int) -> (red: Int, green: Int, blue: Int)) throws -> Void
) throws {
    let width = image.width
    let height = image.height
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let raw = try #require(context.data)
    let bytes = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)
    try body(width, height) { x, y in
        let offset = (y * width + x) * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }
}

/// The location and brightness of the darkest pixel in the image.
private func darkestPixel(of image: CGImage) throws -> (x: Int, y: Int, brightness: Int) {
    var best = (x: 0, y: 0, brightness: Int.max)
    try withPixels(of: image) { width, height, sample in
        for y in 0..<height {
            for x in 0..<width {
                let p = sample(x, y)
                let brightness = p.red + p.green + p.blue
                if brightness < best.brightness {
                    best = (x, y, brightness)
                }
            }
        }
    }
    return best
}

/// The pixel at a specific buffer coordinate.
private func pixel(of image: CGImage, x: Int, y: Int) throws -> (red: Int, green: Int, blue: Int) {
    var result = (red: 0, green: 0, blue: 0)
    try withPixels(of: image) { _, _, sample in
        result = sample(x, y)
    }
    return result
}

private func centrePixel(of image: CGImage) throws -> (red: Int, green: Int, blue: Int) {
    let width = image.width
    let height = image.height
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    let raw = try #require(context.data)
    let bytes = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)
    let offset = ((height / 2) * width + (width / 2)) * 4
    return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
}
