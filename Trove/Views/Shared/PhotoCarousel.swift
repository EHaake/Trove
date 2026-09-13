import SwiftUI

/// The detail screens' hero photo pager. Shows a placeholder when there are
/// no photos — plenty of records won't have any, since photos are optional
/// at creation.
///
/// The thumbnail strip and the "ITEM PHOTO 1 / 2" caption that used to
/// accompany the hero were removed at the T038 device review (2026-08-30):
/// once the pager tracked the finger and carried dots, both were a second
/// way of saying what the dots already say — and the strip only ever
/// appeared on the item detail, so removing it is also what makes the two
/// detail screens match.
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

    /// What VoiceOver calls the thing being pictured — "Item photos"
    /// against "Wishlist photos". Only the wording differs.
    var noun: String = "Item"

    @Environment(\.theme) private var theme

    private var safeIndex: Int { min(max(selectedIndex, 0), max(photos.count - 1, 0)) }

    /// The photo the pager is settled on, or nil when the set is empty — what
    /// the badge and credit are decided from (a stock photo shows both, an
    /// owned photo neither).
    private var currentPhoto: Photo? {
        photos.indices.contains(safeIndex) ? photos[safeIndex] : nil
    }

    /// The stock-photo badge's inset over the hero, `top:12 left:12` (the
    /// `ItemStockHero` artboards).
    private static let badgeInset = EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            hero
            // The credit sits beneath the hero, and only under a stock photo
            // (spec criterion 3). `attribution` is nil for a `.device` photo,
            // so the source check and the binding agree by construction.
            if currentPhoto?.source == .fetched, let attribution = currentPhoto?.attribution {
                StockPhotoCredit(attribution: attribution)
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
                // The Stock photo badge marks a fetched hero, never an owned
                // one (spec criterion 3). Hidden from VoiceOver here — the
                // combined element's value carries the announcement instead.
                .overlay(alignment: .topLeading) {
                    if currentPhoto?.source == .fetched {
                        StockPhotoBadge()
                            .padding(Self.badgeInset)
                            .accessibilityHidden(true)
                    }
                }

            if photos.isEmpty {
                Text("No photos")
                    .monoLabel(color: theme.colors.textQuiet)
                    .padding(theme.metrics.cardPadding)
            }
        }
        .accessibilityElement(children: .combine)
        // The removed caption was also the accessible position read-out;
        // the dots are visual-only, so the combined element carries it.
        .accessibilityLabel(photos.isEmpty ? "No photos" : "\(noun) photos")
        .accessibilityValue(accessibilityValueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            default: break
            }
        }
    }

    /// The combined hero's spoken value: the position, and — under a stock
    /// photo (spec criterion 11) — that it is a representative image and its
    /// credit, every stock word read from `StockPhotoCopy` rather than typed.
    private var accessibilityValueText: String {
        guard !photos.isEmpty else { return "" }
        var value = "Photo \(safeIndex + 1) of \(photos.count)"
        if currentPhoto?.source == .fetched, let attribution = currentPhoto?.attribution {
            value += ". " + StockPhotoCopy.badgeAccessibilityLabel
            value += ". " + StockPhotoCopy.credit(
                author: attribution.author, licenseName: attribution.licenseName)
        }
        return value
    }

    /// Swiping the hero is the gesture people try first; before `010` the
    /// thumbnails were the only way through a set. A paging `ScrollView`
    /// rather than a `TabView`: the plate and the dots are the hero's
    /// chrome and must hold still while only the photos move — a TabView
    /// would page all of it. Pages track the finger and rubber-band at
    /// both ends rather than wrapping, so the ends of the set are felt.
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

    /// One dot per photo, brass on the current one, unscrimmed on the
    /// photo's surface — since T038's review this is the hero's only
    /// position indicator.
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
        // The combined element's accessibility value announces the
        // position; the dots repeat it visually.
        .accessibilityHidden(true)
    }

    /// Moves one photo along, stopping at either end rather than wrapping.
    private func step(by delta: Int) {
        guard !photos.isEmpty else { return }
        let next = safeIndex + delta
        guard photos.indices.contains(next) else { return }
        withAnimation(.snappy(duration: 0.2)) { selectedIndex = next }
    }
}
