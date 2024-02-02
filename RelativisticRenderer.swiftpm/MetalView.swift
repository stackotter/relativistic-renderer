import MetalKit
import SwiftUI

struct MetalView<Coordinator: MetalViewCoordinator>: UIViewRepresentable {
    typealias UIViewType = MTKView
    
    @Binding var error: String?
    let createCoordinator: () throws -> Coordinator
    
    func makeCoordinator() -> Coordinator? {
        do {
            return try createCoordinator()
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to create render coordinator: \(error)"
            }
            return nil
        }
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        context.coordinator?.configure(mtkView)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

protocol MetalViewCoordinator: MTKViewDelegate {
    func configure(_ view: MTKView)
}
