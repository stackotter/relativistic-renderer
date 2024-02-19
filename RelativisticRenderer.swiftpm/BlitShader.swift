let blitShaderSource =
    """
    #include <metal_stdlib>

    using namespace metal;

    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear, address::repeat);
    
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
    """
