import CoreGraphics

func /(_ lhs: CGPoint, _ rhs: CGFloat) -> CGPoint {
    return lhs * (1 / rhs)
}

func /=(_ lhs: inout CGPoint, _ rhs: CGFloat) {
    lhs = lhs / rhs
}

func +(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    var lhs = lhs
    lhs.x += rhs.x
    lhs.y += rhs.y
    return lhs
}

func +=(_ lhs: inout CGPoint, _ rhs: CGPoint) {
    lhs.x += rhs.x
    lhs.y += rhs.y
}

func -(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    return lhs + (-rhs)
}

func -=(_ lhs: inout CGPoint, _ rhs: CGPoint) {
    lhs += -rhs
}

prefix func -(_ point: CGPoint) -> CGPoint {
    return point * -1
}

func *(_ lhs: CGPoint, _ rhs: CGFloat) -> CGPoint {
    var lhs = lhs
    lhs.x *= rhs
    lhs.y *= rhs
    return lhs
}

func *=(_ lhs: inout CGPoint, _ rhs: CGFloat) {
    lhs.x *= rhs
    lhs.y *= rhs
}

protocol CGVector {
    var components: [CGFloat] { get }
}

extension CGVector {
    var magnitude: CGFloat {
        sqrt(
            components
                .map { $0 * $0 }
                .reduce(0, +)
        )
    }
}

extension CGPoint: CGVector {
    var components: [CGFloat] {
        [x, y]
    }
}

extension CGSize: CGVector {
    var components: [CGFloat] {
        [width, height]
    }
}

extension CGPoint {
    var polar: PolarPoint {
        PolarPoint(radius: magnitude, theta: atan2(y, x))
    }
}

struct PolarPoint {
    var radius: CGFloat
    var theta: CGFloat
    
    var cartesian: CGPoint {
        CGPoint(x: radius * cos(theta), y: radius * sin(theta))
    }
}
