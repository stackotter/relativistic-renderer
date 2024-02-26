import SwiftUI

/// A 3d view of a blackhole with a configurable shader and environment. Allows the user to
/// move around via drag gestures.
struct RenderView: View {
    @State var error: String?
    @State var rendererConfig = RelativisticRenderer.Configuration.default
    @State var offset = CGPoint(x: 0, y: CGFloat.pi / 64 * 400)
    @State var scale: CGFloat = 1
    @State var distance: CGFloat = 8
    @State var minPhi: Float = -.pi / 2
    @State var steps: Int = 30
    @State var renderWithGravity = true
    
    var tab: Binding<RootView.Tab>?
    
    var resources: RelativisticRenderer.Resources
    
    func updateCamera() {
        let radius = Float(distance)
        let phi = Float(-offset.y / 400)
        // `minPhi` is used to act as a 'tare' to limit the pitch to the range -90 degrees to 90 degrees.
        // This could be avoided by creating a new gesture recognizer that knows about this range limit,
        // but this is much simpler and allows us to reuse the same ugly UIKit code.
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
            NavigationSplitView {
                configPanel
            } detail: {
                MetalView(error: $error, configuration: rendererConfig) {
                    try RenderCoordinator<RelativisticRenderer>.create(with: resources)
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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Picker("Tab", selection: tab ?? Binding { RootView.Tab._3d } set: { _ in }) {
                            Text("2d").tag(RootView.Tab._2d)
                            Text("3d").tag(RootView.Tab._3d)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .disabled(tab == nil)
                    }
                }
            }
        }
    }
    
    var configPanel: some View {
        List {
            Section("Environment") {
                Picker(selection: $rendererConfig.background) {
                    Text("Star map")
                        .tag(Background.starMap.rawValue)
                    Text("Checker board")
                        .tag(Background.checkerBoard.rawValue)
                } label: {
                    Text("Background")
                }
            }
            
            Section("Accretion disk") {
                Toggle(isOn: $rendererConfig.renderAccretionDisk) {
                    Text("Render accretion disk")
                }
                
                ConfigSlider("Accretion disk start", value: $rendererConfig.accretionDiskStart, in: 1...10)
                    .onChange(of: rendererConfig.accretionDiskStart) { _ in
                        if rendererConfig.accretionDiskStart > rendererConfig.accretionDiskEnd {
                            rendererConfig.accretionDiskStart = rendererConfig.accretionDiskEnd
                        }
                    }
                    .disabled(!rendererConfig.renderAccretionDisk)
                
                ConfigSlider("Accretion disk end", value: $rendererConfig.accretionDiskEnd, in: 1...10)
                    .onChange(of: rendererConfig.accretionDiskEnd) { _ in
                        if rendererConfig.accretionDiskEnd < rendererConfig.accretionDiskStart {
                            rendererConfig.accretionDiskEnd = rendererConfig.accretionDiskStart
                        }
                    }
                    .disabled(!rendererConfig.renderAccretionDisk)
            }
            
            Section("Observer") {
                ConfigSlider("Distance from blackhole", value: $distance, in: 1...100)
            }
            
            Section("Raytracing") {
                Toggle("Gravity", isOn: $renderWithGravity)
                    .onChange(of: renderWithGravity) { _ in
                        if renderWithGravity {
                            rendererConfig.stepCount = Int32(steps)
                        } else {
                            rendererConfig.stepCount = 0
                        }
                    }
                Text("Steps: \(steps)")
                Slider(
                    value: Binding {
                        log10(CGFloat(rendererConfig.stepCount))
                    } set: { newValue in
                        rendererConfig.stepCount = Int32(pow(10, newValue))
                        steps = Int(rendererConfig.stepCount)
                    },
                    in: 0...3
                )
                    .disabled(!renderWithGravity)
                ConfigSlider("Max revolutions", value: $rendererConfig.maxRevolutions.into(), in: 1...10)
                    .disabled(!renderWithGravity)
            }
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
