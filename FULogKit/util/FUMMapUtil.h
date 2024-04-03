//
//  FUMMapUtil.h
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FUMMapUtil : NSObject

//开始mmap映射
- (BOOL)mmapWithPath:(NSString *)path;

//更新内容
- (BOOL)writeContent:(NSString *)content;

//关闭mmap
- (void)destroy;
@end

NS_ASSUME_NONNULL_END
