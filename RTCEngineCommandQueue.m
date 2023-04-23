//
//  RTCCommandQueue.m
//  RTCEngine
//
//  Created by ymluo on 2018/12/21.
//  Copyright © 2018 ymluo. All rights reserved.
//

#import "RTCEngineCommandQueue.h"
// #import "RTCEngineLogUtil.h"

#import "RTCLYMEnginTimer.h"

//#define floader  [APP_DOCPATH stringByAppendingPathComponent:@"log"]

typedef void(^dataCB)(NSDictionary * _Nonnull jsonData);
@interface RTCEngineCommandQueue ()
//@property(nonatomic,strong)NSMutableDictionary<NSString*,id>* listenners;
@property(nonatomic,assign)BOOL isClosed;
@property(nonatomic,assign)BOOL busy;
@property(nonatomic,strong)NSMutableArray<NSMutableDictionary*>* queues;
@property(nonatomic,strong) RTCLYMEnginTimer* timerProxys;
@property(nonatomic,assign)int timerCount;
@property(nonatomic, strong)  dispatch_queue_t queueThread;

@property(nonatomic, strong) NSLock *lock;
@end

@implementation RTCEngineCommandQueue
-(instancetype)init{
    if(self=[super init]){
        _lock = [[NSLock alloc]init];
        _queueThread = dispatch_queue_create("com.vrv.mediasoup.commonQueue", DISPATCH_QUEUE_SERIAL);

    }
    return self;
}
//-(NSMutableDictionary<NSString *,id> *)listenners{
//    if (!_listenners) {
//        _listenners = [NSMutableDictionary dictionary];
//    }
//    return _listenners;
//}
-(NSMutableArray<NSMutableDictionary *> *)queues{
    if (!_queues) {
        _queues = [NSMutableArray array];
    }
    return _queues;
}
-(void)pushWithMethod:(NSString *)method argData:(NSDictionary *)argData dataCB:(void (^)(NSDictionary * _Nonnull))dataCB{
    NSString *log = [NSString stringWithFormat:@"pushWithMethod() [method:%@] currentThread:%@",method,[NSThread currentThread]];
    [self rtc_writeLogFileWithMsg:log line:__LINE__];
    if (argData==nil && dataCB == nil) {//防止空值崩溃
        NSString *log = [NSString stringWithFormat:@"pushWithMethod() [error:%@ dataCB:%@]",method.description,dataCB];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        return;
    }
    NSMutableDictionary *json = [[NSMutableDictionary alloc]initWithDictionary:@{@"method":method}];
    [json setObject:@[dataCB] forKey:@"CB"];
    [json setObject:@[argData] forKey:@"arg"];
    [_lock tryLock];
    [self.queues addObject:json];//将所有方法名与参数缓存起来
    [_lock unlock];
    [self _handlePendingConmands];

}

- (void)_handlePendingConmands{
    if (_isClosed) {
        NSString *log = [NSString stringWithFormat:@"_handlePendingConmands() commandQueue is _isClosed [method:%@]",@(_queues.count)];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        return;
    }
    [_lock tryLock];
    if (_busy) {
        NSString *log = [NSString stringWithFormat:@"_handlePendingConmands() commandQueue is busy [method:%@]",@(_queues.count)];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        [_lock unlock];
        return;
    }
    if (_queues.count == 0) {
        NSString *log = [NSString stringWithFormat:@"_handlePendingConmands() commandQueue is not method"];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        [_lock unlock];
        return;
    }
    NSMutableDictionary *conmand = _queues.firstObject;//取出缓存的第一个方法
    if (!conmand) {
        NSString *log = [NSString stringWithFormat:@"_handlePendingConmands() commandQueue is not conmand method"];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        [_lock unlock];
        return;
    }
    dataCB cb = [(dataCB)conmand[@"CB"] firstObject];
    NSString *method = conmand[@"method"];
    NSDictionary *arg = [conmand[@"arg"] firstObject];
    _busy = YES;
    [_lock unlock];

    [self _handleConmandWithMethod:method argData:arg callback:cb];
    
    //    }
    
}
- (void)_handleConmandWithMethod:(NSString*)methodName argData:(NSDictionary *)argData callback:(dataCB)cb{
    if (self.isClosed) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [_lock tryLock];
    if (!self.timerProxys) {
        //        self.timerProxys = [NSTimer scheduledTimerWithTimeInterval:1.0f
        //                                                            target:self
        //                                                          selector:@selector(timerDidFire:)
        //                                                          userInfo:nil
        //                                                           repeats:YES];
        //        [self.timerProxys fire];
        //        [[NSRunLoop currentRunLoop] addTimer:_timerProxys forMode:NSRunLoopCommonModes];
        NSString *timerProxysbeginLog = [NSString stringWithFormat:@"_handleConmandWithMethod() timer  [methodName:%@]",methodName];
        [self rtc_writeLogFileWithMsg:timerProxysbeginLog line:__LINE__];
        self.timerProxys = [RTCLYMEnginTimer timerWithTask:^(NSInteger count) {
            __strong typeof(weakSelf) stongSelf = weakSelf;
            [stongSelf timerDidFireWithCnt:count];
        } startInterval:1.0f interbal:1.f repeat:YES async:YES];
        
    }
    [_lock unlock];
    if ([NSThread isMainThread]) {
        NSString *log = [NSString stringWithFormat:@"_handleConmandWithMethod() 不能在主线程回调 currentThread:%@ method：%@ ",[NSThread currentThread],methodName];
        [self rtc_writeErrLogFileWithMsg:log line:__LINE__];
    
        dispatch_async(_queueThread, ^{
            __strong typeof(weakSelf) stongSelf = weakSelf;
            [stongSelf _handleConmandWithMethod:methodName argData:argData callback:cb];
        });
        
        return;
    }
    //这里提交到外部，然后外面返回后继续执行下一个方法
    if (self.delegate && [self.delegate respondsToSelector:@selector(engineCommandQueueWithMethod:argData:executionMethodResoultCB:)]) {
        [self.delegate engineCommandQueueWithMethod:methodName argData:argData executionMethodResoultCB:^(id resp, id  error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf.lock tryLock];
            if (strongSelf.isClosed) {
                NSString *log = [NSString stringWithFormat:@"_handleConmandWithMethod() commandQueue is closed"];
                [strongSelf rtc_writeErrLogFileWithMsg:log line:__LINE__];
                [strongSelf.lock unlock];
                return;
            }
            [strongSelf.lock unlock];
            if (cb) {
                cb(resp);//同时通知与之相对应的缓存回调方法
            }
            [strongSelf executionMethodNext];
        }];
        
    }else{
        NSString *log = [NSString stringWithFormat:@"_handleConmandWithMethod() delegate is null  currentThread:%@ method：%@ ",[NSThread currentThread],methodName];
        [self rtc_writeErrLogFileWithMsg:log line:__LINE__];
    }
    
}
- (void)executionMethodNext{
    if ([NSThread isMainThread]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(_queueThread, ^{
            __strong typeof(weakSelf) stongSelf = weakSelf;
            [stongSelf executionMethodNext];
        });
        return;
    }
    NSString *beginLog = [NSString stringWithFormat:@"executionMethodNext(begin) commandQueue [method:%@]",@(self.queues.count)];
    [self rtc_writeLogFileWithMsg:beginLog line:__LINE__];
    [self.lock tryLock];
    if (_isClosed) {
        [self.lock unlock];
        NSString *errLog = [NSString stringWithFormat:@"executionMethodNext() commandQueue is closed"];
        [self rtc_writeErrLogFileWithMsg:errLog line:__LINE__];
        return;
    }
    [self.timerProxys cancle];
    self.timerCount = 0;
    self.timerProxys = nil;
    self.busy = NO;
    if (self.queues.count > 0) {
        [self.queues removeObjectAtIndex:0];
    }
    if (_queues) {
        [self.lock unlock];
        NSString *log = [NSString stringWithFormat:@"removeObjectAtIndex() commandQueue [method:%@]",@(self.queues.count)];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
        [self _handlePendingConmands];
    }else{
        [self.lock unlock];
    }
    NSString *endlog = [NSString stringWithFormat:@"executionMethodNext(end) commandQueue [method:%@]",@(self.queues.count)];
    [self rtc_writeLogFileWithMsg:endlog line:__LINE__];
}
-(void)timerDidFireWithCnt:(NSInteger)count{
    self.timerCount ++;
    if (_timerCount % 3 == 0) {
        NSString *log = [NSString stringWithFormat:@"timerDidFire() [waiting 3s count:%ld time count:%@  queue:%@] currentThread:%@ ",(long)_timerCount,@(count),_queues,[NSThread currentThread]];
        [self rtc_writeLogFileWithMsg:log line:__LINE__];
    }
    //    NSLog(@"_timerCount:%ld",_timerCount);
    if (_timerCount > 30) {//超时后，继续执行下一个方法
        // 到达超时时间执行下一个
        [self executionMethodNext];
        NSString *log = [NSString stringWithFormat:@"timerDidFire() timeout "];
        [self rtc_writeErrLogFileWithMsg:log line:__LINE__];
    }
}
- (void)rtc_writeLogFileWithMsg:(NSString*)logInfo line:(NSInteger)line{
    if (self.logPath) {
        // [RTCEngineLogUtil debug:logInfo file:__FILE__ line:(int)line onFolder:self.logPath print:YES];
    }
}
- (void)rtc_writeErrLogFileWithMsg:(NSString*)logInfo line:(NSInteger)line{
    if (self.logPath) {
        // [RTCEngineLogUtil error:logInfo file:__FILE__ line:(int)line onFolder:self.logPath print:YES];
    }
}
- (void)dealloc{
    NSLog(@"RTCEngineCommandQueue dealloc()");
    //    [RTCEngineLogUtil debug:@"dealloc()" file:__FILE__ line:__LINE__ onFolder:floader print:YES];
}
-(void)close{
    [_lock tryLock];
    self.isClosed = YES;
//    if (_listenners) {
//        [_listenners removeAllObjects];
//        self.listenners=nil;
//    }
    if (self.timerProxys) {
        self.timerCount = 0;
        [self.timerProxys cancle];
        self.timerProxys = nil;
    }
    if (_queues) {
        [_queues removeAllObjects];
        _queues = nil;
    }
    [_lock unlock];
}
@end
