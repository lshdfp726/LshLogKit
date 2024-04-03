//
//  FULogInfo.h
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 * 配置FULogKit 所需的一些信息
 */
@interface FULogInfo : NSObject
/**
 * hostUrl 上传服务器域名
 * savePath，保存本地日志目录,FULogKit 会在该目录下创建日志文件
 */
+ (instancetype)configWithHostUrl:(NSString *)hostUrl
                          saveDir:(NSString *)saveDir;

@property (nonatomic, strong, readonly) NSString *hostUrl;
@property (nonatomic, strong, readonly) NSString *saveDir;
@end

NS_ASSUME_NONNULL_END
