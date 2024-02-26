import MetalKit

enum Background: Int32 {
    case starMap = 0
    case checkerBoard = 1
}

struct RelativisticRenderer: Renderer {
    struct Configuration: Default {
        var cameraX: Float
        var cameraY: Float
        var cameraZ: Float
        var cameraPitch: Float
        var cameraYaw: Float
        var background: Int32
        var stepCount: Int32
        var maxRevolutions: Int32
        var accretionDiskStart: Float
        var accretionDiskEnd: Float
        var renderAccretionDisk: Bool
        var introEffect: Bool
        
        var cameraPosition: SIMD3<Float> {
            get {
                SIMD3(cameraX, cameraY, cameraZ)
            }
            set {
                cameraX = newValue.x
                cameraY = newValue.y
                cameraZ = newValue.z
            }
        }
        
        static let `default` = Self(
            cameraX: 0,
            cameraY: 0,
            cameraZ: -5,
            cameraPitch: 0,
            cameraYaw: 0,
            background: Background.starMap.rawValue,
            stepCount: 30,
            maxRevolutions: 1,
            accretionDiskStart: 1.5,
            accretionDiskEnd: 3.0,
            renderAccretionDisk: true,
            introEffect: false
        )
        
        func with<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
            var config = self
            config[keyPath: keyPath] = value
            return config
        }
    }
    
    struct Resources {
        var computeLibrary: MetalLibrary
        var introEffectLibrary: MetalLibrary
        var blitLibrary: MetalLibrary
    }

    let computePipelineState: any MTLComputePipelineState
    let introEffectPipelineState: any MTLComputePipelineState
    let blitPipelineState: any MTLRenderPipelineState
    var computeOutputTexture: (any MTLTexture)?
    let skyTexture: any MTLTexture
    let timeBuffer: MetalScalarBuffer<Float>
    let initialTime: CFAbsoluteTime
    let configBuffer: MetalScalarBuffer<Configuration>
    
    static func loadResources() async throws -> Resources {
        let device = try MetalDevice.systemDefault()
        let computeLibrary = try device.compileMetalLibrary(source: rayTracingShaderSource)
        let introEffectLibrary = try device.compileMetalLibrary(source: introEffectShaderSource)
        let blitLibrary = try device.compileMetalLibrary(source: blitShaderSource)
        return Resources(computeLibrary: computeLibrary, introEffectLibrary: introEffectLibrary, blitLibrary: blitLibrary)
    }
    
    init(device: MetalDevice, commandQueue: any MTLCommandQueue, resources: Resources) throws {
        let computeFunction = try resources.computeLibrary.getFunction(name: "computeFunction")
        computePipelineState = try device.makeComputePipelineState(function: computeFunction)
        
        let introEffectFunction = try resources.introEffectLibrary.getFunction(name: "computeFunction")
        introEffectPipelineState = try device.makeComputePipelineState(function: introEffectFunction)
        
        let blitVertexFunction = try resources.blitLibrary.getFunction(name: "blitVertexFunction")
        let blitFragmentFunction = try resources.blitLibrary.getFunction(name: "blitFragmentFunction")
        
        blitPipelineState = try device.makeRenderPipelineState(
            vertexFunction: blitVertexFunction,
            fragmentFunction: blitFragmentFunction
        )

        do {
            skyTexture = try MTKTextureLoader(device: device.wrappedDevice).newTexture(name: "starmap_2020_4k", scaleFactor: 1, bundle: Bundle.main)
        } catch {
            throw SimpleError("Failed to load sky texture: \(error)")
        }
        
        timeBuffer = try device.makeScalarBuffer()
        initialTime = CFAbsoluteTimeGetCurrent()
        
        configBuffer = try device.makeScalarBuffer()
    }
    
    mutating func render(
        view: MTKView,
        configuration: Configuration,
        device: MetalDevice,
        renderPassDescriptor: MTLRenderPassDescriptor,
        drawable: MTLDrawable,
        commandBuffer: MTLCommandBuffer
    ) throws {
        let computeOutputTexture = try updateOutputTexture(device.wrappedDevice, view)
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SimpleError("Failed to make compute command encoder")
        }
        
        let time = Float(CFAbsoluteTimeGetCurrent() - initialTime)
        timeBuffer.copyMemory(from: time)
        configBuffer.copyMemory(from: configuration)

        if configuration.introEffect {
            computeEncoder.setComputePipelineState(introEffectPipelineState)
        } else {
            computeEncoder.setComputePipelineState(computePipelineState)
        }
        computeEncoder.setTexture(computeOutputTexture, index: 0)
        computeEncoder.setTexture(skyTexture, index: 1)
        computeEncoder.setBuffer(timeBuffer.wrappedBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(configBuffer.wrappedBuffer, offset: 0, index: 1)
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
}
