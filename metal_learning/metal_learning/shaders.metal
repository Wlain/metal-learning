//
//  shaders.metal
//  metal_learning
//
//  Created by william on 2021/5/15.
//

#include <metal_stdlib>
#include "shaderTypes.h"
using namespace metal;



typedef struct
{
    float4 position [[position]];
    float2 textureCoordinate;
} RasterizerData;

vertex RasterizerData vertShader(uint vertexID [[vertex_id]], constant Vertex* vertexArray [[buffer(0)]])
{
    RasterizerData out;
    float4 position = vector_float4(vertexArray[vertexID].position, 0.0f, 1.0f);
    out.position = position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

fragment float4 fragShader(RasterizerData in [[stage_in]], texture2d<half> colorTexture [[texture(0)]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    return float4(colorSample);
}


