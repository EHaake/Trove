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
}

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
