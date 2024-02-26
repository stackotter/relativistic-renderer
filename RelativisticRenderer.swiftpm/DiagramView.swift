import SwiftUI

// TODO: Implement precise positioning UI (so that users can position the observer more precisely
struct DiagramView: View {
    static let lineWidth: CGFloat = 2
    static let g: CGFloat = 1
    static let c: CGFloat = 1
    static let blackHolePosition = CGPoint(x: 26, y: 15)

    @State var scale: CGFloat = 30
    @State var offset: CGPoint = CGPoint(x: Self.lineWidth, y: Self.lineWidth)
    @State var steps = 1000
    @State var maxRevolutions = 3
    @State var blackHoleMass: CGFloat = 0.5
    
    @State var currentObserverPosition = CGPoint(x: 10, y: 15)
    @GestureState var observerDragDistance = CGSize.zero
    
    var observerPosition: CGPoint {
        return currentObserverPosition + observerDragDistance
    }
    
    /// The radius within which nothing can escape, not even light.
    var schwarzschildRadius: CGFloat {
        2 * Self.g * blackHoleMass / (Self.c * Self.c)
    }
    
    var body: some View {
        NavigationSplitView {
            List {
                Text("Max revolutions: \(maxRevolutions)")
                Slider(value: $maxRevolutions.into(), in: 1...10)
                
                Text("Steps: \(steps)")
                Slider(value: $steps.into(), in: 1...10000)
            }
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
                                    mass: blackHoleMass,
                                    maxRevolutions: maxRevolutions,
                                    steps: steps
                                ))
                            }
                        }
                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: Self.lineWidth))
                        
                        Diagram(scale: scale, offset: offset) { builder in
                            builder.addCircle(center: Self.blackHolePosition, radius: schwarzschildRadius)
                        }
                        .stroke(Color.white, style: StrokeStyle(lineWidth: Self.lineWidth))
                    }
                }
                .contentShape(Rectangle())
                .background(Color.black)
                .clipped()
                .modifier(GestureModifier(offset: $offset, scale: $scale))
                
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "flashlight.on.fill")
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(coordinateSpace: CoordinateSpace.global)
                                    .map { value in
                                        value.translation / scale
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
        }
    }
    
    static func trajectory(
        initialPosition: CGPoint,
        initialVelocity: CGPoint,
        massPosition: CGPoint,
        mass: CGFloat,
        maxRevolutions: Int,
        steps: Int
    ) -> [CGPoint] {
        var points: [CGPoint] = [initialPosition]
        let polarPosition = (initialPosition - massPosition).polar

        let schwarzschildRadius = 2 * g * mass / (c * c)
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
            let ddu = -u * (1 - 6 * mass * mass * u * u)
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
