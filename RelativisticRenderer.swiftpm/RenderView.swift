import SwiftUI

struct RenderView: View {
    @State var error: String?
    @State var rendererConfig = RelativisticRenderer.Configuration.default
    @State var offset = CGPoint(x: 0, y: CGFloat.pi / 64 * 400)
    @State var scale: CGFloat = 1
    @State var distance: CGFloat = 8
    @State var minPhi: Float = -.pi / 2
    
    func updateCamera() {
        let radius = Float(distance)
        let phi = Float(-offset.y / 400)
        // TODO: Make this more self explanatory
        minPhi = min(minPhi, phi)
        minPhi = max(minPhi, phi - .pi)
        let cameraPitch = phi - minPhi - .pi / 2
        let cameraYaw = Float(offset.x / 400)
        rendererConfig.cameraPosition.x = -radius * cos(cameraPitch) * sin(cameraYaw)
        rendererConfig.cameraPosition.y = -radius * sin(cameraPitch)
        rendererConfig.cameraPosition.z = -radius * cos(cameraPitch) * cos(cameraYaw)
        rendererConfig.cameraYaw = -cameraYaw
        rendererConfig.cameraPitch = -cameraPitch
    }
    
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
                .onChange(of: offset) { _ in
                    updateCamera()
                }
                .onChange(of: distance) { _ in
                    updateCamera()
                }
                .onAppear {
                    updateCamera()
                }
                
                ConfigOverlay {
                    HStack {
                        Text("Background")
                        Picker(selection: $rendererConfig.background) {
                            Text("Star map")
                                .tag(Background.starMap.rawValue)
                            Text("Checker board")
                                .tag(Background.checkerBoard.rawValue)
                        } label: {
                            Text("Background")
                        }
                    }
                    
                    Spacer().frame(height: 48)

                    Toggle(isOn: $rendererConfig.renderAccretionDisk) {
                        Text("Render accretion disk")
                    }

                    ConfigSlider("Accretion disk start", value: $rendererConfig.accretionDiskStart, in: 1...rendererConfig.accretionDiskEnd)
                        .disabled(!rendererConfig.renderAccretionDisk)

                    ConfigSlider("Accretion disk end", value: $rendererConfig.accretionDiskEnd, in: rendererConfig.accretionDiskStart...10)
                        .disabled(!rendererConfig.renderAccretionDisk)
                    
                    Spacer().frame(height: 48)

                    ConfigSlider("Distance", value: $distance, in: 1...100)
                    
                    Spacer().frame(height: 48)

                    ConfigSlider("Step count", value: $rendererConfig.stepCount.into(), in: 1...1000)
                    ConfigSlider("Max revolutions", value: $rendererConfig.maxRevolutions.into(), in: 1...10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ConfigSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    var label: String
    @Binding var value: Value
    var range: ClosedRange<Value>
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 1
        formatter.maximumSignificantDigits = 2
        return formatter.string(from: NSNumber(value: Double(value))) ?? "\(value)"
    }
    
    init(_ label: String, value: Binding<Value>, in range: ClosedRange<Value>) {
        self.label = label
        self._value = value
        self.range = range
    }
    
    var body: some View {
        Text("\(label): \(formattedValue)")
        Slider(value: $value, in: range)
    }
}
