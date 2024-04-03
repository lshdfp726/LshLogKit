//
//  FUNetWorkReachhabilityUtil.m
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import "FUNetWorkReachhabilityUtil.h"
#import <SystemConfiguration/SystemConfiguration.h>

@interface FUNetWorkReachhabilityUtil ()
//当前运行的runloop，
@property (nonatomic, assign) CFRunLoopRef runloop;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, weak) id <FUNetWorkReachhabilityProtocol>delegate;
@property (nonatomic, strong) dispatch_queue_t lifeQueue;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation FUNetWorkReachhabilityUtil
- (BOOL)isNetworkAvaiable {
    [self.lock lock];
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "www.testNetwork.com");
    SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);

    
    if ((flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsConnectionRequired)) {
        [self.lock unlock];
        return YES;
    }
    [self.lock unlock];
    return NO;
}

void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    FUNetWorkReachhabilityUtil *cls = (__bridge FUNetWorkReachhabilityUtil *)info;
    
    // 在这里处理网络状态变化的逻辑
    if ((flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsConnectionRequired)) {
        if ([cls.delegate respondsToSelector:@selector(networkChange:)]) {
            [cls.delegate networkChange:YES];
        }
    } else {
        if ([cls.delegate respondsToSelector:@selector(networkChange:)]) {
            [cls.delegate networkChange:NO];
        }
    }
    NSLog(@"Network status changed");
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lifeQueue = dispatch_queue_create("com.FUNetWorkReach.lifeQueue", NULL);
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)startListenNetworkChangeWithDelegate:(id<FUNetWorkReachhabilityProtocol>)delegate {
    dispatch_async(self.lifeQueue, ^{
        self.delegate = delegate;
        
        SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "www.listenNetwork.com");
        self.reachability = reachability;
        
        SCNetworkReachabilityContext context = {0, (__bridge  void *)self, NULL, NULL, NULL};
        SCNetworkReachabilitySetCallback(reachability, ReachabilityCallback, &context);
        
        CFRunLoopRef runloop = CFRunLoopGetCurrent();
        self.runloop = runloop;
        SCNetworkReachabilityScheduleWithRunLoop(reachability, runloop, kCFRunLoopCommonModes);
        
        CFRunLoopRun();
        
        NSLog(@"%@:%s runloop 停止了",self, __func__);
    });
}

- (void)stopListen {
    dispatch_async(self.lifeQueue, ^{
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachability, self.runloop, kCFRunLoopCommonModes);
        CFRelease(self.reachability);
        
        CFRunLoopStop(self.runloop);
        NSLog(@"%@:%s",self, __func__);
    });
}

@end
