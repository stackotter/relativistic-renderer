import SwiftUI

struct DiagramBuilder {
    var path: Path
    var scale: CGFloat
    var offset: CGPoint
    
    mutating func addLine(_ points: [CGPoint]) {
        guard let firstPoint = points.first else {
            return
        }
        let transformedPoint = firstPoint * scale + offset
        path.move(to: transformedPoint)
        for point in points[1...] {
            let transformedPoint = point * scale + offset
            // `Path` starts acting weird if points get too far out of frame (perhaps some sort of culling algorithm
            // gets confused.
            if transformedPoint.magnitude > 1000000 {
                break
            }
            path.addLine(to: transformedPoint)
        }
    }

    mutating func addCircle(center: CGPoint, radius: CGFloat) {
        path.move(to: (center + CGPoint(x: radius, y: 0)) * scale + offset)
        path.addArc(
            center: center * scale + offset,
            radius: radius * scale,
            startAngle: .zero,
            endAngle: .radians(2 * .pi),
            clockwise: true
        )
    }
}

// TODO: Implement precise positioning UI (so that users can position the observer more precisely
struct DiagramView: View {
    static let lineWidth: CGFloat = 2
    static let g: CGFloat = 1
    static let c: CGFloat = 1
    static let blackHolePosition = CGPoint(x: 30, y: 15)

    @State var scale: CGFloat = 30
    @State var offset: CGPoint = CGPoint(x: Self.lineWidth, y: Self.lineWidth)
    @State var timeStepMagnitude: CGFloat = 1
    @State var steps = 1000
    @State var blackHoleMass: CGFloat = 0.5
    
    @State var currentObserverPosition = CGPoint(x: 10, y: 15)
    @GestureState var observerDragDistance = CGSize.zero
    
    var timeStep: CGFloat {
        pow(10, timeStepMagnitude)
    }
    
    var observerPosition: CGPoint {
        return currentObserverPosition + observerDragDistance
    }
    
    /// The radius within which nothing can escape, not even light.
    var schwarzschildRadius: CGFloat {
        2 * Self.g * blackHoleMass / (Self.c * Self.c)
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Path { path in
                    var builder = DiagramBuilder(path: path, scale: scale, offset: offset)
                    for i in 0..<10 {
                        let radians = -CGFloat.pi / 4 * CGFloat(i) / 9 + .pi / 8
                        let velocity = CGPoint(x: Self.c * cos(radians), y: Self.c * sin(radians))
                        builder.addLine(Self.trajectory(
                            initialPosition: observerPosition,
                            initialVelocity: velocity,
                            massPosition: Self.blackHolePosition,
                            mass: blackHoleMass,
                            timeStep: timeStep,
                            steps: steps
                        ))
                        builder.addCircle(center: Self.blackHolePosition, radius: schwarzschildRadius)
                    }
                    path = builder.path
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: Self.lineWidth))
            }
            .contentShape(Rectangle())
            .background(Color(red: 21.0/255, green: 28.0/255, blue: 51.0/255))
            .clipped()
            .modifier(GestureModifier(offset: $offset, scale: $scale))
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "eye")
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
                        .offset(x: -20, y: -5)
                        .scaleEffect(2)
                        .offset(x: (observerPosition.x) * scale + offset.x, y: (observerPosition.y) * scale + offset.y)
                        .foregroundColor(.white)
                    Spacer()
                }
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Blackhole mass: \(blackHoleMass) (arbitrary units)")
                    Slider(value: $blackHoleMass, in: 0.01...100)
                    Text("Time step: \(timeStep)")
                    Slider(value: $timeStepMagnitude, in: -2...3)
                    Text("Steps: \(steps)")
                    Slider(value: $steps.into(), in: 1...10000)
                    Spacer()
                }
                .padding(16)
                .frame(width: 600)
                Spacer()
            }
        }
    }
    
    static func trajectory(
        initialPosition: CGPoint,
        initialVelocity: CGPoint,
        massPosition: CGPoint,
        mass: CGFloat,
        timeStep: CGFloat,
        steps: Int
    ) -> [CGPoint] {
        var points: [CGPoint] = [initialPosition]
        var polarPosition = (initialPosition - massPosition).polar

        let m = mass
        let schwarzschildRadius = 2 * g * mass / (c * c)
        var u = 1 / polarPosition.radius
        let u0 = u
        var xBasis = polarPosition.cartesian
        xBasis /= xBasis.magnitude
        var yBasis = CGPoint(x: -xBasis.y, y: xBasis.x)
        yBasis /= yBasis.magnitude
        let ray = initialVelocity / initialVelocity.magnitude
        if atan2(dot(ray, yBasis), dot(ray, xBasis)) < 0 {
            yBasis *= -1
        }
        var du = -dot(ray, xBasis) / dot(ray, yBasis) * u
        let du0 = du
        var phi: CGFloat = 0
        
        var position: CGPoint = polarPosition.cartesian
        var previousPosition = position
        for _ in 0..<steps {
            // TODO: Make this configurable
            let maxRevolutions: CGFloat = 10
            var step = maxRevolutions * 2 * .pi / CGFloat(steps)
            
            // Prevents us from stepping into the blackhole
            // TODO: Understand and customise this
            let maxUStepRatio = (1 - log(u)) * 10 / CGFloat(steps)
            if (du > 0 || (du0 < 0 && u0 / u < 5)) && abs(du) > abs(maxUStepRatio * u) / step {
                step = maxUStepRatio * u / abs(du)
            }

            // TODO: Update this differential equation to account for blackhole mass
            u += du * step
            let ddu = -u * (1 - 1.5 * u * u)
            du += ddu * step
            phi += step

            if u < 0 {
                // The ray has shot off to infinity, extend it an arbitrarily large amount and stop
                let step: CGFloat = 10000
                let velocity = position - previousPosition
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

public extension Binding where Value: BinaryInteger {
    func into<F: BinaryFloatingPoint>() -> Binding<F> {
        Binding<F>(
            get: { F(wrappedValue) },
            set: { wrappedValue = Value($0) }
        )
    }
}
