//
//  ColoursMetalView.h
//  Colours
//
//  Created by Jamie Montgomerie on 10/4/23.
//  Copyright © 2023 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ColoursMetalViewDelegate;

@interface ColoursMetalView : UIView

@property (nonatomic, weak, nullable) IBOutlet id<ColoursMetalViewDelegate> delegate;
@property (nonatomic, assign, getter=isPaused) BOOL paused;
@property (nonatomic, assign) MTLPixelFormat pixelFormat;

@end

@protocol ColoursMetalViewDelegate <NSObject>

@required
- (void)coloursMetalView:(ColoursMetalView *)view renderToMetalLayer:(CAMetalLayer *)layer forDisplayLink:(CADisplayLink *)displayLink;
- (void)coloursMetalView:(ColoursMetalView *)view didSwitchToMTLDevice:(nullable id<MTLDevice>)device;

@end

NS_ASSUME_NONNULL_END
