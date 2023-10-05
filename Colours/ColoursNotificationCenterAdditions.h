//
//  ColoursNotificationCenterAdditions.h
//  Colours
//
//  Created by Jamie Montgomerie on 10/4/23.
//  Copyright © 2023 Things Made Out Of Other Things Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNotificationCenter (ColoursNotificationCenterAdditions)

- (id <NSObject>)addObserver:(id)observer selector:(SEL)selector forName:(nullable NSNotificationName)name object:(nullable id)obj;

@end

NS_ASSUME_NONNULL_END
