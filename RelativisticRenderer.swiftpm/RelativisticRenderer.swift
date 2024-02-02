import MetalKit

struct RelativisticRenderer: Renderer {
    var vertices: [SIMD3<Float>] = [
        [0, 1, 0],
        [1, -1, 0],
        [-1, -1, 0]
    ]

    let library: any MTLLibrary
    let renderPipelineState: any MTLRenderPipelineState
    let vertexBuffer: any MTLBuffer
    let computePipelineState: any MTLComputePipelineState
    let blitPipelineState: any MTLRenderPipelineState
    var backgroundTexture: (any MTLTexture)?
    var computeOutputTexture: (any MTLTexture)?
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue) throws {
        let options = MTLCompileOptions()
        do {
            library = try device.makeLibrary(
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
                
                kernel void computeFunction(texture2d<float, access::read> inTexture [[texture(0)]],
                                       texture2d<float, access::write> outTexture [[texture(1)]],
                                       uint2 gid [[thread_position_in_grid]]) {
                    outTexture.write(inTexture.read(gid), gid);
                }
                
                typedef struct {
                    float4 position [[position]];
                    float2 uv;
                } BlitVertex;
                
                constant BlitVertex blitVertices[] = {
                    { .position = float4(-1.0, 1.0, 0, 1), .uv = float2(0, 0) },
                    { .position = float4(1.0, 1.0, 0, 1), .uv = float2(1, 0) },
                    { .position = float4(1.0, -1.0, 0, 1), .uv = float2(1, 1) },
                    { .position = float4(1.0, -1.0, 0, 1), .uv = float2(1, 1) },
                    { .position = float4(-1.0, -1.0, 0, 1), .uv = float2(0, 1) },
                    { .position = float4(-1.0, 1.0, 0, 1), .uv = float2(0, 0) }
                };
                
                vertex BlitVertex blitVertexFunction(uint vertexId [[vertex_id]]) {
                    return blitVertices[vertexId];
                }
                
                constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);

                fragment float4 blitFragmentFunction(BlitVertex in [[stage_in]],
                                                 texture2d<float, access::sample> inTexture [[texture(0)]]) {
                    return inTexture.sample(textureSampler, in.uv);
                }
                """,
                options: options
            )
        } catch {
            throw SimpleError("Failed to compile shaders: \(error)")
        }
        
        guard
            let vertexFunction = library.makeFunction(name: "vertexFunction"),
            let fragmentFunction = library.makeFunction(name: "fragmentFunction")
        else {
            throw SimpleError("Failed to get vertex function or fragment function")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw SimpleError("Failed to make render pipeline state: \(error)")
        }
        
        let bytes = MemoryLayout<SIMD3<Float>>.stride * vertices.count
        
        guard let buffer = device.makeBuffer(length: bytes) else {
            throw SimpleError("Failed to make vertex buffer")
        }
        buffer.contents().copyMemory(from: &vertices, byteCount: bytes)
        vertexBuffer = buffer
        
        guard let computeFunction = library.makeFunction(name: "computeFunction") else {
            throw SimpleError("Failed to get compute function")
        }

        do {
            computePipelineState = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            throw SimpleError("Failed to make compute pipeline state: \(error)")
        }
        
        guard
            let blitVertexFunction = library.makeFunction(name: "blitVertexFunction"),
            let blitFragmentFunction = library.makeFunction(name: "blitFragmentFunction")
        else {
            throw SimpleError("Failed to get vertex function or fragment function for blit pipeline")
        }
        
        let blitPipelineDescriptor = MTLRenderPipelineDescriptor()
        blitPipelineDescriptor.vertexFunction = blitVertexFunction
        blitPipelineDescriptor.fragmentFunction = blitFragmentFunction
        blitPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            blitPipelineState = try device.makeRenderPipelineState(descriptor: blitPipelineDescriptor)
        } catch {
            throw SimpleError("Failed to make blit pipeline state: \(error)")
        }
    }
    
    mutating func render(view: MTKView, device: MTLDevice, renderPassDescriptor: MTLRenderPassDescriptor, drawable: MTLDrawable, commandBuffer: MTLCommandBuffer) throws {
        let backgroundTexture: any MTLTexture
        let computeOutputTexture: any MTLTexture
        if let textureA = self.backgroundTexture, let textureB = self.computeOutputTexture, textureA.width == textureB.width, textureA.height == textureB.height, textureB.width == Int(view.drawableSize.width), textureB.height == Int(view.drawableSize.height) {
            backgroundTexture = textureA
            computeOutputTexture = textureB
        } else {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.width = Int(view.drawableSize.width)
            textureDescriptor.height = Int(view.drawableSize.height)
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.usage = [.shaderRead, .renderTarget]
            
            guard let textureA = device.makeTexture(descriptor: textureDescriptor) else {
                throw SimpleError("Failed to make background render target")
            }
            self.backgroundTexture = textureA
            backgroundTexture = textureA
            
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            guard let textureB = device.makeTexture(descriptor: textureDescriptor) else {
                throw SimpleError("Failed to make compute shader output texture")
            }
            self.computeOutputTexture = textureB
            computeOutputTexture = textureB
            print("Remaking textures")
        }
        
        let backgroundRenderPassDescriptor = MTLRenderPassDescriptor()
        backgroundRenderPassDescriptor.colorAttachments[0].texture = backgroundTexture
        backgroundRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 1, alpha: 1)
        backgroundRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        backgroundRenderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: backgroundRenderPassDescriptor) else {
            throw SimpleError("Failed to make render command encoder")
        }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        renderEncoder.endEncoding()
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SimpleError("Failed to make compute command encoder")
        }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(backgroundTexture, index: 0)
        computeEncoder.setTexture(computeOutputTexture, index: 1)
        computeEncoder.dispatchThreadgroups(
            MTLSize(width: Int(view.drawableSize.width + 15) / 16, height: Int(view.drawableSize.height + 15) / 16, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1)
        )
        computeEncoder.endEncoding()
        
        guard let blitRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            throw SimpleError("Failed to make render command encoder for blitting output to drawable")
        }
        
        blitRenderEncoder.setRenderPipelineState(blitPipelineState)
        blitRenderEncoder.setFragmentTexture(computeOutputTexture, index: 0)
        blitRenderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        blitRenderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

