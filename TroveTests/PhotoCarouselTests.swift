import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Trove

/// Guards the two visual claims `PhotoCarousel` makes for a stock photo (spec
/// 005, plan §6): the credit line beneath the hero, and the Stock photo badge
/// over it — both only for a `.fetched` current photo, neither for a `.device`
/// one. Same instinct as `RowThumbnailTests`: a visual claim is still a claim,
/// so render the view and measure it rather than reading the source.
@MainActor
@Suite("Photo carousel — stock badge and credit")
struct PhotoCarouselTests {
    private let attribution = StockPhotoAttribution(
        author: "Ansel Adams",
        licenseName: "CC BY-SA 4.0",
        sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!
    )

    private static let renderWidth: CGFloat = 320

    private func carousel(_ photos: [Photo]) -> some View {
        PhotoCarousel(photos: photos, selectedIndex: .constant(0))
            .frame(width: Self.renderWidth)
    }

    private func fetchedPhoto() throws -> Photo {
        Photo.fetched(imageData: try makeWhitePNG(), attribution: attribution, sortOrder: 0)
    }

    private func devicePhoto() throws -> Photo {
        Photo(imageData: try makeWhitePNG(), source: .device)
    }

    // MARK: - The credit line (criterion 3)

    /// The credit adds a line beneath the hero, so a fetched carousel renders
    /// **taller** than an otherwise-identical device carousel. **Mutation
    /// target:** always show the credit → the device carousel grows too →
    /// heights match → red.
    @Test func theCreditShowsOnlyForAFetchedCurrentPhoto() throws {
        let fetched = try #require(renderBitmap(carousel([try fetchedPhoto()])))
        let device = try #require(renderBitmap(carousel([try devicePhoto()])))

        #expect(
            fetched.height > device.height,
            "the credit line didn't add height: fetched \(fetched.height), device \(device.height)"
        )
    }

    // MARK: - The badge (criterion 3)

    /// The badge draws its capsule — with light "STOCK PHOTO" text and glyph —
    /// over the top-left of a fetched hero, and nothing over a device hero. The
    /// hero itself renders dark under `ImageRenderer` (its pager image needs a
    /// scroll container it has no size for here), so the badge's light text is
    /// the signal: light pixels appear in the badge region for a fetched photo
    /// and none for a device photo. **Mutation target:** show the badge for a
    /// device photo → light pixels appear there too → red.
    @Test func theBadgeShowsOnlyForAFetchedCurrentPhoto() throws {
        let fetchedImage = try #require(renderBitmap(carousel([try fetchedPhoto()])))
        let deviceImage = try #require(renderBitmap(carousel([try devicePhoto()])))
        let fetched = try #require(Bitmap(fetchedImage))
        let device = try #require(Bitmap(deviceImage))

        #expect(lightPixelCount(in: fetched) > 0, "the badge left no light pixels over the fetched hero")
        #expect(lightPixelCount(in: device) == 0, "a badge (or other light chrome) appeared over the device hero")
    }

    /// The badge region: the top-leading corner of the hero, where the
    /// `top:12 left:12` capsule with its light label sits.
    private func lightPixelCount(in bitmap: Bitmap) -> Int {
        var count = 0
        for y in 14..<34 {
            for x in 14..<120 {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                if pixel.red > 150, pixel.green > 150, pixel.blue > 150 { count += 1 }
            }
        }
        return count
    }
}

/// A solid-white, decodable PNG — bright enough that the badge's dark capsule
/// reads unambiguously against it. Built with CoreGraphics/ImageIO rather than
/// `UIImage`, per CLAUDE.md's one-bridge rule (`RowThumbnailTests`' reasoning).
private func makeWhitePNG(side: Int = 32) throws -> Data {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8,
        bytesPerRow: side * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
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
