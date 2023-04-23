//
//  LYMTimer.h
//  TestTimer
//
//  Created by ymluo on 2019/12/9.
//  Copyright © 2019 ymluo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RTCLYMEnginTimer : NSObject
- (void) execTimerWithTask:(void (^)(NSInteger count))task startInterval:(NSTimeInterval)startInterval interbal:(NSTimeInterval)interbal repeat:(BOOL)repeat async:(BOOL)async;
+ (instancetype) timerWithTask:(void (^)(NSInteger count))task startInterval:(NSTimeInterval)startInterval interbal:(NSTimeInterval)interbal repeat:(BOOL)repeat async:(BOOL)async;
- (void)cancle;
@end

NS_ASSUME_NONNULL_END
