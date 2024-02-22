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

struct DiagramView: View {
    static let lineWidth: CGFloat = 2
    static let g: CGFloat = 1
    static let c: CGFloat = 1
    static let blackHolePosition = CGPoint(x: 700, y: 700)

    @State var scale: CGFloat = 1
    @State var offset: CGPoint = CGPoint(x: Self.lineWidth, y: Self.lineWidth)
    @State var timeStepMagnitude: CGFloat = 1
    @State var steps = 1000
    @State var blackHoleMass: CGFloat = 1
    
    @State var currentObserverPosition = CGPoint(x: 220, y: 500)
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
                        let radians = -CGFloat.pi / 4 * CGFloat(i) / 10 + .pi / 8
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

        let h = 0.00001
        let nudgedPosition = (initialPosition - massPosition + initialVelocity * h).polar
        var polarVelocity = PolarPoint(radius: (nudgedPosition.radius - polarPosition.radius) / h, theta: (nudgedPosition.theta - polarPosition.theta) / h)

        // We reference mass enough for it to make sense to have a shorter name locally
        let m = mass
        let schwarzschildRadius = 2 * g * m / (c * c)
        var t: CGFloat = 0
        for _ in 0..<steps {
            let r = polarPosition.radius
            let timeStep = timeStep * r / 100
            let christoffelRTT = g * m / (c * c * r * r) * (1 - 2 * g * m / (c * c * r))
            let christoffelRRR = -g * m / (c * c * r * r) / (1 - 2 * g * m / (c * c * r))
            let christoffelRThetaTheta = -r * (1 - 2 * g * m / (c * c * r))
            let christoffelThetaRTheta = 1 / r

            let dTdTau: CGFloat = 1
            let dRdTau = polarVelocity.radius
            let dThetaDTau = polarVelocity.theta

            let d2RdTau2 = -christoffelRRR * dRdTau * dRdTau - christoffelRTT * dTdTau * dTdTau - christoffelRThetaTheta * dThetaDTau * dThetaDTau
            let d2ThetaDTau2 = -christoffelThetaRTheta * dRdTau * dThetaDTau
            
            polarVelocity.radius += d2RdTau2 * timeStep
            polarVelocity.theta += d2ThetaDTau2 * timeStep
            
//            polarPosition.radius += polarVelocity.radius * timeStep
//            polarPosition.theta += polarVelocity.theta * timeStep
            
            let velocity = (
                PolarPoint(
                    radius: polarPosition.radius + polarVelocity.radius * h,
                    theta: polarPosition.theta + polarVelocity.theta * h
                ).cartesian
                -
                polarPosition.cartesian
            ) / h
            
            let newPosition = polarPosition.cartesian + velocity * timeStep
            // At this point the light ray can be considered sucked in (to avoid wasting time following it around the photon sphere forever)
            if newPosition.polar.radius < schwarzschildRadius * 1.01 {
                break
            }
            points.append(newPosition + massPosition)
            polarPosition = newPosition.polar
//            points.append(polarPosition.cartesian + massPosition)
            
            t += timeStep
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
