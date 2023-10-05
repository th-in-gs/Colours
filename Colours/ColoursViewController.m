//
//  ColoursViewController.m
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import "ColoursViewController.h"
#import "ColoursMetalView.h"

#import <simd/simd.h>

static const float sIMacColors[5][4] =
{
    { 0.0f,   0.725f, 1.0f,   1.0f }, // Bondi Blue
    { 0.431f, 0.063f, 1.0f,   1.0f }, // Grape
    { 1.0f,   0.275f, 0.031f, 1.0f }, // Tangerine
    { 0.114f, 1.0f,   0.227f, 1.0f }, // Lime
    { 1.0f,   0.0f,   0.302f, 1.0f } // Strawberry
};

@interface ColoursViewController () <ColoursMetalViewDelegate>

@property (nonatomic, strong) ColoursMetalView *view;

@end

@implementation ColoursViewController {
    // Shaders
    id<MTLFunction> _vertexProgram;
    id<MTLFunction> _fragmentProgram;
    
    // Textures and geometry
    id<MTLTexture> _texture;
    CGSize _textureSize;
    id<MTLBuffer> _vertexCoordinates;
    id<MTLBuffer> _textureCoordinates;

    // Metal state
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    MTLRenderPassDescriptor *_renderPassDescriptor;
}

@dynamic view;

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)dealloc
{
    if (_animating) {
        [self stopAnimation];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [self startAnimation];
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopAnimation];
    
    [super viewWillDisappear:animated];
}

- (void)startAnimation
{
    if (!_animating) {
        self.view.paused = NO;
        _animating = YES;
    }
}

- (void)stopAnimation
{
    if (_animating) {
        self.view.paused = YES;
        _animating = NO;
    }
}

- (void)coloursMetalView:(ColoursMetalView *)view didSwitchToMTLDevice:(id<MTLDevice>)device
{
    [self loadShadersToMTLDevice:device];
    [self loadTextureToMTLDevice:device];
    [self loadGeometryToMTLDevice:device];
    [self setUpPipelineWithDevice:device];
}

- (void)coloursMetalView:(ColoursMetalView *)view 
      renderToMetalLayer:(CAMetalLayer *)layer
          forDisplayLink:(CADisplayLink *)displayLink
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<CAMetalDrawable> currentDrawable = [layer nextDrawable];
    if(!currentDrawable)
    {
        return;
    }

    _renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture;
    
    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    
    [renderEncoder setRenderPipelineState:_pipelineState];

    [renderEncoder setViewport:(MTLViewport){0, 0, layer.drawableSize.width, layer.drawableSize.height, -1, 1}];
    
    // Set the texture
    [renderEncoder setFragmentTexture:_texture atIndex:0];
    
    // Set the untransformed geometry
    [renderEncoder setVertexBuffer:_vertexCoordinates offset:0 atIndex:0];
    [renderEncoder setVertexBuffer:_textureCoordinates offset:0 atIndex:1];

    // Work out the matrix to position the iMac on the screen 
    CATransform3D staticPositioningTransform = CATransform3DIdentity;
    CGSize boundsSize = layer.bounds.size;
    CGSize textureSize = _textureSize;
    
    // Move the iMac down from the center of the screen
    CATransform3D moveDown = CATransform3DMakeTranslation(0.0f, -1.5f, 0.0f);
    staticPositioningTransform = CATransform3DConcat(staticPositioningTransform, moveDown);

    // Scale the 2-by-2 vertexPositions rectangle into the aspect ratio
    // of the texture.  We scale the height to be correct in terms of the 
    // width.
    CATransform3D correctAspectRatio = CATransform3DMakeScale(1.0f, 
                                                              textureSize.height / textureSize.width,
                                                              1.0f);
    staticPositioningTransform = CATransform3DConcat(staticPositioningTransform, correctAspectRatio);
    
    // Now, rotate it.  1/4 a rotation per second. around 
    // the Z axis (i.e. the axis pointing 'through' the screen).
    // This will cause a rotation around (0.0, 0.0).
    CATransform3D rotate = CATransform3DMakeRotation((M_PI * 0.5f) * displayLink.targetTimestamp,
                                                     0.0f, 0.0f, 1.0f);
    staticPositioningTransform = CATransform3DConcat(staticPositioningTransform, rotate);
        
    
    // Now, the scaling to an appropriate size.
    // We won't concatenate this to the positioning matrix yet
    // we'll do it in the loop, after we've rotated
    // the iMac around the center point, but we'll calculate it here
    // because it won't vary with the loop iteration.

    // Scale it up to get it to be 1:1 texture pixels to screen pixels.
    // Remember, the screen coordinate system is two units high, and two 
    // units wide, and so is the vertexPositions triangle strip.
    // textureSize.width is used in both X and Y scaling because we already 
    // scaled, before the rotation, to get the height to be in terms of the
    // width.
    CATransform3D scaleToSize = CATransform3DMakeScale(textureSize.width / boundsSize.width,
                                                       textureSize.width / boundsSize.height,
                                                       1.0f);
    
    // Lastly, we'll scale the whole scene up or down to fit our entire circle
    // of iMacs on the screen (turns out this means we need to scale to fit 3.25
    // iMacs across the width of the screen, so we work out the scale factor
    // required to do that).
    CGFloat screenScale = MIN(boundsSize.width / textureSize.width,
                              boundsSize.height / textureSize.height);
    CATransform3D scaleToScreen = CATransform3DMakeScale(screenScale / 3.25f,
                                                         screenScale / 3.25f,
                                                         1.0f);
    scaleToSize = CATransform3DConcat(scaleToSize, scaleToScreen);
    
    // The angle 'between' each iMac in the circle. 
    NSUInteger iMacCount = sizeof(sIMacColors) / sizeof(sIMacColors[0]);
    CGFloat iMacSegmentAngle = - 2.0f * (CGFloat)M_PI / (CGFloat)iMacCount;
    
    for(NSUInteger i = 0; i < iMacCount; ++i) {
        CATransform3D thisIMacPositioningTransform = staticPositioningTransform;

        // Rotate this iMac into its individual place in the circle
        CATransform3D rotateIntoPlace =  CATransform3DMakeRotation(i * iMacSegmentAngle, 0.0f, 0.0f, 1.0f);
        thisIMacPositioningTransform = CATransform3DConcat(thisIMacPositioningTransform, rotateIntoPlace);
        
        // Finally scale to pixel size using the scale factor using the matrix 
        // we calculated above.
        thisIMacPositioningTransform = CATransform3DConcat(thisIMacPositioningTransform, scaleToSize);
        
        // Upload the transform matrix. Because CoreAnimation uses CGFloats,
        // and our Metal shaders use flaots, we need to convert first.
        [renderEncoder setVertexBytes:(float[]){
                                        thisIMacPositioningTransform.m11, thisIMacPositioningTransform.m12, thisIMacPositioningTransform.m13, thisIMacPositioningTransform.m14,
                                        thisIMacPositioningTransform.m21, thisIMacPositioningTransform.m22, thisIMacPositioningTransform.m23, thisIMacPositioningTransform.m24,
                                        thisIMacPositioningTransform.m31, thisIMacPositioningTransform.m32, thisIMacPositioningTransform.m33, thisIMacPositioningTransform.m34,
                                        thisIMacPositioningTransform.m41, thisIMacPositioningTransform.m42, thisIMacPositioningTransform.m43, thisIMacPositioningTransform.m44
                                    }
                               length:4 * 4 * sizeof(float)
                              atIndex:2];
        
        // Upload the tint color.
        [renderEncoder setVertexBytes:sIMacColors[i]
                               length:sizeof(sIMacColors[i])
                              atIndex:3];
        
        // Finally, render our quad!
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    }
    
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:currentDrawable];
    [commandBuffer commit];
}

- (void)loadShadersToMTLDevice:(id<MTLDevice>)device
{
    _vertexProgram = nil;
    _fragmentProgram = nil;
    if(!device) {
        return;
    }

    id<MTLLibrary> shaderLib = [device newDefaultLibrary];
    _vertexProgram = [shaderLib newFunctionWithName:@"vertexMain"];
    _fragmentProgram = [shaderLib newFunctionWithName:@"fragmentMain"];
}

- (void)loadTextureToMTLDevice:(id<MTLDevice>)device
{
    _texture = nil;
    _textureSize = CGSizeZero;
    if(!device) {
        return;
    }
    
    UIImage *textureImage = [UIImage imageNamed:@"iMacGrey.png"];
    
    // Work out the image size in pixels.
    CGSize imageSize = textureImage.size;
    CGFloat imageScaleFactor = textureImage.scale;
    
    CGSize imagePixelSize = CGSizeMake(imageSize.width * imageScaleFactor,
                                       imageSize.height * imageScaleFactor);
    CGRect imageRect = CGRectMake(0, 0, 
                                  imagePixelSize.width, imagePixelSize.height);
    
    
    // Create a buffer to hold the raw decompressed RGBA data.
    void *textureRGBAData = malloc(4 * imagePixelSize.width * imagePixelSize.height);
    
    // Create a CGContext around our RGBA buffer to draw the image through.
    CGColorSpaceRef deviceRGBColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    size_t bytesPerRow = imagePixelSize.width * 4;
    CGContextRef textureContext =
        CGBitmapContextCreate(textureRGBAData,
                              imagePixelSize.width, imagePixelSize.height,
                              8,
                              bytesPerRow,
                              deviceRGBColorSpace,
                              kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(deviceRGBColorSpace);

    // Flip the Y coordinates so that we get our image the convenient way up
    CGContextScaleCTM(textureContext, 1.0f, -1.0f);
    CGContextTranslateCTM(textureContext, 0, -imagePixelSize.height);

    // Draw the image (cover the entire buffer).
    CGContextSetBlendMode(textureContext, kCGBlendModeCopy);
    CGContextDrawImage(textureContext, imageRect, textureImage.CGImage);  
    
    // We're done with the context now - the data is in the RGBA buffer.
    CGContextRelease(textureContext);
    
    MTLTextureDescriptor *textureDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:imagePixelSize.width
                                                          height:imagePixelSize.height
                                                       mipmapped:NO];
    textureDescriptor.storageMode = MTLStorageModeShared;
    
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    
    [texture replaceRegion:MTLRegionMake2D(0, 0, imagePixelSize.width, imagePixelSize.height)
               mipmapLevel:0
                 withBytes:textureRGBAData
               bytesPerRow:bytesPerRow];
    
    _texture = texture;
    _textureSize = imageSize; // Size in points, not pixels.
}

- (void)loadGeometryToMTLDevice:(id<MTLDevice>)device
{
    _vertexCoordinates = nil;
    _textureCoordinates = nil;
    if(!device) {
        return;
    }
    
    // A big 2 X 2 rectangle centered around 0, 0.
    // We'll position it using a positioning matrix in the vertex shader.
    static const simd_float2 vertexPositions[] = {
        { -1.0f, -1.0f },
        {  1.0f, -1.0f },
        { -1.0f,  1.0f },
        {  1.0f,  1.0f },
    };
    
    _vertexCoordinates =
    [device newBufferWithBytes:vertexPositions
                        length:sizeof(vertexPositions)
                       options:MTLResourceStorageModeShared];
    
    // The GL texture coordinates run from (0.0f, 0.0f) in the top left,
    // to (1.0f, 1.0f) in the bottom right of the texture, so this will use the
    // entire texture to cover the entire rectangle.
    static const simd_float2 textureCoordinates[] = {
        { 0.0f, 0.0f } ,
        { 1.0f, 0.0f },
        { 0.0f, 1.0f },
        { 1.0f, 1.0f },
    };
    
    _textureCoordinates =
    [device newBufferWithBytes:textureCoordinates
                        length:sizeof(textureCoordinates)
                       options:MTLResourceStorageModeShared];
}

- (void)setUpPipelineWithDevice:(id<MTLDevice>)device
{
    _commandQueue = nil;
    _pipelineState = nil;
    _renderPassDescriptor = nil;
    if(!device) {
        return;
    }
    
    // Store the a command queue for later use..
    _commandQueue = [device newCommandQueue];
        
    // Make a pipeline descriptor with out fragment and vertex programs.
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = @"ColoursPipeline";
    pipelineDescriptor.vertexFunction = _vertexProgram;
    pipelineDescriptor.fragmentFunction = _fragmentProgram;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.view.pixelFormat;
    
    // Set up for blending with premultiplied alpha (our textures, from
    // CGBitmapContexts, have premultiplied alpha).
    pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    NSError *error;
    _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                            error:&error];
    if(!_pipelineState)
    {
        NSLog(@"ERROR: Failed aquiring pipeline state: %@", error);
        return;
    }
    
    // Makle a render pass descriptor - we'll reuse it on every render.
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
    _renderPassDescriptor = renderPassDescriptor;
}

@end
