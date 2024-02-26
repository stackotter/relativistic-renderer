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

struct Diagram: View {
    var scale: CGFloat
    var offset: CGPoint
    var buildDiagram: (inout DiagramBuilder) -> Void
    var color = Color.white
    var strokeStyle = StrokeStyle()
    
    var body: some View {
        Path { path in
            var builder = DiagramBuilder(path: path, scale: scale, offset: offset)
            buildDiagram(&builder)
            path = builder.path
        }
        .stroke(color, style: strokeStyle)
    }
    
    func stroke(_ color: Color, style: StrokeStyle) -> Self {
        var diagram = self
        diagram.color = color
        diagram.strokeStyle = style
        return diagram
    }
}
