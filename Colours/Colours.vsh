//
//  Colours.vsh
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

attribute vec4 aPosition;
attribute vec2 aTextureCoordinate;

uniform mat4 uPositioningMatrix;

varying vec2 vTextureCoordinate;
varying vec4 vTintColor;

const vec4 cMediumGrey = vec4(0.5, 0.5, 0.5, 1.0);
const vec4 cBondiBlue = vec4(0.0, 0.725, 1.0, 1.0);

void main()
{
    // Pass the texture coordinate straight through.
    vTextureCoordinate = aTextureCoordinate;
    
    // 100% tint for vertexes with y < 0, 
    // 0% for vertexes with y > 1.
    float tintPercentage = 1.0 - step(aPosition.y, 0.0);
    vTintColor = mix(cMediumGrey, cBondiBlue, tintPercentage);
    
    gl_Position = uPositioningMatrix * aPosition;
}
