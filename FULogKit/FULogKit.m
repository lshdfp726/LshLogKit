//
//  FULogKit.m
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import <UIKit/UIDevice.h>

#import "FULogKit.h"
#import "FULogkitUtil.h"
#import "FUNetWorkReachhabilityUtil.h"
#import "FUMMapUtil.h"
#import "FUServerLogUtil.h"
#import "FULogPool.h"
#import "FUExceptionUtil.h"


const NSString *TRACEKEY = @"trace_id";
const NSString *TIMESTAMP = @"timestamp";
const NSString *DEVICEINFO = @"device_info";
const NSString *PLATFORM = @"platform";
const NSString *INFOTAG = @"info_tag";
const NSString *INFO = @"info";

@interface FULogKit ()<FUNetWorkReachhabilityProtocol> {
    BOOL _poolRun; //开启关闭缓存池标识
}

@property (nonatomic, strong) FULogInfo *info;

//上传的服务器完整地址
@property (nonatomic, strong) NSString *serverUrl;

//当天日志的标识
@property (nonatomic, strong) NSString *traceId;

//网络变化监听
@property (nonatomic, strong) FUNetWorkReachhabilityUtil *reachable;

//内存映射
@property (nonatomic, strong) FUMMapUtil *mmap;

//服务器上传
@property (nonatomic, strong) FUServerLogUtil *uploadServer;

//日志缓存池
@property (nonatomic, strong) FULogPool *logPool;

@property (nonatomic, strong) FUExceptionUtil *catchUtil;

//保存本地日志队列
@property (nonatomic, strong) dispatch_queue_t saveQueue;
//上传服务端队列
@property (nonatomic, strong) dispatch_queue_t uploadQueue;
//sdk 内部需要串行执行的接口队列
@property (nonatomic, strong) dispatch_queue_t lifeQueue;

//缓存池读写数据串行队列，串行保证数据存取顺序
@property (nonatomic, strong) dispatch_queue_t poolQueue;

//控制缓存池开启关闭串行队列
@property (nonatomic, strong) dispatch_queue_t controlPoolQueue;
//控制缓存循环逻辑是否休眠
@property (nonatomic, strong) dispatch_semaphore_t controlPoolSemo;

@property (nonatomic, strong) NSMutableDictionary *header;

@property (nonatomic, strong) dispatch_queue_t headerQueue;


@end

@implementation FULogKit
#pragma mark - public
+ (void)destroy {
    [[FULogKit shareInstace] destroy];
}

+ (void)configWithInfo:(FULogInfo *)info
              callback:(void(^)(BOOL res))callback {
    
    dispatch_async([FULogKit shareInstace].lifeQueue, ^{
        if (![[FULogKit shareInstace].reachable isNetworkAvaiable]) {
            NSLog(@"config FULogKit failed for network failed!");
            if (callback) callback(NO);
            return ;
        }
       
        if (!info) {
            NSLog(@"config FULogKit failed for info is nil!");
            if (callback) callback(NO);
            return ;
        }

        if (![FULogKitUtil isVaildHostUrl:info.hostUrl]) {
            NSLog(@"info.hostUrl is inVaild");
            if (callback) callback(NO);
            return ;
        }
        [FULogKit shareInstace].serverUrl = [info.hostUrl stringByAppendingString:@"服务器上传日志地址"];
        NSLog(@"%@:%s isVaildHostUrl, serverUrl is %@",self, __func__,[FULogKit shareInstace].serverUrl);
        
        if (![FULogKitUtil isVaildDir:info.saveDir]) {
            NSLog(@"info.saveDir is inVaild");
            if (callback) callback(NO);
            return ;
        }
        NSLog(@"%@:%s isVaildDir",self, __func__);
        
        [FULogKit shareInstace].info = info;
        NSLog(@"%@:%s set info",self, __func__);
        
        [[FULogKit shareInstace] configLogFileCallBack:callback];
        [[FULogKit shareInstace] consumerLog];
    });
}

+ (void)setOCUncaugtException {
    [[FULogKit shareInstace].catchUtil setOCUncaugtExceptionCallback:^(NSDictionary * _Nonnull dic) {
        [[FULogKit shareInstace] writeToLocal:dic];
    }];
}

+ (void)uploadLog:(NSDictionary *)log {
    if (log.count == 0) {
        NSLog(@"%@:%s, log count is 0",self, __func__);
        return ;
    }
    FULogKit *instace = [FULogKit shareInstace];
    dispatch_async([FULogKit shareInstace].poolQueue, ^{
        [instace.logPool addLog:log];
    });
}


+ (void)uploadLog:(NSDictionary *)log callback:(void(^)(BOOL res, NSError *error))callback {
    if (log.count == 0) {
        NSLog(@"%@:%s, log count is 0",self, __func__);
        return ;
    }
    dispatch_async([FULogKit shareInstace].saveQueue, ^{
        [[FULogKit shareInstace] writeToLocal:log];
    });
    
    dispatch_async([FULogKit shareInstace].uploadQueue, ^{
#ifdef DEBUG
        [[FULogKit shareInstace] writeToServer:log callback:callback];
#endif
    });
}

#pragma mark - private
+ (instancetype)shareInstace {
    static FULogKit *_instance;
    static dispatch_once_t onceToken; //onceToken == 0 执行block方法，-1 跳过block， 其他值 ，休眠线程休眠，等onceToken 值变化，等block 执行完之后onceToken = -1，跳过block
    dispatch_once(&onceToken, ^{
        _instance = [[FULogKit alloc] init];
    });
    return _instance;
}

- (void)destroy {
    dispatch_async(self.lifeQueue, ^{
        [self.reachable stopListen];
        dispatch_async(self.saveQueue, ^{
            [self.mmap destroy];
        });
    });
    [self cancelConsumerLog];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mmap = [[FUMMapUtil alloc] init];
        _uploadServer = [[FUServerLogUtil alloc] init];
        _logPool = [[FULogPool alloc] init];
        
        _lifeQueue = dispatch_queue_create("com.FULogKit.lifeQueue", NULL);
        _saveQueue = dispatch_queue_create("com.FULogKit.saveQueue", NULL);
        _uploadQueue = dispatch_queue_create("com.FULogKit.uploadQueue", NULL);
        _poolQueue = dispatch_queue_create("com.FULogKit.poolQueue", NULL);
        _controlPoolQueue = dispatch_queue_create("com.FULogKit.controlPoolQueue", NULL);
        
        _headerQueue = dispatch_queue_create("com.FULogKit.headerQueue", DISPATCH_QUEUE_CONCURRENT);
        //获取设备信息
        NSMutableString *deviceInfo = [@"" mutableCopy];
        [deviceInfo appendString:[UIDevice currentDevice].name];
        [deviceInfo appendFormat:@"-%@",[UIDevice currentDevice].model];
        [deviceInfo appendFormat:@"-%@",[UIDevice currentDevice].systemName];
        [deviceInfo appendFormat:@"-%@",[UIDevice currentDevice].systemVersion];
        _header = [@{TRACEKEY:@"",
                     TIMESTAMP:@"",
                     DEVICEINFO: deviceInfo,
                     PLATFORM: @1,  // 平台信息，1是安卓 2是iOS，3是Web，4是Node
                     INFOTAG:@"http",
                     INFO:@{}
                    } mutableCopy];
        
        _reachable = [[FUNetWorkReachhabilityUtil alloc] init];
        [_reachable startListenNetworkChangeWithDelegate:self];
        
        _controlPoolSemo = dispatch_semaphore_create(0);
        [self loopLog];
        
        _catchUtil = [[FUExceptionUtil alloc] init];
        
        [_catchUtil setOCUncaugtExceptionCallback:^(NSDictionary * _Nonnull dic) {
            [[FULogKit shareInstace] writeToLocal:dic];
        }];
    }
    return self;
}


- (BOOL)writeToLocal:(NSDictionary *)log {
    if (log.count == 0) {
        NSLog(@"%@:%s, log count is 0",self, __func__);
        return NO;
    }
//    FULogKit *instance = [FULogKit shareInstace];
//    [instance setHeaderObject:log forKey:INFO];
//    [instance setHeaderObject:@(round([FULogKitUtil getDeviceTimeStamp])) forKey:TIMESTAMP];
//    NSDictionary *realDic = [instance getHeader];
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:log options:0 error:&error];

    if (!jsonData) {
        NSLog(@"Error converting dictionary to JSON: %@", error);
        return NO;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [[FULogKit shareInstace].mmap writeContent:jsonString];
}


- (BOOL)writeToServer:(NSDictionary *)log callback:(void(^)(BOOL , NSError *))callback {
    if (log.count == 0) {
        NSLog(@"%@:%s, log count is 0",self, __func__);
        return NO;
    }
    
    NSString *path = self.serverUrl;
    
    [self setHeaderObject:log forKey:INFO];
    [self setHeaderObject:@(round([FULogKitUtil getDeviceTimeStamp])) forKey:TIMESTAMP];
    NSDictionary *realDic = [self getHeader];

    [self.uploadServer uploadWithURL:path
                          parameters:realDic
                             success:^(id  _Nullable responseObject) {
        if (callback) callback(YES, nil);
    } failure:^(NSError * _Nullable error) {
        if (callback) callback(NO, error);
    }];
    
    return YES;
}


- (void)configLogFileCallBack:(void(^)(BOOL res))callback {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    time_t time = [FULogKitUtil getTimeFromNTP];
    NSLog(@"getTimeFromNTP耗时: %f", CFAbsoluteTimeGetCurrent() - start);
    NSString *dateStr = [FULogKitUtil timeStampToStr:time];
    dateStr = [dateStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    [self configHeader: dateStr traceId:time];
    
    NSString *fileName = [dateStr stringByAppendingString:@".txt"];
    if (![self createLocalFile: fileName]) {
        if (callback) callback(NO);
        return ;
    }
    if (callback) callback(YES);
}

- (BOOL)createLocalFile:(NSString *)timeStr {
    NSString *logPath = [self.info.saveDir stringByAppendingPathComponent:timeStr];
    if (![FULogKitUtil createFileWithPath:logPath]) {
        NSLog(@"创建日志文件失败");
        return NO;
    }
    NSLog(@"创建日志文件成功");
    return [self.mmap mmapWithPath:logPath];
}

- (void)consumerLog {
    NSLog(@"%@:%s",self, __func__);
    _poolRun = YES;
    dispatch_semaphore_signal(self.controlPoolSemo);
}

- (void)cancelConsumerLog {
    NSLog(@"%@:%s",self, __func__);
    _poolRun = NO;
}

- (void)loopLog {
    dispatch_async(self.controlPoolQueue, ^{
        while (1) {
            
            if (!self->_poolRun) {
                dispatch_wait(self.controlPoolSemo, DISPATCH_TIME_FOREVER);
            }
            
            NSDictionary *log = [self.logPool popLog];
            NSLog(@"");
            [FULogKit uploadLog:log callback:^(BOOL res, NSError *error) {
                if (error) {
                    [FULogKit uploadLog: log];
                }
            }];
            sleep(1);
        }
        
    });
}

//配置头
- (void)configHeader:(NSString *)dateStr traceId:(time_t)traceId {
    if (dateStr && dateStr.length != 0) {
        [self setHeaderObject:dateStr forKey:TIMESTAMP];
    }
    [self setHeaderObject:@(traceId) forKey:TRACEKEY];
}

#pragma mark - FUNetWorkReachhabilityProtocol
- (void)networkChange:(BOOL)reachability {
    NSLog(@"网络是否通: %d", reachability);
    if (reachability) {
        [self consumerLog];
    } else {
        [self cancelConsumerLog];
    }
}

#pragma mark - 对于 header 加读写锁, 外部调用上传接口的时候传都需要读header头内容拼到里面，无法预测是在哪个线程。
- (void)setHeaderObject:(id)value forKey:(const NSString *)key {
    dispatch_barrier_sync(self.headerQueue, ^{
        [self.header setObject:value forKey:key];
    });
}

- (NSMutableDictionary *)getHeader {
    __block NSMutableDictionary *value;
    //放到队列里面而已，用async 返回值处理又需要加信号量。所以sync
    dispatch_sync(self.headerQueue, ^{
        value = [NSMutableDictionary dictionaryWithDictionary:self.header];
    });
    return value;
}

@end
