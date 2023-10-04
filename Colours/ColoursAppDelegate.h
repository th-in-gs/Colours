//
//  ColoursAppDelegate.h
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ColoursViewController;

@interface ColoursAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet ColoursViewController *viewController;

@end
