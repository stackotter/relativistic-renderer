import SwiftUI

struct RootView: View {
    @State var tab = Tab._2d
    
    enum Tab: Hashable {
        case _2d
        case _3d
    }
    
    var body: some View {
        // Shaders are loaded upfront since they are compiled at runtime instead of compile time in
        // this playground
        Await(RelativisticRenderer.loadResources) {
            Text("Loading resources")
        } success: { resources in
            OnboardAndThen(resources: resources) {
                TabView(selection: $tab) {
                    DiagramView(tab: $tab)
                        .tabItem {
                            Text("2d")
                        }
                        .tag(Tab._2d)
                    
                    RenderView(tab: $tab, resources: resources)
                        .tabItem {
                            Text("3d")
                        }
                        .tag(Tab._3d)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        } failure: { error in
            Text("Failed to load resources: \(error.localizedDescription)")
        }
    }
}
