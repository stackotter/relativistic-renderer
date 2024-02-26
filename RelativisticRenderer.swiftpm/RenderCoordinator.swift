import MetalKit

final class RenderCoordinator<ConcreteRenderer: Renderer>: NSObject, MetalViewCoordinator {
    typealias Configuration = ConcreteRenderer.Configuration

    let device: MetalDevice
    let commandQueue: any MTLCommandQueue
    var renderer: ConcreteRenderer
    var configuration: ConcreteRenderer.Configuration
    
    init(
        device: MetalDevice,
        commandQueue: any MTLCommandQueue,
        renderer: ConcreteRenderer,
        configuration: Configuration
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.renderer = renderer
        self.configuration = configuration
    }
    
    static func create(with resources: ConcreteRenderer.Resources) throws -> RenderCoordinator {
        let device = try MetalDevice.systemDefault()
        
        guard let commandQueue = device.wrappedDevice.makeCommandQueue() else {
            throw SimpleError("Failed to make Metal command queue")
        }
        
        let renderer: ConcreteRenderer
        do {
            renderer = try ConcreteRenderer(
                device: device,
                commandQueue: commandQueue,
                resources: resources
            )
        } catch {
            throw SimpleError("Failed to create renderer: \(error)")
        }
        
        let configuration = Configuration.default
        
        return RenderCoordinator(
            device: device,
            commandQueue: commandQueue,
            renderer: renderer,
            configuration: configuration
        )
    }
    
    func setup(_ view: MTKView) {
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 1, 0, 1)
        view.device = device.wrappedDevice
        view.drawableSize = view.frame.size
        view.framebufferOnly = false
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        do {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
                throw SimpleError("Failed to get current render pass descriptor")
            }
            
            guard let drawable = view.currentDrawable else {
                throw SimpleError("Failed to get current drawable")
            }
            
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw SimpleError("Failed to make command buffer")
            }
            
            try renderer.render(
                view: view,
                configuration: configuration,
                device: device,
                renderPassDescriptor: renderPassDescriptor,
                drawable: drawable,
                commandBuffer: commandBuffer
            )
        } catch {
            print("Failed to render frame: \(error)")
        }
    }
}

protocol Default {
    static var `default`: Self { get }
}

protocol Renderer {
    associatedtype Configuration: Default
    associatedtype Resources
    init(device: MetalDevice, commandQueue: MTLCommandQueue, resources: Resources) throws
    mutating func render(
        view: MTKView,
        configuration: Configuration,
        device: MetalDevice,
        renderPassDescriptor: MTLRenderPassDescriptor,
        drawable: any MTLDrawable,
        commandBuffer: any MTLCommandBuffer
    ) throws
}
