//
//  FUNetWorkReachhabilityUtil.h
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import <Foundation/Foundation.h>

@protocol FUNetWorkReachhabilityProtocol <NSObject>

- (void)networkChange:(BOOL)reachability;

@end

NS_ASSUME_NONNULL_BEGIN

@interface FUNetWorkReachhabilityUtil : NSObject
//检测网络可用性
- (BOOL)isNetworkAvaiable;

//开始监听网络
- (void)startListenNetworkChangeWithDelegate:(id<FUNetWorkReachhabilityProtocol>)delegate;
//停止监听网络
- (void)stopListen;
@end

NS_ASSUME_NONNULL_END
