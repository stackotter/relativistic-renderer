import SwiftUI

class GestureCatcherView: UIView {
    var offset: CGPoint
    var offsetDifference: CGPoint = .zero
    let offsetChanged: (CGPoint) -> Void
    var scale: CGFloat
    var currentPinchScaleFactor: CGFloat = 1
    let scaleChanged: (CGFloat) -> Void
    
    init(
        currentOffset: CGPoint,
        currentScale: CGFloat,
        offsetChanged: @escaping (CGPoint) -> Void,
        scaleChanged: @escaping (CGFloat) -> Void
    ) {
        self.offset = currentOffset
        self.scale = currentScale
        self.offsetChanged = offsetChanged
        self.scaleChanged = scaleChanged
        super.init(frame: .zero)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(gesture:)))
        panGesture.cancelsTouchesInView = false
        addGestureRecognizer(panGesture)
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(gesture:)))
        pinchGesture.cancelsTouchesInView = false
        addGestureRecognizer(pinchGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    @objc private func pan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed, .ended:
            let translation = gesture.translation(in: self)
            offsetDifference = translation
            if gesture.state == .ended {
                offset += offsetDifference
                offsetDifference = .zero
            }
            offsetChanged(offset + offsetDifference)
        default:
            break
        }
    }
    
    @objc private func pinch(gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed, .ended:
            let previousScale = scale * currentPinchScaleFactor
            currentPinchScaleFactor = gesture.scale
            if gesture.state == .ended {
                scale *= currentPinchScaleFactor
                currentPinchScaleFactor = 1
            }
            let newScale = scale * currentPinchScaleFactor
            scaleChanged(newScale)
            
            let pinchLocation = gesture.location(in: self)
            let scaleCenter = pinchLocation - offset
            print(pinchLocation, offset, scaleCenter)
            
            offset -= scaleCenter * (newScale / previousScale - 1)
            offsetChanged(offset)
        default:
            break
        }
    }
}

struct GestureCatcher: UIViewRepresentable {
    @Binding var offset: CGPoint
    @Binding var scale: CGFloat
    
    func makeUIView(context: Context) -> GestureCatcherView {
        return GestureCatcherView(
            currentOffset: offset,
            currentScale: scale,
            offsetChanged: { value in
                offset = value
            },
            scaleChanged: { value in
                scale = value
            }
        )
    }
    
    func updateUIView(_ view: GestureCatcherView, context: Context) { }
}

struct GestureModifier: ViewModifier {
    @Binding var offset: CGPoint
    @Binding var scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(GestureCatcher(offset: $offset, scale: $scale))
    }
}
