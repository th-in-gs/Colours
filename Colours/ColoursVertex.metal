//
//  Colours.vsh
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

#include <metal_stdlib>
#include "ColoursShaders.h"

using namespace metal;

vertex VertexOutToFragmentIn vertexMain(uint vertexId [[vertex_id]],
                                        constant float2 *vertices [[buffer(0)]],
                                        constant float2 *textureCoordinates [[buffer(1)]],
                                        constant float4x4 &uPositioningMatrix [[buffer(2)]],
                                        constant float4 &uTintColor [[buffer(3)]])
{
    float2 position = vertices[vertexId];
    float2 textureCoordinate = textureCoordinates[vertexId];
        
    // 100% tint for vertexes with y < 0,
    // 0% for vertexes with y > 1.
    const half4 cMediumGrey = { 0.5, 0.5, 0.5, 1.0 };
    half tintPercentage = 1.0 - step(position.y, 0.0);
    const half4 tintColor = mix(cMediumGrey, half4(uTintColor), tintPercentage);
    
    const float4 positionOut = uPositioningMatrix * float4(position, 0, 1);
    
    return (VertexOutToFragmentIn){ positionOut, textureCoordinate, tintColor };
}
