//
//  RTCCommandQueue.h
//  RTCEngine
//
//  Created by ymluo on 2018/12/21.
//  Copyright © 2018 ymluo. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol RTCEngineCommandQueueDelegate <NSObject>

-(void)engineCommandQueueWithMethod:(NSString*)method argData:(NSDictionary*)arg executionMethodResoultCB:(void(^)( id  _Nullable resp, id _Nullable error))dataCallback;

@end
@interface RTCEngineCommandQueue :NSObject
@property(nonatomic,weak,nullable)id<RTCEngineCommandQueueDelegate> delegate;
@property(nonatomic,copy)NSString *logPath;
- (void)pushWithMethod:(NSString*)method argData:(nonnull NSDictionary*)argData dataCB:(void (^)( NSDictionary *respData))dataCB;
- (void)close;
@end

NS_ASSUME_NONNULL_END
