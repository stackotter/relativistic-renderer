import MetalKit
import SwiftUI

struct MetalView<Coordinator: MetalViewCoordinator>: UIViewRepresentable {
    typealias UIViewType = MTKView
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        context.coordinator.configure(mtkView)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(with: uiView)
    }
}

protocol MetalViewCoordinator: MTKViewDelegate {
    init()
    func configure(_ view: MTKView)
    func update(with view: MTKView)
}
