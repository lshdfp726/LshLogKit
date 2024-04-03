//
//  FULogKitAppTests.m
//  FULogKitAppTests
//
//  Created by lsh726 on 2024/3/21.
//

#import <XCTest/XCTest.h>
#import <FULogKit/FULogKit.h>
@interface FULogKitAppTests : XCTestCase
@property (nonatomic, strong) FULogInfo *info;

@end

@implementation FULogKitAppTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [FULogKit destroy];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
//    NSLock *lock = [NSLock new];
    XCTestExpectation *expect = [self expectationWithDescription:@"111"];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    FULogInfo *info = [FULogInfo configWithHostUrl:@"www.baidu.com" saveDir: path];
    [FULogKit configWithInfo:info callback:^(BOOL res) {
//        XCTAssertTrue(res, @"configInfo failed");
        
        for (size_t i = 0; i < 10; i ++) {
            NSString *content = [NSString stringWithFormat:@"我是第%zu段数据",i];
            NSString *key = [NSString stringWithFormat:@"i"];
            [FULogKit uploadLog:@{key:content}];
        }
//        [lock lock];
        [expect fulfill];
//        [lock unlock];
    }];
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"error:%@" ,error);
        }
    }];
    
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
