//
//  ColoursSceneDelegate.m
//  Colours
//
//  Created by Jamie Montgomerie on 10/5/23.
//

#import "ColoursSceneDelegate.h"
#import "ColoursViewController.h"

@implementation ColoursSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    NSParameterAssert([session.configuration.name isEqualToString:@"Default Configuration"]);
    _window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    
    ColoursViewController *viewController = [[ColoursViewController alloc] initWithNibName:@"ColoursViewController" bundle:nil];
    _window.rootViewController = viewController;
    
    [_window makeKeyAndVisible];
}

@end
