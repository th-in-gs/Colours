//
//  ColoursViewController.m
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import "ColoursViewController.h"
#import "EAGLView.h"

#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


static const GLfloat sIMacColors[5][4] = 
{
    { 0.0f,   0.725f, 1.0f,   1.0f }, // Bondi Blue
    { 0.431f, 0.063f, 1.0f,   1.0f }, // Grape
    { 1.0f,   0.275f, 0.031f, 1.0f }, // Tangerine
    { 0.114f, 1.0f,   0.227f, 1.0f }, // Lime
    { 1.0f,   0.0f,   0.302f, 1.0f } // Strawberry
};

@interface ColoursViewController () 

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) CADisplayLink *displayLink;

// Our texture
@property (nonatomic, assign) GLuint texture;
@property (nonatomic, assign) CGSize textureSize;

// Our compiled shader program
@property (nonatomic, assign) GLuint program;

// Shader attribute and uniform locations.
@property (nonatomic, assign) GLuint aPosition, aTextureCoordinate;
@property (nonatomic, assign) GLuint uPositioningMatrix, uTintColor;
@property (nonatomic, assign) GLuint sTexture;

- (BOOL)loadShaders;
- (BOOL)loadTexture;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)fileURL;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end



@implementation ColoursViewController


@synthesize animating, animationFrameInterval;
@synthesize context, displayLink;
@synthesize texture, textureSize;
@synthesize program;
@synthesize aPosition, aTextureCoordinate;
@synthesize uPositioningMatrix, uTintColor;
@synthesize sTexture;


- (void)awakeFromNib
{
    EAGLContext *aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!aContext) {
        NSLog(@"Failed to create ES context");
    } else if (![EAGLContext setCurrentContext:aContext]) {
        NSLog(@"Failed to set ES context current");
    }
    
	self.context = aContext;
	[aContext release];
	
    EAGLView *myEaglView = (EAGLView *)self.view;
    [myEaglView setContext:context];
    [myEaglView setFramebuffer];
    
    [self loadShaders];
    [self loadTexture];
    
    // Enable blending - we'll alpha blend.
    glEnable(GL_BLEND);
    
    // Our textures have premultiplied alpha, and (mainly as a result),
    // the shaders output premultiplied alpha.
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    animating = NO;
    
    // Default 30 fps - see comment in setAnimationFrameInterval:
    animationFrameInterval = 2;
}


- (void)dealloc
{
    if (animating) {
        [self stopAnimation];
    }
    
    if (program) {
        glDeleteProgram(program);
        program = 0;
    }
    
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    [context release];
    
    [super dealloc];
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}


- (void)viewWillAppear:(BOOL)animated
{
    [self startAnimation];
    
    [super viewWillAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [self stopAnimation];
    
    [super viewWillDisappear:animated];
}


- (void)viewDidUnload
{
	[super viewDidUnload];
	
    if (program) {
        glDeleteProgram(program);
        program = 0;
    }

    // Tear down context.
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
	self.context = nil;	
}


- (NSInteger)animationFrameInterval
{
    return animationFrameInterval;
}


- (void)setAnimationFrameInterval:(NSInteger)frameInterval
{
	 // Frame interval defines how many display frames must pass between each time the display link fires.
	 // The display link will only fire 30 times a second when the frame internal is two on a display that refreshes 60 times a second. 
     // The default frame interval setting of 2 will fire 30 times a second when the display refreshes at 60 times a second. 
     // A frame interval setting of less than one results in undefined behavior.
    if (frameInterval >= 1) {
        animationFrameInterval = frameInterval;
        
        if (animating) {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}


- (void)startAnimation
{
    if (!animating) {
        CADisplayLink *aDisplayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(drawFrame)];
        [aDisplayLink setFrameInterval:animationFrameInterval];
        [aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.displayLink = aDisplayLink;
        
        animating = YES;
    }
}


- (void)stopAnimation
{
    if (animating) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        
        animating = NO;
    }
}


- (void)drawFrame
{
    EAGLView *eaglView = (EAGLView *)self.view;
    [eaglView setFramebuffer];
    
    glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Use shader program.
    glUseProgram(program);
        
    
    // Update attribute values.
    
    // A big 2 X 2 rectangle centered around 0, 0.
    // We'll position it using a positioning matrix in the vertex shader.
    const GLfloat vertexPositions[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };

    glVertexAttribPointer(self.aPosition, 2, GL_FLOAT, 0, 0, vertexPositions);
    glEnableVertexAttribArray(self.aPosition);

    // The GL texture coordinates run from (0.0f, 0.0f) in the top left,
    // to (1.0f, 1.0f) in the bottom right of the texture, so this will use the 
    // entire texture to cover the entire rectangle.
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glVertexAttribPointer(self.aTextureCoordinate, 2, GL_FLOAT, 0, 0, textureCoordinates);
    glEnableVertexAttribArray(self.aTextureCoordinate);
    
    // Use our iMac texture.
    glUniform1i(sTexture, 1);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, texture);

    // Work out the matrix to position the iMac on the screen 
    CATransform3D staticPositioningTransform = CATransform3DIdentity;
    CGSize myBoundsSize = self.view.bounds.size;
    CGSize myTextureSize = self.textureSize;
    
    // Move the iMac down from the center of the screen
    CATransform3D moveDown = CATransform3DMakeTranslation(0.0f, -1.5f, 0.0f);
    staticPositioningTransform = CATransform3DConcat(staticPositioningTransform, moveDown);

    // Scale the 2-by-2 vertexPositions rectangle into the aspect ratio
    // of the texture.  We scale the height to be correct in terms of the 
    // width.
    CATransform3D correctAspectRatio = CATransform3DMakeScale(1.0f, 
                                                              myTextureSize.height / myTextureSize.width,
                                                              1.0f);
    staticPositioningTransform = CATransform3DConcat(staticPositioningTransform, correctAspectRatio);
    
    // Now, rotate it.  1/4 a rotation per second. around 
    // the Z axis (i.e. the axis pointing 'through' the screen).
    // This will cause a rotation around (0.0, 0.0).
    CATransform3D rotate = CATransform3DMakeRotation((M_PI * 0.5f) * self.displayLink.timestamp, 
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
    CATransform3D scaleToSize = CATransform3DMakeScale(textureSize.width / myBoundsSize.width, 
                                                       textureSize.width / myBoundsSize.height,
                                                       1.0f);
    
    // Lastly, we'll scale the whole scene up or down to fit our entire circle
    // of iMacs on the screen (turns out this means we need to scale to fit 4
    // iMacs across the width of the screen, so we work out the scale factor
    // required to do that).
    CGFloat screenScale = MAX(myBoundsSize.width / textureSize.width,
                              myBoundsSize.height / textureSize.height);
    CATransform3D scaleToScreen = CATransform3DMakeScale(screenScale / 4.0f, 
                                                         screenScale / 4.0f,
                                                         1.0f);
    scaleToSize = CATransform3DConcat(scaleToSize, scaleToScreen);
    
    // The angle 'between' each iMac in the circle. 
    CGFloat iMacSegmentAngle = - 2.0f * (CGFloat)M_PI / 5.0f;
    
    for(NSUInteger i = 0; i < 5; ++i) {
        CATransform3D thisIMacPositioningTransform = staticPositioningTransform;

        // Rotate this iMac into its individual place in the circle
        CATransform3D rotateIntoPlace =  CATransform3DMakeRotation(i * iMacSegmentAngle, 0.0f, 0.0f, 1.0f);
        thisIMacPositioningTransform = CATransform3DConcat(thisIMacPositioningTransform, rotateIntoPlace);
        
        // Finally scale to pixel size using the scale factor using the matrix 
        // we calculated above.
        thisIMacPositioningTransform = CATransform3DConcat(thisIMacPositioningTransform, scaleToSize);
        
        // Upload the matrix.
        glUniformMatrix4fv(self.uPositioningMatrix, 1, GL_FALSE, (GLfloat *)&thisIMacPositioningTransform);
        
        // Per-iMac tint color
        glUniform4fv(self.uTintColor, 1, sIMacColors[i]);
        
        // Validate program before drawing. This is a good check, but only really necessary in a debug build.
        // DEBUG macro must be defined in your debug configurations if that's not already the case.
    #if defined(DEBUG)
        if (![self validateProgram:program]) {
            NSLog(@"Failed to validate program: %d", program);
            return;
        }
    #endif
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    [eaglView presentFramebuffer];
}


- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)fileURL
{
    GLint status;
    
    NSData *source = [NSData dataWithContentsOfURL:fileURL];
    if (!source)
    {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    const GLchar *shaderSource = source.bytes;
    const GLint shaderSourceLength = source.length;
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &shaderSource, &shaderSourceLength);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}


- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0)
        return NO;
    
    return YES;
}


- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0)
        return NO;
    
    return YES;
}


- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    
    // Create shader program.
    self.program = glCreateProgram();
    
    // Create and compile vertex shader.
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:[[NSBundle mainBundle] URLForResource:@"Colours" withExtension:@"vsh"]])
    {
        glDeleteProgram(program);
        self.program = 0;
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:[[NSBundle mainBundle] URLForResource:@"Colours" withExtension:@"fsh"]])
    {
        glDeleteProgram(program);
        self.program = 0;
        glDeleteShader(vertShader);
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach the shaders to the program.
    glAttachShader(program, vertShader);
    glAttachShader(program, fragShader);
        
    // Link program.
    if (![self linkProgram:program])
    {
        glDeleteShader(vertShader);
        glDeleteShader(fragShader);
        glDeleteProgram(program);
        self.program = 0;
        NSLog(@"Failed to link program: %d", program);
        return NO;
    }
    
    // Release vertex and fragment shaders - they're linked in to the program now.
    glDeleteShader(vertShader);
    glDeleteShader(fragShader);
    
    // Get the attribute and uniform locations from the linked program.
    self.aPosition = glGetAttribLocation(program, "aPosition");
    self.aTextureCoordinate = glGetAttribLocation(program, "aTextureCoordinate");
    
    self.uPositioningMatrix = glGetUniformLocation(program, "uPositioningMatrix");
    self.uTintColor = glGetUniformLocation(program, "uTintColor");
    
    self.sTexture = glGetUniformLocation(program, "sTexture");
    
    return YES;
}


- (BOOL)loadTexture
{
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
    CGColorSpaceRef deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef textureContext = 
        CGBitmapContextCreate(textureRGBAData, 
                              imagePixelSize.width, imagePixelSize.height, 
                              8, 
                              imagePixelSize.width * 4,
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
        
    GLuint myTexture = 0;
    glGenTextures(1, &myTexture);
    
    glBindTexture(GL_TEXTURE_2D, myTexture); 
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 
                 imagePixelSize.width, imagePixelSize.height, 0, 
                 GL_RGBA, GL_UNSIGNED_BYTE, textureRGBAData);
        
    // Scale the texture with a linear scaling function if we're not
    // viewing it 1:1 pixels.
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);    
    
    // If we try to use a pixel that's off the edge of the texture, this will
    // use the nearest edge pixel instead.
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // We're done with the texture data now, OpenGL has kept a copy.
    free(textureRGBAData);
    
    self.texture = myTexture;
    self.textureSize = imageSize; // Size in points, not pixels.
    
    return YES;
}


@end
