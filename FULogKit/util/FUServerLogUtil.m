//
//  FUServerLogUtil.m
//  FULogKit
//
//  Created by lsh726 on 2024/4/1.
//

#import "FUServerLogUtil.h"

static NSInteger const successCode = 0;

@interface FUServerLogUtil ()<NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;
@end

@implementation FUServerLogUtil
- (void)dealloc {
    
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [self sessionConfig];
        NSOperationQueue *queue = [self sessionQueue];
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:queue];
    }
    return self;
}

- (void)uploadWithURL:(NSString *)url
           parameters:(NSDictionary *)parameters
              success:(FUServerLogSuccessBlock)success
              failure:(FUServerLogFailureBlock)failure {
    NSURL *nsurl = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsurl];
    request.HTTPMethod = @"POST";
    NSString *postStr = [self transformationToString:parameters];
    request.HTTPBody = [postStr dataUsingEncoding:NSUTF8StringEncoding];
 
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request 
                                                     completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self handleRequestResultWithData:data 
                                 response:response
                                    error:error
                                  success:success
                                  failure:failure];
    }];
    [dataTask resume];
}

#pragma mark -
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    NSLog(@"%@:%s error is %@",self, __func__, error);
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
           SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
           if (serverTrust != NULL) {
               // Perform custom trust evaluation here, e.g., check certificate validity, domain, etc.
               // For simplicity, we'll just trust all certificates
               NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
               completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
               return;
           }
       }
       
       // For other authentication methods or if trust evaluation fails, use default handling
       completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (NSString *)transformationToString:(id )transition {
    NSString *jsonString = nil;
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:transition options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData) {
        NSLog(@"Get an error: %@", error);
        return nil;
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
}


/**
 * 配置 sessionConfig
 */
- (NSURLSessionConfiguration *)sessionConfig {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 10.0;
    config.HTTPAdditionalHeaders = @{
        @"Accept": @"application/json",
        @"Content-Type" : @"application/json"
    };
    return config;
}


- (NSOperationQueue *)sessionQueue {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 6;
    return queue;
}

- (NSArray <NSURLSessionTask *> *)getAllTask {
    __block NSArray<__kindof NSURLSessionTask *> *allTask;
    dispatch_semaphore_t semo = dispatch_semaphore_create(0);
    [self.session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
        allTask = tasks;
        dispatch_semaphore_signal(semo);
    }];
    dispatch_semaphore_wait(semo, DISPATCH_TIME_FOREVER);
    return allTask;
}



//加一层respose 打印
- (void)handleRequestResultWithData:(NSData * _Nullable)data
                           response:(NSURLResponse *)response
                              error:(NSError * _Nullable)error
                            success:(FUServerLogSuccessBlock)success
                            failure:(FUServerLogFailureBlock)failure {
    if (!error && data) {
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
        NSLog(@"handle-- result == %@", result);
        NSInteger code = [result[@"code"] integerValue];
        if (code == successCode) {
            !success ?: success(result);
        } else {
            int code = [result[@"code"] intValue];
            NSString *message = result[@"message"];
            NSError *e = [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:@{NSUnderlyingErrorKey : message}];
            NSLog(@"handle-- error: %@", e);
            !failure ?: failure(e);
        }
    } else {
        NSLog(@"handle-- error: %@", error);
        !failure ?: failure(error);
    }
}
@end
