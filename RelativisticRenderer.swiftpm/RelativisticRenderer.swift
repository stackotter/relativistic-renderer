import MetalKit

struct RelativisticRenderer: Renderer {
    let computePipelineState: any MTLComputePipelineState
    let blitPipelineState: any MTLRenderPipelineState
    var computeOutputTexture: (any MTLTexture)?
    let skyTexture: any MTLTexture
    let timeBuffer: any MTLBuffer
    let initialTime: CFAbsoluteTime
    
    init(device: any MTLDevice, commandQueue: any MTLCommandQueue) throws {
        let library = try Self.compileMetalLibrary(device, source: rayTracingShaderSource)
        let computeFunction = try Self.getFunction(library, name: "computeFunction")
        computePipelineState = try Self.makeComputePipelineState(device, function: computeFunction)
        
        let blitLibrary = try Self.compileMetalLibrary(device, source: blitShaderSource)
        let blitVertexFunction = try Self.getFunction(blitLibrary, name: "blitVertexFunction")
        let blitFragmentFunction = try Self.getFunction(blitLibrary, name: "blitFragmentFunction")
        
        blitPipelineState = try Self.makeRenderPipelineState(
            device,
            vertexFunction: blitVertexFunction,
            fragmentFunction: blitFragmentFunction
        )

        do {
            skyTexture = try MTKTextureLoader(device: device).newTexture(name: "starmap_2020_4k", scaleFactor: 1, bundle: Bundle.main)
        } catch {
            throw SimpleError("Failed to load sky texture: \(error)")
        }
        
        guard let timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride) else {
            throw SimpleError("Failed to create time buffer")
        }
        self.timeBuffer = timeBuffer
        initialTime = CFAbsoluteTimeGetCurrent()
    }
    
    mutating func render(view: MTKView, device: MTLDevice, renderPassDescriptor: MTLRenderPassDescriptor, drawable: MTLDrawable, commandBuffer: MTLCommandBuffer) throws {
        let computeOutputTexture = try updateOutputTexture(device, view)
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SimpleError("Failed to make compute command encoder")
        }
        
        var time = Float(CFAbsoluteTimeGetCurrent() - initialTime)
        timeBuffer.contents().copyMemory(from: &time, byteCount: MemoryLayout<Float>.stride)
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(computeOutputTexture, index: 0)
        computeEncoder.setTexture(skyTexture, index: 1)
        computeEncoder.setBuffer(timeBuffer, offset: 0, index: 0)
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
    
    mutating func updateOutputTexture(_ device: MTLDevice, _ view: MTKView) throws -> MTLTexture {
        guard
            let computeOutputTexture = self.computeOutputTexture,
            computeOutputTexture.width == Int(view.drawableSize.width),
            computeOutputTexture.height == Int(view.drawableSize.height)
        else {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.width = Int(view.drawableSize.width)
            textureDescriptor.height = Int(view.drawableSize.height)
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            guard let computeOutputTexture = device.makeTexture(descriptor: textureDescriptor) else {
                throw SimpleError("Failed to make compute shader output texture")
            }
            self.computeOutputTexture = computeOutputTexture
            
            return computeOutputTexture
        }
        
        return computeOutputTexture
    }
    
    static func compileMetalLibrary(_ device: any MTLDevice, source: String) throws -> any MTLLibrary {
        let options = MTLCompileOptions()
        do {
            return try device.makeLibrary(source: source, options: options)
        } catch {
            throw SimpleError("Failed to compile shaders: \(error)")
        }
    }
    
    static func getFunction(_ library: any MTLLibrary, name: String) throws -> any MTLFunction {
        guard let function = library.makeFunction(name: name) else {
            throw SimpleError("Failed to get function '\(name)'")
        }
        return function
    }
    
    static func makeComputePipelineState(_ device: any MTLDevice, function: any MTLFunction) throws -> any MTLComputePipelineState {
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw SimpleError("Failed to make compute pipeline state: \(error)")
        }
    }
    
    static func makeRenderPipelineState(
        _ device: any MTLDevice,
        vertexFunction: any MTLFunction,
        fragmentFunction: any MTLFunction
    ) throws -> any MTLRenderPipelineState {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw SimpleError("Failed to make pipeline state: \(error)")
        }
    }
}
