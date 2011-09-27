//
//  Colours.fsh
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

uniform lowp sampler2D sTexture;
varying highp vec2 vTextureCoordinate;

void main()
{
    gl_FragColor = texture2D(sTexture, vTextureCoordinate);
}
