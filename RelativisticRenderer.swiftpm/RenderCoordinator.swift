import MetalKit

final class RenderCoordinator: NSObject, MetalViewCoordinator {
    let device: any MTLDevice
    
    override init() {
        device = MTLCreateSystemDefaultDevice()!
        super.init()
    }
    
    func configure(_ view: MTKView) {
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 1, 0, 1)
        view.device = device
        view.drawableSize = view.frame.size
    }
    
    func update(with view: MTKView) {
        // TODO: Is this required?
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        // TODO: Decide how error handling should work
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            print("Failed to get current render pass descriptor")
            return
        }
        
        guard let drawable = view.currentDrawable else {
            print("Failed to get current drawable")
            return
        }
        
        // TODO: Only create once
        let commandQueue = device.makeCommandQueue()!
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to make command buffer")
            return
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("Failed to make render command encoder")
            return
        }
        
        let options = MTLCompileOptions()
        let library = try! device.makeLibrary(
            source: """
            #include <metal_stdlib>
            
            using namespace metal;
            
            typedef struct {
                float3 position;
            } InVertex;
            
            typedef struct {
                float4 position [[position]];
            } OutVertex;
            
            vertex OutVertex vertexFunction(constant InVertex *vertices [[buffer(0)]],
                                            uint vertexId [[vertex_id]]) {
                InVertex in = vertices[vertexId];
                OutVertex out = { .position = float4(in.position, 1) };
                return out;
            }
            
            fragment float4 fragmentFunction(OutVertex in [[stage_in]]) {
                return float4(1, 0, 0, 1);
            }
            """,
            options: options
        )
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexFunction")!
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        let pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        var vertices: [SIMD3<Float>] = [
            [0, 1, 0],
            [1, -1, 0],
            [-1, -1, 0]
        ]
        let bytes = MemoryLayout<SIMD3<Float>>.stride * vertices.count
        let vertexBuffer = device.makeBuffer(length: bytes)
        vertexBuffer?.contents().copyMemory(from: &vertices, byteCount: bytes)
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        print("Done draw")
    }
}
