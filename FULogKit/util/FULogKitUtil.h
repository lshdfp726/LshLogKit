//
//  FULogKitUtil.h
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FULogKitUtil : NSObject
//校验域名是否合法，内部 getaddrinfo 函数返回的数据，线程不安全，需要锁住临界区
+ (BOOL)isVaildHostUrl:(NSString *)hostUrl;

//校验目录是否存在
+ (BOOL)isVaildDir:(NSString *)dir;

//创建文件
+ (BOOL)createFileWithPath:(NSString *)path;

//NTP服务器获取准确的世界时间,并且转为Unix时间戳内部 getaddrinfo 函数返回的数据线程不安全，需要锁住临界区
+ (time_t)getTimeFromNTP;

//时间戳转时间字符串，只转换到天，不含小时
+ (NSString *)timeStampToStr:(time_t)timeStamp;

//获取设备时间
+ (NSTimeInterval)getDeviceTimeStamp;
@end

NS_ASSUME_NONNULL_END
