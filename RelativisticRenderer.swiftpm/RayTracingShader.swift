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
        float3 massPos = float3(0, 0, 125);

        // We calculate the angle of deflection based on the impact parameter and a constant.
        float3 unitRay = normalize(cartesianRay);
        float k = 1.0;
        float schwarzchildRadius = 10.0;
        float impactParam = length(massPos - dot(unitRay, massPos)*unitRay);
        if (impactParam < schwarzchildRadius) {
            outTexture.write(float4(0, 0, 0, 1), gid);
            return;
        }
        float angleOfDeflection = k / (impactParam - schwarzchildRadius);

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
        float2 deflectedRayDirectionPolar = float2(
            atan2(deflectedRayDirection.z, deflectedRayDirection.x), // yaw
            atan2(deflectedRayDirection.y, length(deflectedRayDirection.xz)) // pitch
        );
        float2 uv = float2(
            (deflectedRayDirectionPolar.x + M_PI_F) / (2 * M_PI_F),
            (deflectedRayDirectionPolar.y + M_PI_F / 2) / (M_PI_F)
        );

        float3 viewRayDirection = float3(0, 0, 1);
        float4 color;
        uv.x += time / 60.0;
        color = skyTexture.sample(textureSampler, uv);
        //color = sampleCheckerBoard(uv, 50.0);
        outTexture.write(color, gid);
    }
    """
