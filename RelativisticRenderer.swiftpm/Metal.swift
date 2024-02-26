import Metal

struct MetalDevice {
    var wrappedDevice: any MTLDevice
    
    init(wrapping device: any MTLDevice) {
        self.wrappedDevice = device
    }
    
    static func systemDefault() throws -> MetalDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw SimpleError("Failed to create system default device")
        }
        return Self(wrapping: device)
    }
    
    func compileMetalLibrary(source: String) throws -> MetalLibrary {
        let options = MTLCompileOptions()
        do {
            return MetalLibrary(wrapping: try wrappedDevice.makeLibrary(source: source, options: options))
        } catch {
            throw SimpleError("Failed to compile shaders: \(error)")
        }
    }
    
    func makeComputePipelineState(function: any MTLFunction) throws -> any MTLComputePipelineState {
        do {
            return try wrappedDevice.makeComputePipelineState(function: function)
        } catch {
            throw SimpleError("Failed to make compute pipeline state: \(error)")
        }
    }
    
    func makeRenderPipelineState(
        vertexFunction: any MTLFunction,
        fragmentFunction: any MTLFunction
    ) throws -> any MTLRenderPipelineState {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            return try wrappedDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw SimpleError("Failed to make pipeline state: \(error)")
        }
    }
    
    func makeScalarBuffer<T>() throws -> MetalScalarBuffer<T> {
        guard let buffer = wrappedDevice.makeBuffer(length: MemoryLayout<T>.stride) else {
            throw SimpleError("Failed to create buffer")
        }
        return MetalScalarBuffer(wrapping: buffer)
    }
    
    func makeScalarBuffer<T>(initialValue: T) throws -> MetalScalarBuffer<T> {
        guard let buffer = wrappedDevice.makeBuffer(length: MemoryLayout<T>.stride) else {
            throw SimpleError("Failed to create buffer")
        }
        let scalarBuffer = MetalScalarBuffer<T>(wrapping: buffer)
        scalarBuffer.copyMemory(from: initialValue)
        return scalarBuffer
    }
}

struct MetalLibrary {
    var wrappedLibrary: any MTLLibrary
    
    init(wrapping library: any MTLLibrary) {
        self.wrappedLibrary = library
    }
    
    func getFunction(name: String) throws -> any MTLFunction {
        guard let function = wrappedLibrary.makeFunction(name: name) else {
            throw SimpleError("Failed to get function '\(name)'")
        }
        return function
    }
}

struct MetalScalarBuffer<T> {
    var wrappedBuffer: any MTLBuffer
    
    init(wrapping buffer: any MTLBuffer) {
        wrappedBuffer = buffer
    }
    
    func copyMemory(from value: T) {
        withUnsafePointer(to: value) { pointer in
            wrappedBuffer.contents().copyMemory(from: pointer, byteCount: MemoryLayout<T>.stride)
        }
    }
}
