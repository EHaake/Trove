import SwiftUI
import UIKit

extension Image {
    /// Builds an `Image` from in-memory image data.
    ///
    /// **Flagged UIKit exception**, per CLAUDE.md: SwiftUI has no
    /// `Image(data:)` — `AsyncImage` takes a URL and `Image(_:bundle:)` takes
    /// an asset name, so decoding a `Photo.imageData` blob has to go through
    /// `UIImage`. Contained to this one initializer so nothing in the view
    /// layer imports UIKit itself.
    init?(imageData: Data) {
        guard let uiImage = UIImage(data: imageData) else { return nil }
        self.init(uiImage: uiImage)
    }
}
