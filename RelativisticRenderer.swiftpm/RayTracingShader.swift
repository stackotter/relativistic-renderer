let rayTracingShaderSource =
    """
    #include <metal_stdlib>

    using namespace metal;

    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear, address::repeat);

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

    kernel void computeFunction(uint2 gid [[thread_position_in_grid]],
                                texture2d<float, access::write> outTexture [[texture(0)]],
                                texture2d<float, access::sample> skyTexture [[texture(1)]],
                                constant float &time [[buffer(0)]]) {
        float textureWidth = (float)outTexture.get_width();
        float textureHeight = (float)outTexture.get_height();
        
        // A ray from the camera representing the direction that light must come from to
        // contribute to the current pixel (we trace this ray backwards).
        float3 cartesianRay = float3(
            ((float)gid.x - textureWidth/2) / textureWidth * 2,
            ((float)gid.y - textureHeight/2) / textureWidth * 2,
            1
        );

        // The position (relative to camera) of the mass which is acting as a gravitational lens.
        float3 massPos = float3(0, 2, 10);

        // We rotate our coordinate system based on the initial velocity and the position of the mass
        // so that the ray travels in the xz-plane.
        float3 position = -massPos;
        float3 xBasis = normalize(position);
        float3 unitRay = normalize(cartesianRay);
        // A vector perpendicular to xBasis and in the same plane as xBasis and unitRay
        float3 yBasis = normalize(cross(cross(xBasis, unitRay), xBasis));

        float r = length(position);
        float u = 1.0 / r;
        float u0 = u;
        float du = -dot(unitRay, xBasis) / dot(unitRay, yBasis) * u;
        float du0 = du;
        
        float phi = 0.0;
        
        float3 previousPosition = position;
        float previousU = u;

        int steps = 200;
        float maxRevolutions = 2.0;
        for (int i = 0; i < steps; i++) {
            float step = maxRevolutions * 2.0 * M_PI_F / float(steps);
            previousU = u;
            u += du * step;
            float ddu = -u * (1.0 - 1.5 * u * u);
            du += ddu * step;
            if (u <= 0.0) {
                // Non-positive u means that the radius has exploded off to infinity. Just
                // set it to something really small (yet positive) and finish tracing.
                u = 0.000001;
                break;
            }
            phi += step;
            previousPosition = position;
            position = (cos(phi) * xBasis + sin(phi) * yBasis) / u;
            float3 ray = position - previousPosition;
            if (sign(previousPosition.y) != sign(position.y)) {
                // We assume that the photon is travelling in a straight line between the previous
                // and current positions so that we can easily perform an intersection.
                float lerpFactor = abs(previousPosition.y) / abs(previousPosition.y - position.y);
                float r = length(mix(previousPosition, position, lerpFactor));
                if (r > 1.5 && r < 3.0) {
                    outTexture.write(float4(1, 1, 1, 1), gid);
                    return;
                }
            }
            
            if (u > 1.0) {
                break;
            }
        }
    
        float schwarzschildRadius = 1.0;
        float4 color;
        if (1.0 / u < schwarzschildRadius ) {
            color = float4(0, 0, 0, 1);
        } else {
            float3 ray = position - previousPosition;
            float2 uv = float2(
                atan2(ray.z, ray.x) / (2 * M_PI_F) + 0.5 + time * 0.01,
                atan2(ray.y, length(ray.xz)) / M_PI_F + 0.5
            );
            color = skyTexture.sample(textureSampler, uv);
        }
        outTexture.write(color, gid);
    }
    """
