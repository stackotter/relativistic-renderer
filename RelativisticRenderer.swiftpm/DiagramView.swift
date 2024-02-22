import SwiftUI

struct DiagramBuilder {
    var path: Path
    var scale: CGFloat
    var offset: CGPoint
    
    mutating func addLine(_ points: [CGPoint]) {
        guard let firstPoint = points.first else {
            return
        }
        path.move(to: firstPoint * scale + offset)
        for point in points[1...] {
            path.addLine(to: point * scale + offset)
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

    @State var scale: CGFloat = 1
    @State var offset: CGPoint = CGPoint(x: Self.lineWidth, y: Self.lineWidth)
    @State var timeStepMagnitude: CGFloat = 1
    @State var steps = 1000
    
    var timeStep: CGFloat {
        pow(10, timeStepMagnitude)
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Path { path in
                    let massCenter = CGPoint(x: 500, y: 400)
                    var builder = DiagramBuilder(path: path, scale: scale, offset: offset)
                    builder.addLine(Self.points(timeStep: timeStep, steps: steps))
                    builder.addCircle(center: massCenter, radius: 2)
                    path = builder.path
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: Self.lineWidth))
            }
            .contentShape(Rectangle())
            .background(Color(red: 21.0/255, green: 28.0/255, blue: 51.0/255))
            .clipped()
            .modifier(GestureModifier(offset: $offset, scale: $scale))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Time step: \(timeStep)")
                    Slider(value: $timeStepMagnitude, in: -2...3)
                    Text("Steps: \(steps)")
                    Slider(value: $steps.into(), in: 1...10000)
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(width: 600)
                Spacer()
            }
        }
    }
    
    static func points(timeStep: CGFloat, steps: Int) -> [CGPoint] {
        let g: CGFloat = 1
        let m: CGFloat = 1
        let c: CGFloat = 1
        let initialPosition = CGPoint(x: 0, y: 100)
        let initialVelocity = CGPoint(x: c, y: 0)
        let massCenter = CGPoint(x: 500, y: 400)
        var points: [CGPoint] = [initialPosition]
        var polarPosition = (initialPosition - massCenter).polar

        let h = 0.00001
        let nudgedPosition = (initialPosition - massCenter + initialVelocity * h).polar
        var polarVelocity = PolarPoint(radius: (nudgedPosition.radius - polarPosition.radius) / h, theta: (nudgedPosition.theta - polarPosition.theta) / h)
        
        var t: CGFloat = 0
        for _ in 0..<steps {
            let r = polarPosition.radius
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
            
            let velocity = (
                PolarPoint(
                    radius: polarPosition.radius + polarVelocity.radius * h,
                    theta: polarPosition.theta + polarVelocity.theta * h
                ).cartesian
                -
                polarPosition.cartesian
            ) / h
            
//            polarPosition.radius += polarVelocity.radius * timeStep
//            polarPosition.theta += polarVelocity.theta * timeStep
            
            let newPosition = polarPosition.cartesian + velocity * timeStep
            points.append(newPosition + massCenter)
            polarPosition = newPosition.polar
            
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
