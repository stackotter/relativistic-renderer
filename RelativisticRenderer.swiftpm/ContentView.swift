import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalView<RenderCoordinator>()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
