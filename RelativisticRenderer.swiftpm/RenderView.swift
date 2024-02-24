import SwiftUI

struct RenderView: View {
    @State var error: String?
    @State var rendererConfig = RelativisticRenderer.Configuration.default
    @State var offset: CGPoint = .zero
    @State var scale: CGFloat = 1
    
    var body: some View {
        if let error {
            Text(error)
                .font(.system(size: 12).monospaced())
        } else {
            ZStack {
                MetalView(error: $error, configuration: rendererConfig) {
                    try RenderCoordinator<RelativisticRenderer>.create()
                }
                .overlay(GestureCatcher(offset: $offset, scale: $scale))
                .onChange(of: scale) { newValue in
                    rendererConfig.cameraPosition.z = -20 / Float(newValue)
                }
                .onChange(of: offset) { newValue in
                    rendererConfig.cameraPosition.y = -1 - Float(offset.y) / 25
                }
                
                ConfigOverlay {
                    Toggle(isOn: $rendererConfig.renderAccretionDisk) {
                        Text("Render accretion disk")
                    }
                    
                    HStack {
                        Text("Background")
                        Picker(selection: $rendererConfig.background) {
                            Text("Star map")
                                .tag(Background.starMap)
                            Text("Checker board")
                                .tag(Background.checkerBoard)
                        } label: {
                            Text("Background")
                        }
                    }
                    
                    Text("Step count: \(rendererConfig.stepCount)")
                    Slider(value: $rendererConfig.stepCount.into(), in: 1...1000)
                    
                    Text("Max revolutions: \(rendererConfig.maxRevolutions)")
                    Slider(value: $rendererConfig.maxRevolutions.into(), in: 1...10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
