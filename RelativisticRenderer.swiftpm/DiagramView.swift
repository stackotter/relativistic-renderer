import SwiftUI

/// A 2d diagram of light bending around a blackhole. Allows the light source to be moved around and
/// the simulation to be configured (e.g. by changing granularity).
struct DiagramView: View {
    static var lineWidth: CGFloat { 2 }
    static var g: CGFloat { 1 }
    static var c: CGFloat { 1 }
    static var blackHolePosition: CGPoint { CGPoint(x: 26, y: 15) }

    @State var scale: CGFloat = 30
    @State var offset: CGPoint = CGPoint(x: Self.lineWidth, y: Self.lineWidth)
    @State var stepsMagnitude: CGFloat = 3
    @State var maxRevolutions = 3
    @State var precisePositioning = false
    
    @State var currentObserverPosition = CGPoint(x: 10, y: 15)
    @GestureState var observerDragDistance = CGSize.zero
    
    var steps: Int {
        Int(pow(10, stepsMagnitude))
    }
    
    var tab: Binding<ContentView.Tab>?
    
    var observerPosition: CGPoint {
        return currentObserverPosition + observerDragDistance
    }
    
    /// The radius within which nothing can escape, not even light. The chosen coordinate system
    /// means that this is simply 1 for our blackhole.
    static var schwarzschildRadius: CGFloat { 1 }
    
    var body: some View {
        NavigationSplitView {
            configPanel
        } detail: {
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        Diagram(scale: scale, offset: offset) { builder in
                            for i in 0...10 {
                                let radians = -CGFloat.pi / 4 * CGFloat(i) / 10 + .pi / 8
                                let velocity = CGPoint(x: Self.c * cos(radians), y: Self.c * sin(radians))
                                builder.addLine(Self.trajectory(
                                    initialPosition: observerPosition,
                                    initialVelocity: velocity,
                                    massPosition: Self.blackHolePosition,
                                    maxRevolutions: maxRevolutions,
                                    steps: steps
                                ))
                            }
                        }
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: Self.lineWidth))
                        
                        Diagram(scale: scale, offset: offset) { builder in
                            builder.addCircle(center: Self.blackHolePosition, radius: Self.schwarzschildRadius)
                        }
                        .stroke(Color.white, style: StrokeStyle(lineWidth: Self.lineWidth))
                    }
                }
                .contentShape(Rectangle())
                .background(Color.black)
                .clipped()
                .modifier(GestureModifier(offset: $offset, scale: $scale))
                
                flashlight
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Tab", selection: tab ?? Binding { ContentView.Tab._2d } set: { _ in }) {
                        Text("2d").tag(ContentView.Tab._2d)
                        Text("3d").tag(ContentView.Tab._3d)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(tab == nil)
                }
            }
        }
    }
    
    var configPanel: some View {
        List {
            Text("Max revolutions: \(maxRevolutions)")
            Slider(value: $maxRevolutions.into(), in: 1...10)
            
            Text("Steps: \(steps)")
            Slider(value: $stepsMagnitude, in: 0...4)
                .onChange(of: stepsMagnitude) { _ in
                    // Click the steps to logarithmic increments
                    stepsMagnitude = log10(CGFloat(steps))
                }
            
            Toggle("Precise positioning", isOn: $precisePositioning)
        }
    }
    
    var flashlight: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "flashlight.on.fill")
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(coordinateSpace: CoordinateSpace.global)
                            .map { value in
                                let sensitivity = precisePositioning ? 0.2 : 1
                                return value.translation / scale * sensitivity
                            }
                            .updating($observerDragDistance) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                currentObserverPosition += value
                            }
                    )
                    .rotationEffect(.radians(.pi / 2))
                    .scaleEffect(3)
                    .offset(x: -32, y: -10)
                    .offset(x: (observerPosition.x) * scale + offset.x, y: (observerPosition.y) * scale + offset.y)
                    .foregroundColor(.white)
                Spacer()
            }
            Spacer()
        }
    }
    
    static func trajectory(
        initialPosition: CGPoint,
        initialVelocity: CGPoint,
        massPosition: CGPoint,
        maxRevolutions: Int,
        steps: Int
    ) -> [CGPoint] {
        var points: [CGPoint] = [initialPosition]
        let polarPosition = (initialPosition - massPosition).polar

        var u = 1 / polarPosition.radius
        var xBasis = polarPosition.cartesian
        xBasis /= xBasis.magnitude
        var yBasis = CGPoint(x: -xBasis.y, y: xBasis.x)
        yBasis /= yBasis.magnitude
        let ray = initialVelocity / initialVelocity.magnitude
        if atan2(dot(ray, yBasis), dot(ray, xBasis)) < 0 {
            yBasis *= -1
        }
        var du = -dot(ray, xBasis) / dot(ray, yBasis) * u
        var phi: CGFloat = 0
        
        // Don't start ray tracing if we're inside the event horizon already
        if u > 1 / schwarzschildRadius {
            return points
        }
        
        var position: CGPoint = polarPosition.cartesian
        var previousPosition = position
        for i in 0..<steps {
            var step = CGFloat(maxRevolutions) * 2 * .pi / CGFloat(steps)
            
            // Prevents us from stepping across the event horizon
            if du > 0 {
                let maxStep = (1 / schwarzschildRadius - u) / du
                step = min(step, maxStep)
            }

            u += du * step
            let ddu = -u * (1 - 1.5 * u * u)
            du += ddu * step
            phi += step

            if u < 0 {
                // The ray has shot off to infinity, extend it an arbitrarily large amount and stop
                let step: CGFloat = 10000
                
                // If this condition is met on the first step, then it means the ray is basically
                // travelling directly away from the black hole's center of mass. That's useful
                // because on the first step we don't have a previous step to extrapolate from.
                let velocity = if i == 0 {
                    position
                } else {
                    position - previousPosition
                }
                
                points.append(position + velocity / velocity.magnitude * step + massPosition)
                break
            }

            previousPosition = position
            position = (xBasis * cos(phi) + yBasis * sin(phi)) / u
            points.append(position + massPosition)
            
            // Stop once we cross the event horizon
            if u > 1 / schwarzschildRadius {
                break
            }
        }
        
        return points
    }
}
