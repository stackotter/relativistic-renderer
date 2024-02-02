import SwiftUI

struct ContentView: View {
    @State var error: String?
    
    var body: some View {
        if let error {
            Text(error)
        } else {
            MetalView(error: $error) {
                try RenderCoordinator<RelativisticRenderer>.create()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
