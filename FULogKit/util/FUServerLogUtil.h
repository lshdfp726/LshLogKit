//
//  FUServerLogUtil.h
//  FULogKit
//
//  Created by lsh726 on 2024/4/1.
//

#import <Foundation/Foundation.h>

typedef void (^FUServerLogSuccessBlock)(id _Nullable responseObject);
typedef void (^FUServerLogFailureBlock)(NSError * _Nullable error);


NS_ASSUME_NONNULL_BEGIN
/**
 * 日志上传服务器
 */
@interface FUServerLogUtil : NSObject

- (void)uploadWithURL:(NSString *)url
           parameters:(NSDictionary *)parameters
              success:(FUServerLogSuccessBlock)success
              failure:(FUServerLogFailureBlock)failure;
@end

NS_ASSUME_NONNULL_END
