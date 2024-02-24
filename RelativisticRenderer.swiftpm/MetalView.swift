import MetalKit
import SwiftUI

struct MetalView<Coordinator: MetalViewCoordinator>: UIViewRepresentable {
    typealias UIViewType = MTKView
    
    @Binding var error: String?
    var configuration: Coordinator.Configuration
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
        context.coordinator?.setup(mtkView)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator?.configuration = configuration
    }
}

protocol MetalViewCoordinator: MTKViewDelegate {
    associatedtype Configuration
    var configuration: Configuration { get set }
    func setup(_ view: MTKView)
}
