//
//  ColoursShaders.h
//  Colours
//
//  Created by Jamie Montgomerie on 10/4/23.
//  Copyright © 2023 Things Made Out Of Other Things Ltd. All rights reserved.
//

#ifndef ColoursShaders_h
#define ColoursShaders_h

struct VertexOutToFragmentIn {
    float4 position [[position]];
    float2 textureCoordinate;
    half4 tintColor;
};

#endif /* ColoursShaders_h */
