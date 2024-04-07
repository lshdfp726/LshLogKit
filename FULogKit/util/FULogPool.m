//
//  FULogPool.m
//  FULogKit
//
//  Created by lsh726 on 2024/4/1.
//

#import "FULogPool.h"

@interface FULogPool ()
@property (nonatomic, strong) NSMutableArray *pool;
@property (nonatomic, strong) dispatch_semaphore_t productSemo;
@property (nonatomic, strong) dispatch_semaphore_t consumerSemo;
@property (nonatomic, strong) dispatch_semaphore_t resourceSemo;
@end

@implementation FULogPool
+ (void)load {
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _productSemo = dispatch_semaphore_create(1);
        _consumerSemo = dispatch_semaphore_create(0);
        _resourceSemo = dispatch_semaphore_create(1);
        _pool = [NSMutableArray array];
    }
    return self;
}

//添加到缓存池
- (void)addLog:(NSDictionary *)log {
    NSLog(@"%@:%s, productSemo --",self,__FUNCTION__);
    dispatch_semaphore_wait(self.productSemo, DISPATCH_TIME_FOREVER);
    NSLog(@"%@:%s,resourceSemo --",self,__FUNCTION__);
    dispatch_semaphore_wait(self.resourceSemo, DISPATCH_TIME_FOREVER);
    [self.pool addObject:log];
    dispatch_semaphore_signal(self.resourceSemo);
    NSLog(@"%@:%s,resourceSemo ++",self,__FUNCTION__);
    dispatch_semaphore_signal(self.consumerSemo);
    NSLog(@"%@:%s,consumerSemo ++",self,__FUNCTION__);
}

//从缓存池弹出
- (NSDictionary *)popLog {
    NSDictionary *dic;
    NSLog(@"%@:%s, consumerSemo ++",self,__FUNCTION__);
    dispatch_semaphore_wait(self.consumerSemo, DISPATCH_TIME_FOREVER);
    NSLog(@"%@:%s, resourceSemo --",self,__FUNCTION__);
    dispatch_semaphore_wait(self.resourceSemo, DISPATCH_TIME_FOREVER);
    dic = [self.pool objectAtIndex:0];
    if (dic) {
        [self.pool removeObjectAtIndex:0];
    }
    dispatch_semaphore_signal(self.resourceSemo);
    NSLog(@"%@:%s, resourceSemo ++",self,__FUNCTION__);
    dispatch_semaphore_signal(self.productSemo);
    NSLog(@"%@:%s, productSemo ++",self,__FUNCTION__);
    return dic;
}

@end
