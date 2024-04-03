//
//  FUExceptionUtil.h
//  FULogKit
//
//  Created by lsh726 on 2024/4/2.
//

#import <Foundation/Foundation.h>
@protocol FUExceptionProtocol <NSObject>

@end

NS_ASSUME_NONNULL_BEGIN
/**
 * 异常捕获类
 */
@interface FUExceptionUtil : NSObject
@property (nonatomic, weak) id<FUExceptionProtocol>delegate;

- (void)setOCUncaugtExceptionCallback:(void(^)(NSDictionary *))callback;
@end

NS_ASSUME_NONNULL_END
