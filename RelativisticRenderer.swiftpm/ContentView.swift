import SwiftUI

struct ContentView: View {
    @State var tab = Tab._2d
    
    enum Tab: Hashable {
        case _2d
        case _3d
    }
    
    var body: some View {
        TabView(selection: $tab) {
            DiagramView()
                .tabItem {
                    Text("2d")
                }
                .tag(Tab._2d)
            
            RenderView()
                .tabItem {
                    Text("3d")
                }
                .tag(Tab._3d)
        }
    }
}
