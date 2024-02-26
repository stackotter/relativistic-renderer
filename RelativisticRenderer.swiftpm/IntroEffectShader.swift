let introEffectShaderSource =
    """
    #include <metal_stdlib>

    using namespace metal;

    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear, address::repeat);

    typedef enum {
        STAR_MAP = 0,
        CHECKER_BOARD = 1
    } Background;
    
    typedef struct {
        float cameraX;
        float cameraY;
        float cameraZ;
        float cameraPitch;
        float cameraYaw;
        Background background;
        int stepCount;
        int maxRevolutions;
        float accretionDiskStart;
        float accretionDiskEnd;
        uint8_t renderAccretionDisk;
    } Configuration;

    kernel void computeFunction(uint2 gid [[thread_position_in_grid]],
                                texture2d<float, access::write> outTexture [[texture(0)]],
                                texture2d<float, access::sample> skyTexture [[texture(1)]],
                                constant float &time [[buffer(0)]],
                                constant Configuration &config [[buffer(1)]]) {
        float textureWidth = (float)outTexture.get_width();
        float textureHeight = (float)outTexture.get_height();
        
        // A ray from the camera representing the direction that light must come from to
        // contribute to the current pixel (we trace this ray backwards).
        float3 cartesianRay = float3(
            (float(gid.x) - textureWidth/2) / textureWidth * 2,
            1,
            -(float(gid.y) - textureHeight/2) / textureWidth * 2
        );
        float rayTheta = atan2(cartesianRay.z, cartesianRay.x);
        float rayPhi = atan2(cartesianRay.y, length(cartesianRay.xz));
    
        float zoom = log(time + 3) * 2;
        cartesianRay = float3(
            cos(rayPhi + zoom) * sin(rayTheta),
            sin(rayPhi + zoom),
            cos(rayPhi + zoom) * cos(rayTheta)
        );

        float3 ray = normalize(cartesianRay);
        float2 uv = float2(
            atan2(ray.z, ray.x) / (2 * M_PI_F) + 0.5 + time * 0.02,
            atan2(ray.y, length(ray.xz)) / M_PI_F + 0.5
        );

        float4 color = skyTexture.sample(textureSampler, uv);
        outTexture.write(color, gid);
    }
    """
