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
    
    // Converted from the hex values at http://www.vendian.org/mncharity/dir3/blackbody/
    // The first color is for 1000K (Kelvin), the second for 1200K and so on (in increments of 200K).
    constant float3 blackBodyRadiationLookup[] = {
        float3(255.0 / 255.0, 56.0 / 255.0, 0.0 / 255.0),
        float3(255.0 / 255.0, 83.0 / 255.0, 0.0 / 255.0),
        float3(255.0 / 255.0, 101.0 / 255.0, 0.0 / 255.0),
        float3(255.0 / 255.0, 115.0 / 255.0, 0.0 / 255.0),
        float3(255.0 / 255.0, 126.0 / 255.0, 0.0 / 255.0),
        float3(255.0 / 255.0, 137.0 / 255.0, 18.0 / 255.0),
        float3(255.0 / 255.0, 147.0 / 255.0, 44.0 / 255.0),
        float3(255.0 / 255.0, 157.0 / 255.0, 63.0 / 255.0),
        float3(255.0 / 255.0, 165.0 / 255.0, 79.0 / 255.0),
        float3(255.0 / 255.0, 173.0 / 255.0, 94.0 / 255.0),
        float3(255.0 / 255.0, 180.0 / 255.0, 107.0 / 255.0),
        float3(255.0 / 255.0, 187.0 / 255.0, 120.0 / 255.0),
        float3(255.0 / 255.0, 193.0 / 255.0, 132.0 / 255.0),
        float3(255.0 / 255.0, 199.0 / 255.0, 143.0 / 255.0),
        float3(255.0 / 255.0, 204.0 / 255.0, 153.0 / 255.0),
        float3(255.0 / 255.0, 209.0 / 255.0, 163.0 / 255.0),
        float3(255.0 / 255.0, 213.0 / 255.0, 173.0 / 255.0),
        float3(255.0 / 255.0, 217.0 / 255.0, 182.0 / 255.0),
        float3(255.0 / 255.0, 221.0 / 255.0, 190.0 / 255.0),
        float3(255.0 / 255.0, 225.0 / 255.0, 198.0 / 255.0),
        float3(255.0 / 255.0, 228.0 / 255.0, 206.0 / 255.0),
        float3(255.0 / 255.0, 232.0 / 255.0, 213.0 / 255.0),
        float3(255.0 / 255.0, 235.0 / 255.0, 220.0 / 255.0),
        float3(255.0 / 255.0, 238.0 / 255.0, 227.0 / 255.0),
        float3(255.0 / 255.0, 240.0 / 255.0, 233.0 / 255.0),
        float3(255.0 / 255.0, 243.0 / 255.0, 239.0 / 255.0),
        float3(255.0 / 255.0, 245.0 / 255.0, 245.0 / 255.0),
        float3(255.0 / 255.0, 248.0 / 255.0, 251.0 / 255.0),
        float3(254.0 / 255.0, 249.0 / 255.0, 255.0 / 255.0)
    };
    
    // Approximation adapted from: https://github.com/zubetto/BlackBodyRadiation/blob/main/BlackBodyRadiation.hlsl
    // To did this precisely we'd need to perform integration, which would significantly
    // hurt performance.
    float3 blackBodyRadiation(float temperature) {
        float step = 200.0;
        float k = clamp(temperature, 1000.0, 6599.0) - 1000.0;
        int index = floor(k / step);
        return mix(
            blackBodyRadiationLookup[index],
            blackBodyRadiationLookup[index + 1],
            k / step - float(index)
        );
    }
    
    typedef enum {
        STAR_MAP = 0,
        CHECKER_BOARD = 1
    } Background;
    
    typedef struct {
        float3 cameraPosition;
        float3 cameraRay;
        Background background;
        int stepCount;
        int maxRevolutions;
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
            ((float)gid.x - textureWidth/2) / textureWidth * 2,
            ((float)gid.y - textureHeight/2) / textureWidth * 2,
            1
        );

        // The position (relative to camera) of the mass which is acting as a gravitational lens.
        float3 massPos = float3(0, 1, 10);
        float accretionDiskStart = 1.5;
        float accretionDiskEnd = 3.0;

        // We rotate our coordinate system based on the initial velocity and the position of the mass
        // so that the ray travels in the xz-plane.
        float3 position = -massPos;
        float3 xBasis = normalize(position);
        float3 unitRay = normalize(cartesianRay);
        // A vector perpendicular to xBasis and in the same plane as xBasis and unitRay
        float3 yBasis = normalize(cross(cross(xBasis, unitRay), xBasis));

        float r = length(position);
        float u = 1.0 / r;
        float du = -dot(unitRay, xBasis) / dot(unitRay, yBasis) * u;
        
        float phi = 0.0;
        
        float3 previousPosition = position;
        float previousU = u;

        int steps = config.stepCount;
        float maxRevolutions = float(config.maxRevolutions);
        float4 color = float4(0, 0, 0, 0);
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
            if (config.renderAccretionDisk && sign(previousPosition.y) != sign(position.y)) {
                // We assume that the photon is travelling in a straight line between the previous
                // and current positions so that we can easily perform an intersection.
                float lerpFactor = abs(previousPosition.y) / abs(previousPosition.y - position.y);
                float r = length(mix(previousPosition, position, lerpFactor));
                if (r > accretionDiskStart && r < accretionDiskEnd) {
                    float factor = (r - accretionDiskStart) / (accretionDiskEnd - accretionDiskStart);
                    float3 emittedColor = blackBodyRadiation(mix(4000, 1000, factor));
                    outTexture.write(float4(emittedColor, 1), gid);
                    return;
                }
            }
            
            if (u > 1.0) {
                break;
            }
        }
    
        float schwarzschildRadius = 1.0;
        if (1.0 / u < schwarzschildRadius ) {
            color = float4(0, 0, 0, 1) * (1 - color.a) + color * color.a;
        } else {
            float3 ray = position - previousPosition;
            float2 uv = float2(
                atan2(ray.z, ray.x) / (2 * M_PI_F) + 0.5 + time * 0.01,
                atan2(ray.y, length(ray.xz)) / M_PI_F + 0.5
            );
    
            float4 sampledColor;
            if (config.background == STAR_MAP) {
                sampledColor = skyTexture.sample(textureSampler, uv);
            } else if (config.background == CHECKER_BOARD) {
                sampledColor = sampleCheckerBoard(uv, 40);
            } else {
                // Make it obvious that something has gone wrong
                sampledColor = float4(1, 0, 1, 1);
            }
    
            color = sampledColor * (1 - color.a) + color * color.a;
        }
        outTexture.write(color, gid);
    }
    """
