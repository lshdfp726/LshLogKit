//
//  FUExceptionUtil.m
//  FULogKit
//
//  Created by lsh726 on 2024/4/2.
//

#import "FUExceptionUtil.h"

static void(^OCUncatchCallback)(NSDictionary *);

void uncaughtExceptionHandler(NSException *exception) {
    NSArray *callStack = [exception callStackSymbols];
    NSString *stackInfo = [NSString stringWithFormat:@"Uncaught Exception:\n%@\n", callStack];
    
    // 将stackInfo写入本地文件
    NSLog(@"Unhandled exception: %@", exception);
    
    NSDictionary *dic = @{@"exception": exception.reason,
                          @"name": exception.name,
                          @"stackInfo": stackInfo
    };
    // 可以在这里做一些其他处理，比如发送错误报告给开发者
    if (OCUncatchCallback) OCUncatchCallback(dic);
}



@implementation FUExceptionUtil
- (void)setOCUncaugtExceptionCallback:(void(^)(NSDictionary *))callback {
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    OCUncatchCallback = callback;
}

@end
