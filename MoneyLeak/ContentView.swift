import SwiftUI

/// Preview host for Xcode canvas. The app launches via `MoneyLeakApp`.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            ProcessListView(
                viewModel: ProcessListViewModel(settings: MemoryCostSettings()),
                showSettings: .constant(false)
            )
        }
    }
}

#Preview {
    ContentView()
}
