import SwiftUI

/// Hero photo with the thumbnail strip beneath, as drawn on the item detail
/// mock. Shows a placeholder when there are no photos — plenty of records
/// won't have any, since photos are optional at creation.
///
/// Detail screens shrink the hero rather than reserving its full height, the
/// opposite of `RowThumbnail`'s fixed slot: a large empty rectangle dominates
/// a screen in a way a small one never dominates a row. plan.md keeps both
/// rules on the record so they don't get "unified" later.
///
/// Shared by `ItemDetailView` and `WishlistDetailView`. It lived inside the
/// former until the latter needed exactly the same thing.
struct PhotoCarousel: View {
    let photos: [Photo]
    @Binding var selectedIndex: Int

    /// What the captions call the thing being pictured — "Item photo 1 / 3"
    /// against "Wishlist photo 1 / 3". Only the wording differs.
    var noun: String = "Item"

    @Environment(\.theme) private var theme

    private var safeIndex: Int { min(max(selectedIndex, 0), max(photos.count - 1, 0)) }

    var body: some View {
        VStack(spacing: theme.metrics.listRowGap) {
            hero
            if photos.count > 1 {
                strip
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photo = photos[safe: safeIndex], let image = Image(imageData: photo.imageData) {
                    image.resizable().scaledToFill()
                } else {
                    theme.colors.surfaceInset
                }
            }
            // A full-height hero is worth the space when there's a photo in
            // it; empty, it's just a large grey rectangle. Photos are optional
            // at creation, so plenty of items sit in the shorter state.
            .frame(height: photos.isEmpty ? 108 : 240)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
            // A photo is a card like any other (`010`'s review): the plate
            // sits behind it, so an opaque image hides the bevel and only
            // the cast shadow reads — which is the whole point of it here.
            .extrudedPlate()

            Text(photos.isEmpty ? "No photos" : "\(noun) photo \(safeIndex + 1) / \(photos.count)")
                .monoLabel(color: theme.colors.textQuiet)
                .padding(theme.metrics.cardPadding)
        }
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.metrics.listRowGap) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button {
                        selectedIndex = index
                    } label: {
                        Group {
                            if let image = Image(imageData: photo.imageData) {
                                image.resizable().scaledToFill()
                            } else {
                                theme.colors.surfaceInset
                            }
                        }
                        .frame(width: 80, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius)
                                .strokeBorder(
                                    index == safeIndex ? theme.colors.accentBrass : theme.colors.divider,
                                    lineWidth: theme.metrics.hairline
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Photo \(index + 1)")
                    .accessibilityAddTraits(index == safeIndex ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
