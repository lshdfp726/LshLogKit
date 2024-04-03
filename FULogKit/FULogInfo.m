//
//  FULogInfo.m
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import "FULogInfo.h"

@interface FULogInfo ()
@property (nonatomic, strong) NSString *hostUrl;
@property (nonatomic, strong) NSString *saveDir;
@end

@implementation FULogInfo
+ (instancetype)configWithHostUrl:(NSString *)hostUrl
                          saveDir:(NSString *)saveDir {
    FULogInfo *model = [[FULogInfo alloc] init];
    if (!hostUrl || hostUrl.length == 0) {
        NSLog(@"hostUrl invaild!");
        return nil;
    }
    model.hostUrl = hostUrl;
    model.saveDir = saveDir;
    return model;
}


@end
