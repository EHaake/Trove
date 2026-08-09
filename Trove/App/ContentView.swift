import SwiftData
import SwiftUI

/// Placeholder shell, replaced by the real root `TabView` in T042.
///
/// Until then it hosts whichever Phase 4 screen was built last, so each one
/// can be checked against `design/screens/` on a real device rather than only
/// in a preview.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ItemFormView(modelContext: modelContext)
        }
        .task { seedCategoriesIfNeeded() }
    }

    /// Gives the category picker something to autocomplete against on a fresh
    /// install. Harness-only; it goes away with this view at T042.
    private func seedCategoriesIfNeeded() {
        let helper = CategoryPathHelper(modelContext: modelContext)
        guard (try? helper.allCategoryPaths())?.isEmpty ?? true else { return }

        for path in [
            "Photography/Cameras",
            "Photography/Lenses",
            "Music/Guitars/Electric",
            "Music/Amps",
            "Audio/Headphones",
        ] {
            modelContext.insert(Item(name: "Sample", categoryPath: path))
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .environment(\.theme, .dark)
        .modelContainer(for: TroveSchema.models, inMemory: true)
}
