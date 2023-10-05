//
//  Colours.fsh
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

#include <metal_stdlib>
#include "ColoursShaders.h"

using namespace metal;

static half4 dodgyAdHocTint(const half4 baseShadeColor, const half4 tintColor)
{
    // This will give us 100% tint color when the base shade is 50% brightness,
    // ramping down to full black when the base is black, and up to full
    // white when the base is white.
    // I don't pretend that this models any sort of real-world color mixing
    // process, but it seems to look alright.

    // Brightness using NTSC brightness formula.
    // Uses the dot-product built in function to calculate.
    half4 brightness = dot(baseShadeColor.rgb, half3(0.299, 0.587, 0.114));
    
    // Percentage of tint color to use.
    // 1 when the brightness is 0.5, ramping down to 0 when the brightness
    // 0 or 1.
    // Note that the '/ 0.5' is really "* 2" - but 2.0 is not representable
    // as a lowp float (lowp float range is -2.0 to 2.0, _non_ inclusive)
    half4 mixPercentage = (-abs(brightness - 0.5)) / 0.5 + 1.0;
    
    // Mix the base with the tint.
    return mix(baseShadeColor, tintColor, mixPercentage);
}



fragment half4 fragmentMain(VertexOutToFragmentIn in [[ stage_in ]],
                            texture2d<half> texture [[ texture(0) ]])
{
    const sampler quadSampler;
    half4 textureSample = texture.sample(quadSampler, in.textureCoordinate);
    return dodgyAdHocTint(textureSample, in.tintColor);
    return textureSample;
}
