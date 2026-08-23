import SwiftUI

/// The photo slot a list row reserves, whether or not there's a photo to put
/// in it.
///
/// Fixed size in both states, deliberately — plan.md makes this a standing
/// rule for list-style screens. A list where some rows carry a thumbnail and
/// others start straight at their text has no consistent left edge to read
/// down, so an empty slot draws a placeholder instead of collapsing.
///
/// Detail screens make the opposite call: `ItemDetailView`'s hero shrinks from
/// 240pt to 108pt rather than showing a placeholder, because the tradeoff
/// flips once the empty area is big enough to dominate the screen instead of
/// sitting quietly at the head of a row. Both are intentional; they aren't two
/// answers to the same question.
///
/// Shared by `ItemRow` and `WishlistView`'s row so the two can't drift.
struct RowThumbnail: View {
    let photos: [Photo]
    var side: CGFloat = 72

    @Environment(\.theme) private var theme

    /// The first photo in the user's own order, not whichever one the
    /// relationship happens to hand back — SwiftData guarantees no ordering,
    /// so reading `photos.first` directly would let a row's thumbnail change
    /// between launches.
    private var first: Photo? { PhotoSelection.inDisplayOrder(photos).first }

    var body: some View {
        Group {
            if let first, let image = Image(imageData: first.imageData) {
                image.resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius))
    }

    /// A flat glyph, per the brief's icon language — and an SF Symbol rather
    /// than a custom mark precisely because this should recede. It replaces
    /// the word "Photo" the item row used to show, which read as a label for
    /// something that wasn't there.
    ///
    /// Deliberately *not* the dashed outline `PhotoPickerField` draws for its
    /// add tile: dashes mean "tap to add" in this app, and a row's thumbnail
    /// isn't a control. Sized off `side` so it stays proportionate.
    private var placeholder: some View {
        ZStack {
            theme.colors.surfaceInset
            Image(systemName: "photo")
                .font(.system(size: side * 0.3, weight: .light))
                .foregroundStyle(theme.colors.textInactive)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        HStack(spacing: Theme.dark.metrics.listRowGap) {
            RowThumbnail(photos: [])
            RowThumbnail(photos: [], side: 44)
        }
    }
    .environment(\.theme, .dark)
}
