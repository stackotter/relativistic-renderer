import MetalKit

struct RelativisticRenderer: Renderer {
    let library: any MTLLibrary
    let computePipelineState: any MTLComputePipelineState
    let blitPipelineState: any MTLRenderPipelineState
    var computeOutputTexture: (any MTLTexture)?
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue) throws {
        let options = MTLCompileOptions()
        do {
            library = try device.makeLibrary(
                source: """
                #include <metal_stdlib>
                
                using namespace metal;
                
                constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
                
                float4 sampleCheckerBoard(float2 uv, float scaleFactor) {
                    float2 scaledUV = uv * scaleFactor;
                    if (length(scaledUV) < 0.25) {
                        return float4(1, 0.75, 0, 1);
                    }
                    if (((int)floor(scaledUV.x) % 2 == 0) == ((int)floor(scaledUV.y) % 2 == 0)) {
                        return float4(1, 1, 1, 1);
                    } else {
                        return float4(0, 0, 0, 1);
                    }
                }
                
                kernel void computeFunction(texture2d<float, access::write> outTexture [[texture(0)]],
                                            uint2 gid [[thread_position_in_grid]]) {
                    float textureWidth = (float)outTexture.get_width();
                    float textureHeight = (float)outTexture.get_height();
                    
                    // A ray from the camera representing the direction that light must come from to
                    // contribute to the current pixel (we trace this ray backwards).
                    float3 cartesianRay = float3(
                        ((float)gid.x - textureWidth/2) / textureWidth,
                        ((float)gid.y - textureHeight/2) / textureWidth,
                        1
                    );
                
                    // The position (relative to camera) of the mass which is acting as a gravitational lens.
                    float3 massPos = float3(0, 0, 125);

                    // We calculate the angle of deflection based on the impact parameter and a constant.
                    float3 unitRay = normalize(cartesianRay);
                    float k = 1.0;
                    float impactParam = length(massPos - dot(unitRay, massPos)*unitRay);
                    float angleOfDeflection = k / impactParam;
                
                    // The deflection occurs in the plane containing the original ray and the mass. Note that
                    // this plane contains the origin.
                    float3 deflectionPlaneNormal = normalize(cross(massPos, unitRay));
                    // The original ray direction (unitRay) forms a coordinate system along with deflectionPlaneNormal
                    // and the aptly named otherBasisVector.
                    float3 otherBasisVector = normalize(cross(unitRay, deflectionPlaneNormal)); // TODO: Is this normalized by definition?
                    
                    // The direction of the deflected ray in this special basis with the basis vectors
                    // unitRay, deflectionPlaneNormal, and otherBasisVector. In this basis, the original
                    // ray points exactly in the z direction, and the xz plane is the deflection plane.
                    // In mathematical terms this is an orthonormal basis (all 3 basis vectors are perpendicular
                    // to one another.
                    float3 deflectedDirectionInCustomBasis = float3(
                        sin(angleOfDeflection),
                        0,
                        cos(angleOfDeflection)
                    );
                    float3 deflectedRayDirection = deflectedDirectionInCustomBasis.x * otherBasisVector
                                                 + deflectedDirectionInCustomBasis.y * deflectionPlaneNormal
                                                 + deflectedDirectionInCustomBasis.z * unitRay;
                    
                    // This is in the same basis as deflectedDirectionInCustomBasis except that the origin
                    // is at the deflecting mass instead of the observer.
                    float3 deflectedRayOriginInCustomBasis = float3(
                        -deflectedDirectionInCustomBasis.z,
                        0,
                        deflectedDirectionInCustomBasis.x
                    ) * impactParam;
                    float3 deflectedRayOrigin = massPos
                                              + deflectedRayOriginInCustomBasis.x * otherBasisVector
                                              + deflectedRayOriginInCustomBasis.y * deflectionPlaneNormal
                                              + deflectedRayOriginInCustomBasis.z * unitRay;
                
                    // The deflected ray's intersection with the background plane determines the 'uv' we
                    // sample the background at (not really a normal uv since it doesn't need to be bounded).
                    float backgroundDistance = 250;
                    float2 uv = float2(
                        deflectedRayDirection.x/deflectedRayDirection.z * (backgroundDistance - deflectedRayOrigin.z) + deflectedRayOrigin.x,
                        deflectedRayDirection.y/deflectedRayDirection.z * (backgroundDistance - deflectedRayOrigin.z) + deflectedRayOrigin.y
                    );
                    //float2 uv = float2(
                    //    unitRay.x/unitRay.z * (backgroundDistance),
                    //    unitRay.y/unitRay.z * (backgroundDistance)
                    //);

                    float3 viewRayDirection = float3(0, 0, 1);
                    float4 color;
                    if (dot(deflectedRayDirection, viewRayDirection) < 0) {
                        // If the ray is deflected back towards the observer, render the pixel as black.
                        color = float4(0, 0, 0, 1);
                    } else {
                        color = sampleCheckerBoard(uv, 1.0/5.0);
                    }
                    outTexture.write(color, gid);
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
        let computeOutputTexture = try updateOutputTexture(device, view)
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SimpleError("Failed to make compute command encoder")
        }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(computeOutputTexture, index: 0)
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

