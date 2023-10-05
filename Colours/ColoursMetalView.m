//
//  ColoursMetalView.m
//  Colours
//
//  Created by Jamie Montgomerie on 10/4/23.
//  Copyright © 2023 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import "ColoursMetalView.h"
#import "ColoursNotificationCenterAdditions.h"

@interface ColoursMetalView ()
@property (nonatomic, readonly, strong) CAMetalLayer *layer;
@end

@implementation ColoursMetalView {
    BOOL _haveCalledDeviceCallback;
    CADisplayLink *_displayLink;
    NSArray *_backgroundingObservers;
}

@dynamic layer;

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    if(newWindow != self.window) {
        if(self.window) {
            if(_backgroundingObservers) {
                NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
                [_backgroundingObservers enumerateObjectsUsingBlock:^(id observer, NSUInteger idx, BOOL *stop) {
                    [notificationCenter removeObserver:observer];
                }];
                _backgroundingObservers = nil;
            }
            
            [_displayLink invalidate];
            _displayLink = nil;
        }
        
        if(newWindow)
        {
            id<MTLDevice> newDevice = self.layer.preferredDevice;
            if(self.layer.device != newDevice || !_haveCalledDeviceCallback) {
                self.layer.device = newDevice;
                [self.delegate coloursMetalView:self didSwitchToMTLDevice:newDevice];
                _haveCalledDeviceCallback = YES;
            }
            self.layer.framebufferOnly = YES;
            
            NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
            UIScene *scene = newWindow.windowScene;
            _backgroundingObservers = @[
                [notificationCenter addObserver:self selector:@selector(sceneWillEnterForeground) forName:UISceneWillEnterForegroundNotification object:scene],
                [notificationCenter addObserver:self selector:@selector(sceneDidEnterBackground) forName:UISceneDidEnterBackgroundNotification object:scene],
            ];
            
            _displayLink = [newWindow.screen displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
            _displayLink.paused = _paused;
            _displayLink.preferredFramesPerSecond = 60;
            [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        } else {
            self.layer.device = nil;
            if(_haveCalledDeviceCallback) {
                [self.delegate coloursMetalView:self didSwitchToMTLDevice:nil];
            }
        }
    }
}

- (void)sceneDidEnterBackground
{
    _displayLink.paused = YES;
}

- (void)sceneWillEnterForeground
{
    _displayLink.paused = _paused;
}

- (void)setPaused:(BOOL)paused
{
    _paused = paused;
    _displayLink.paused = paused;
}

- (void)_resizeDrawable:(CGFloat)scaleFactor
{
    CGSize newSize = self.bounds.size;
    newSize.width *= scaleFactor;
    newSize.height *= scaleFactor;

    if(CGSizeEqualToSize(newSize, self.layer.drawableSize)) {
        return;
    }
    
    self.layer.drawableSize = newSize;
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
    [super setContentScaleFactor:contentScaleFactor];
    [self _resizeDrawable:self.window.screen.nativeScale];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self _resizeDrawable:self.window.screen.nativeScale];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self _resizeDrawable:self.window.screen.nativeScale];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self _resizeDrawable:self.window.screen.nativeScale];
}

- (void)displayLinkDidFire:(CADisplayLink *)displayLink
{
    [self.delegate coloursMetalView:self
                 renderToMetalLayer:self.layer
                     forDisplayLink:displayLink];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPixelFormat
{
    return [NSSet setWithObjects:@"layer.pixelFormat", nil];
}

- (MTLPixelFormat)pixelFormat
{
    return self.layer.pixelFormat;
}

@end
