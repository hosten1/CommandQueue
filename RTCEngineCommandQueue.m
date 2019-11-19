//
//  RTCCommandQueue.m
//  RTCEngine
//
//  Created by ymluo on 2018/12/21.
//  Copyright © 2018 ymluo. All rights reserved.
//

#import "RTCEngineCommandQueue.h"
#import "RTCEngineLogUtil.h"
//#define floader  [APP_DOCPATH stringByAppendingPathComponent:@"log"]

typedef void(^dataCB)(NSDictionary * _Nonnull jsonData);
@interface RTCEngineCommandQueue ()
@property(nonatomic,strong)NSMutableDictionary<NSString*,id>* listenners;
@property(nonatomic,assign)BOOL isClosed;
@property(nonatomic,assign)BOOL busy;
@property(nonatomic,strong)NSMutableArray<NSMutableDictionary*>* queues;
@property(nonatomic,strong) NSTimer* timerProxys;
@property(nonatomic,assign)int timerCount;

@end

@implementation RTCEngineCommandQueue
-(NSMutableDictionary<NSString *,id> *)listenners{
    if (!_listenners) {
        _listenners = [NSMutableDictionary dictionary];
    }
    return _listenners;
}
-(NSMutableArray<NSMutableDictionary *> *)queues{
    if (!_queues) {
        _queues = [NSMutableArray array];
    }
    return _queues;
}
-(void)pushWithMethod:(NSString *)method argData:(NSDictionary *)argData dataCB:(void (^)(NSDictionary * _Nonnull))dataCB{
    NSString *log = [NSString stringWithFormat:@"pushWithMethod() [method:%@]",method];
    [self rtc_writeLogFileWithMsg:log line:__LINE__];
    if (argData==nil && dataCB == nil) {//防止空值崩溃
        NSString *log = [NSString stringWithFormat:@"pushWithMethod() [error:%@ dataCB:%@]",method.description,dataCB];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        return;
    }
    NSMutableDictionary *json = [[NSMutableDictionary alloc]initWithDictionary:@{@"method":method}];
    [json setObject:@[dataCB] forKey:@"CB"];
    [json setObject:@[argData] forKey:@"arg"];
    [self.queues addObject:json];//将所有方法名与参数缓存起来
    [self _handlePendingConmands];
}

- (void)_handlePendingConmands{
    @synchronized (self) {
        if (_isClosed) {
            return;
        }
        //    @autoreleasepool {
        if (_busy) {
            NSString *log = [NSString stringWithFormat:@"_handlePendingConmands() commandQueue is busy [method:%@]",_queues.description];
            [self rtc_writeLogFileWithMsg:log line:__LINE__];
            return;
        }
        if (_queues.count == 0) {
            NSString *log = [NSString stringWithFormat:@"_handlePendingConmands() commandQueue is not method"];
            [self rtc_writeLogFileWithMsg:log line:__LINE__];
            return;
        }
        NSMutableDictionary *conmand = _queues.firstObject;//取出缓存的第一个方法
        if (!conmand) {
            return;
        }
        dataCB cb = [(dataCB)conmand[@"CB"] firstObject];
        NSString *method = conmand[@"method"];
        NSDictionary *arg = [conmand[@"arg"] firstObject];
        _busy = YES;
        [self _handleConmandWithMethod:method argData:arg callback:cb];
    }
    
    //    }
    
}
- (void)_handleConmandWithMethod:(NSString*)method argData:(NSDictionary *)argData callback:(dataCB)cb{
    if (self.isClosed) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    if (!self.timerProxys) {
        self.timerProxys = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                            target:self
                                                          selector:@selector(timerDidFire:)
                                                          userInfo:nil
                                                           repeats:YES];
        [self.timerProxys fire];
        [[NSRunLoop currentRunLoop] addTimer:_timerProxys forMode:NSRunLoopCommonModes];
        
    }
    
    //这里提交到外部，然后外面返回后继续执行下一个方法
    if (self.delegate && [self.delegate respondsToSelector:@selector(engineCommandQueueWithMethod:argData:executionMethodResoultCB:)]) {
        [self.delegate engineCommandQueueWithMethod:method argData:argData executionMethodResoultCB:^(id resp, id  error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf.isClosed) {
                return;
            }
            if (cb) {
                cb(resp);//同时通知与之相对应的缓存回调方法
            }
            [strongSelf executionMethodNext];
        }];
        
    }
    
}
- (void)executionMethodNext{
    if (_isClosed) {
        return;
    }
    [self.timerProxys invalidate];
    self.timerCount = 0;
    self.timerProxys = nil;
    self.busy = NO;
    if (self.queues.count > 0) {
        [self.queues removeObjectAtIndex:0];
    }
    if (_queues) {
        NSString *log = [NSString stringWithFormat:@"removeObjectAtIndex() commandQueue [method:%@]",self.queues.description];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        [self _handlePendingConmands];
    }
}
-(void)timerDidFire:(NSTimer*)timer{
    _timerCount ++;
    if (_timerCount % 3 == 0) {
        NSString *log = [NSString stringWithFormat:@"timerDidFire() [count:%ld time:%@]",(long)_timerCount,timer.description];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
    }
    //    NSLog(@"_timerCount:%ld",_timerCount);
    if (_timerCount > 8) {//超时后，继续执行下一个方法
        [_timerProxys invalidate];
        _timerCount = 0;
        _timerProxys = nil;
        _busy = NO;
        if (self.queues.count > 0) {
            [self.queues removeObjectAtIndex:0];
            [self _handlePendingConmands];
        }
        NSString *log = [NSString stringWithFormat:@"timerDidFire() timeout "];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
    }
}
- (void)rtc_writeLogFileWithMsg:(NSString*)logInfo line:(NSInteger)line{
    if (self.logPath) {
        [RTCEngineLogUtil error:logInfo file:__FILE__ line:__LINE__ onFolder:self.logPath print:YES];
    }
}
- (void)dealloc{
    NSLog(@"RTCEngineCommandQueue dealloc()");
    //    [RTCEngineLogUtil debug:@"dealloc()" file:__FILE__ line:__LINE__ onFolder:floader print:YES];
}
-(void)close{
    self.isClosed = YES;
    if (_listenners) {
        [_listenners removeAllObjects];
        self.listenners=nil;
    }
    if (self.timerProxys) {
        self.timerCount = 0;
        [self.timerProxys invalidate];
        self.timerProxys = nil;
    }
    if (_queues) {
        [_queues removeAllObjects];
        _queues = nil;
    }
}
@end
