//
//  ViewController.m
//  FULogKitApp
//
//  Created by lsh726 on 2024/3/21.
//

#import "ViewController.h"
#import <FULogKit/FULogKit.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view
    

    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    FULogInfo *info = [FULogInfo configWithHostUrl:@"www.baidu.com" saveDir: path];
    [FULogKit configWithInfo:info callback:^(BOOL res) {
        for (size_t i = 0; i < 10; i ++) {
            NSString *content = [NSString stringWithFormat:@"我是第%zu段数据",i];
            NSString *key = [NSString stringWithFormat:@"%zu",i];
            if (i % 2 == 0) {
                [FULogKit uploadLog:@{key:content}];
            } else {
                [FULogKit uploadLog:@{key:content} callback:nil];
            }
        }
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [FULogKit destroy];
    });
}

static size_t count = 10;
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    NSString *content = [NSString stringWithFormat:@"我是第%zu段数据",count];
    NSString *key = [NSString stringWithFormat:@"%zu",count];
    [FULogKit uploadLog:@{key:content}];
    count ++;
}
@end
