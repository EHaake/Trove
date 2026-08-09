import SwiftUI

/// Placeholder shell for the app. Replaced by the real root `TabView` in T042.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Trove")
                .font(.largeTitle.weight(.semibold))
            Text("Your Gear, Valued")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
