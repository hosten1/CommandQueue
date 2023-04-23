//
//  LYMTimer.m
//  TestTimer
//
//  Created by ymluo on 2019/12/9.
//  Copyright © 2019 ymluo. All rights reserved.
//

#import "RTCLYMEnginTimer.h"
@interface RTCLYMEnginTimer ()

@property (nonatomic, strong) dispatch_source_t timer;  //!<计时器资源
@property (nonatomic, assign) NSInteger timerCount;     //!<计时


@end
@implementation RTCLYMEnginTimer
+ (instancetype)timerWithTask:(void (^)(NSInteger))task startInterval:(NSTimeInterval)startInterval interbal:(NSTimeInterval)interval repeat:(BOOL)repeat async:(BOOL)async{
    RTCLYMEnginTimer *timer = [[RTCLYMEnginTimer alloc]init];
    [timer execTimerWithTask:task startInterval:startInterval interbal:interval repeat:repeat async:async];
    
    return timer;
}
-(instancetype)init{
    if (self=[super init]) {
        self.timerCount = 0;
    }
    return self;
}
- (void) execTimerWithTask:(void (^)(NSInteger count))task startInterval:(NSTimeInterval)startInterval interbal:(NSTimeInterval)interval repeat:(BOOL)repeat async:(BOOL)async{
    if (!task) {
        return;
    }
    // 是否异步，异步则开启新队列，负责就在主队列中执行
    dispatch_queue_t queue = async ? dispatch_queue_create("com.lym.timer", DISPATCH_QUEUE_CONCURRENT) : dispatch_get_main_queue();
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, startInterval * NSEC_PER_SEC, interval * NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (repeat) {
            strongSelf.timerCount ++;
            task(strongSelf.timerCount);
        }else{
            strongSelf.timerCount ++;
            task(strongSelf.timerCount);
            [strongSelf cancle];
        }
//        NSLog(@"======== 计时开始 ========");
    });
    //启动定时器
    dispatch_resume(_timer);
}
- (void)cancle{
    dispatch_source_cancel(_timer);
    self.timerCount = 0;
}
@end
