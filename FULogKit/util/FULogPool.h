//
//  FULogPool.h
//  FULogKit
//
//  Created by lsh726 on 2024/4/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 * 日志缓存池，目的保证多线程并发情况下，安全的存取缓存数据
 */
@interface FULogPool : NSObject

//添加到缓存池
- (void)addLog:(NSDictionary *)log;

//从缓存池弹出
- (NSDictionary *)popLog;
@end

NS_ASSUME_NONNULL_END
