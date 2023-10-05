//
//  ColoursAppDelegate.m
//  Colours
//
//  Created by James Montgomerie on 23/09/2011.
//  Copyright 2011 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import "ColoursAppDelegate.h"
#import "ColoursViewController.h"

@implementation ColoursAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window.rootViewController = self.viewController;
    return YES;
}

@end
