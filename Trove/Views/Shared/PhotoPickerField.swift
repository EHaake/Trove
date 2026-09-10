import PhotosUI
import SwiftUI

/// Multi-photo selection from the user's own library, shown as the thumbnail
/// strip plus dashed add-tile from `design/screens/Trove Item Detail.png`.
///
/// This field only ever *adds* device photos — every `Photo` it makes is
/// `.device`. An item may already hold a fetched stock photo (spec 005), and
/// adding a device photo to such an item asks the person whether to replace the
/// stock photo or keep both (Decision 4a); the field never fetches a stock
/// photo itself — that is the separate Find a photo… sheet the host presents.
struct PhotoPickerField: View {
    var label: String = "Photos"
    @Binding var photos: [Photo]

    @Environment(\.theme) private var theme
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var unreadableCount = 0
    /// The picked device bytes held while the replace/keep prompt is up, since
    /// the alert's buttons decide what to do with them (Decision 4a).
    @State private var pendingDeviceData: [Data] = []
    @State private var isPromptingReplaceKeep = false

    /// Derived from Design's thumbnail strip: four tiles across the content
    /// width at roughly 10:7. tokens.md gives the corner radius but not the
    /// tile size, so this is measured rather than specified.
    private let thumbnailSize = CGSize(width: 80, height: 56)

    private var orderedPhotos: [Photo] { PhotoSelection.inDisplayOrder(photos) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            HStack {
                Text(label).monoLabel()
                Spacer()
                if !photos.isEmpty {
                    Text("\(photos.count)").monoLabel(color: theme.colors.textQuiet)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.metrics.listRowGap) {
                    ForEach(orderedPhotos, id: \.id, content: thumbnail)
                    addTile
                }
                // Room for the remove buttons, which sit proud of the tiles.
                .padding(.top, 6)
                .padding(.trailing, 6)
            }

            statusLine
        }
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
        // Adding a device photo to an item that already holds a stock photo
        // asks first (Decision 4a). SwiftUI shows a two-button alert's title as
        // its message, and the spec pins only the question, so no separate
        // message is drawn. There is no Cancel — the spec pins only the two
        // choices. Keep both leads with the owned photo; Replace is destructive.
        .alert(
            StockPhotoCopy.replaceKeepMessage,
            isPresented: $isPromptingReplaceKeep
        ) {
            Button(StockPhotoCopy.keepBoth) {
                photos = PhotoSelection.addingKeepingStock(pendingDeviceData, to: photos)
                pendingDeviceData = []
            }
            Button(StockPhotoCopy.replace, role: .destructive) {
                photos = PhotoSelection.addingReplacingStock(pendingDeviceData, to: photos)
                pendingDeviceData = []
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if isLoading {
            Text("Adding photos…")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.textQuiet)
        } else if unreadableCount > 0 {
            Text(unreadableCount == 1
                 ? "One photo couldn't be read."
                 : "\(unreadableCount) photos couldn't be read.")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.accentRustText)
        }
    }

    private func thumbnail(_ photo: Photo) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = Image(imageData: photo.imageData) {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    // A photo whose data won't decode still occupies its slot,
                    // so the strip doesn't silently renumber around it.
                    theme.colors.surfaceInset
                }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipShape(RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.thumbnailRadius)
                    .strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
            )

            removeButton(for: photo)
                .offset(x: 6, y: -6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo \(photo.sortOrder + 1) of \(photos.count)")
    }

    private func removeButton(for photo: Photo) -> some View {
        Button {
            photos = PhotoSelection.removing(photo, from: photos)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(theme.colors.background))
                .overlay(
                    Circle().strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove photo")
    }

    private var addTile: some View {
        // `PhotosPicker`'s label builder is `@Sendable`, so reading the
        // MainActor-isolated `theme` inside it warns. Read the four values
        // here, on the main actor, and let the closure capture plain
        // `Sendable` colours and lengths instead — the alternative is
        // annotating around a shared component, which is a bigger change than
        // the problem.
        let plusColor = theme.colors.textLabel
        let borderColor = theme.colors.divider
        let radius = theme.metrics.thumbnailRadius
        let hairline = theme.metrics.hairline

        return PhotosPicker(
            selection: $pickerItems,
            selectionBehavior: .ordered,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(plusColor)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(
                            borderColor,
                            style: StrokeStyle(lineWidth: hairline, dash: [4, 3])
                        )
                )
        }
        .accessibilityLabel(photos.isEmpty ? "Add photos" : "Add more photos")
    }

    /// Each picker session adds to what's already there, rather than replacing
    /// it — `pickerItems` is cleared afterwards so the next session starts
    /// fresh instead of re-importing everything.
    private func load(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(data)
            }
        }

        unreadableCount = items.count - loaded.count
        if PhotoSelection.shouldPromptReplaceOrKeep(addingCount: loaded.count, to: photos) {
            // A stock photo is present: hold the bytes and ask whether to
            // replace it or keep both (Decision 4a) rather than appending.
            pendingDeviceData = loaded
            isPromptingReplaceKeep = true
        } else if !loaded.isEmpty {
            photos = PhotoSelection.appending(loaded, to: photos)
        }
        pickerItems = []
    }
}

#Preview {
    @Previewable @State var photos: [Photo] = []

    return ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        PhotoPickerField(photos: $photos)
            .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}
