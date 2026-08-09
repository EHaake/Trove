import SwiftData
import SwiftUI

/// Placeholder shell, replaced by the real root `TabView` in T042.
///
/// Until then it doubles as a live harness for whichever Phase 4 component was
/// built last, so each one can be checked against `design/screens/` on a real
/// device rather than only in a preview.
struct ContentView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    @State private var categoryPath = ""
    @State private var suggestions: [String] = []
    @State private var photos: [Photo] = []

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: theme.metrics.sectionGap) {
                Text("Add item")
                    .font(theme.typography.screenTitle)
                    .foregroundStyle(theme.colors.textPrimary)

                CategoryPickerField(
                    suggestions: suggestions,
                    categoryPath: $categoryPath
                )

                PhotoPickerField(photos: $photos)

                Spacer()
            }
            .padding(theme.metrics.screenGutter)
        }
        .task { await seedAndLoadSuggestions() }
    }

    /// Seeds a handful of paths the first time through so the chip row has
    /// something to show. Harness-only; it goes away with this view at T042.
    private func seedAndLoadSuggestions() async {
        let helper = CategoryPathHelper(modelContext: modelContext)
        if (try? helper.allCategoryPaths())?.isEmpty ?? true {
            for path in [
                "Photography/Cameras",
                "Photography/Lenses",
                "Music/Guitars/Electric",
                "Music/Amps",
                "Audio/Headphones",
                "Accessories",
            ] {
                modelContext.insert(Item(name: "Sample", categoryPath: path))
            }
            try? modelContext.save()
        }
        suggestions = (try? helper.allCategoryPaths()) ?? []
    }
}

#Preview {
    ContentView()
        .environment(\.theme, .dark)
        .modelContainer(for: TroveSchema.models, inMemory: true)
}
