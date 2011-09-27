//
//  Colours.vsh
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

attribute vec4 aPosition;
attribute vec2 aTextureCoordinate;

varying vec2 vTextureCoordinate;

void main()
{
    vTextureCoordinate = aTextureCoordinate;
    gl_Position = aPosition;
}
