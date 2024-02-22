import SwiftUI

struct ContentView: View {
    @State var error: String?
    @State var tab = Tab._2d
    
    enum Tab: Hashable {
        case _2d
        case _3d
    }
    
    var body: some View {
        if let error {
            Text(error)
                .font(.system(size: 12).monospaced())
        } else {
            TabView(selection: $tab) {
                DiagramView()
                    .tabItem {
                        Text("2d")
                    }
                    .tag(Tab._2d)

                MetalView(error: $error) {
                    try RenderCoordinator<RelativisticRenderer>.create()
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tabItem {
                        Text("3d")
                    }
                    .tag(Tab._3d)
            }
        }
    }
}
