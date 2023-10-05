//
//  ColoursNotificationCenterAdditions.m
//  Colours
//
//  Created by Jamie Montgomerie on 10/4/23.
//  Copyright © 2023 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import "ColoursNotificationCenterAdditions.h"
#import <objc/message.h>

@implementation NSNotificationCenter (ColoursNotificationCenterAdditions)

- (id <NSObject>)addObserver:(id)observer selector:(SEL)selector forName:(nullable NSNotificationName)name object:(nullable id)obj
{
    __weak id wObserver = observer;
    return [self addObserverForName:name object:obj queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        ((void(*)(id, SEL, NSNotification*))objc_msgSend)(wObserver, selector, notification);
    }];
}

@end
