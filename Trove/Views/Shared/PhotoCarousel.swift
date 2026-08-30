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

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            heroPager
                .frame(height: photos.isEmpty ? 108 : 240)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius))
                // A photo is a card like any other (`010`'s review): the plate
                // sits behind it, so an opaque image hides the bevel and only
                // the cast shadow reads — which is the whole point of it here.
                .extrudedPlate()
                .overlay(alignment: .bottom) {
                    if photos.count > 1 {
                        dots
                    }
                }

            Text(photos.isEmpty ? "No photos" : "\(noun) photo \(safeIndex + 1) / \(photos.count)")
                .monoLabel(color: theme.colors.textQuiet)
                .padding(theme.metrics.cardPadding)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            default: break
            }
        }
    }

    /// Swiping the hero is the gesture people try first; before `010` the
    /// thumbnails were the only way through a set. A paging `ScrollView`
    /// rather than a `TabView`: the caption, the plate, and the dots are the
    /// hero's chrome and must hold still while only the photos move — a
    /// TabView would page all of it. Pages track the finger and rubber-band
    /// at both ends, so there's no wrap, which agrees with the fixed strip
    /// below about where the set ends.
    @ViewBuilder
    private var heroPager: some View {
        if photos.isEmpty {
            theme.colors.surfaceInset
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        Group {
                            if let image = Image(imageData: photo.imageData) {
                                image.resizable().scaledToFill()
                            } else {
                                theme.colors.surfaceInset
                            }
                        }
                        .containerRelativeFrame(.horizontal)
                        .frame(height: 240)
                        // Each page clips itself — a filled landscape image
                        // is wider than its page and would lie over its
                        // neighbors mid-swipe otherwise.
                        .clipped()
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: scrolledIndex)
        }
    }

    /// Two-way bridge between the pager's settle position and the carousel's
    /// one selection state: a swipe writes through to `selectedIndex`, and a
    /// thumbnail tap (or VoiceOver step) writing `selectedIndex` scrolls the
    /// pager. One state, three controls.
    private var scrolledIndex: Binding<Int?> {
        Binding(
            get: { photos.isEmpty ? nil : safeIndex },
            set: { index in
                if let index { selectedIndex = index }
            }
        )
    }

    /// One dot per photo, brass on the current one — the same treatment the
    /// strip's selected thumbnail border uses, and unscrimmed like the
    /// caption that shares the photo's surface.
    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(photos.indices, id: \.self) { index in
                Circle()
                    .fill(index == safeIndex
                        ? theme.colors.accentBrass
                        : theme.colors.textPrimary.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 10)
        // The caption already announces "photo 1 / 3" for the combined
        // element; the dots repeat it visually.
        .accessibilityHidden(true)
    }

    /// Moves one photo along, stopping at either end rather than wrapping.
    private func step(by delta: Int) {
        guard !photos.isEmpty else { return }
        let next = safeIndex + delta
        guard photos.indices.contains(next) else { return }
        withAnimation(.snappy(duration: 0.2)) { selectedIndex = next }
    }

    // MARK: - Strip

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.metrics.listRowGap) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selectedIndex = index }
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
