//
//  FULogKit.h
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import <Foundation/Foundation.h>

//! Project version number for FULogKit.
FOUNDATION_EXPORT double FULogKitVersionNumber;

//! Project version string for FULogKit.
FOUNDATION_EXPORT const unsigned char FULogKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <FULogKit/PublicHeader.h>

#import <FULogKit/FULogInfo.h>
#import <FULogKit/FUMMapUtil.h>

@interface FULogKit : NSObject

- (instancetype)init __attribute__((unavailable("init is not available")));

/**
 * note 该函数会验证服务器可用性和同步NTP时间，所以需要网络，没网会同步失败. 会有log提示
 * 配置FUlogKit 运行的必要的信息
 * block:  NO, 配置失败，YES 成功
 */
+ (void)configWithInfo:(FULogInfo *)info
              callback:(void(^)(BOOL res))callback;

/**
 * 放入缓存池，内部从缓存池取出一条一条上传
 * 日志上传接口
 * log 待上传的字符串
 */
+ (void)uploadLog:(NSDictionary *)log;

/**
 * 立即上传，并不放入缓存池
 * 日志上传接口
 * log 待上传的字符串
 * callback 上传服务器回调结果
 */
+ (void)uploadLog:(NSDictionary *)log callback:(void(^)(BOOL res, NSError *error))callback;

/**
 *  NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler); 是全局捕获异常句柄，
 *  该接口主要是针对其他地方也注册了 NSSetUncaughtExceptionHandler 句柄导致库内的 被覆盖，可用于重新开启和关闭句柄
 *  初始化时会默认调用一次
 */
+ (void)setOCUncaugtException;

//销毁内存
+ (void)destroy;
@end
