//
//  FULogKitUtil.m
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import "FULogKitUtil.h"
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <netdb.h>
#include <time.h>


#define NTP_TIMESTAMP_DELTA 2208988800ull

@implementation FULogKitUtil
//TLS
__thread struct addrinfo* res = NULL;
+ (BOOL)isVaildHostUrl:(NSString *)hostUrl {
    if (hostUrl.length == 0) {
        return NO;
    }
    const char *domain = hostUrl.UTF8String;
    struct addrinfo hints, *p;
    int status;
    
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC; // IPv4
    hints.ai_socktype = SOCK_STREAM;
    
    if ((status = getaddrinfo(domain, NULL, &hints, &res)) != 0) {
        fprintf(stderr, "getaddrinfo: 域名:%s %s\n", domain, gai_strerror(status));
        return NO;
    }
    
    printf("IP addresses for %s:\n\n", domain);
    
    for (p = res; p != NULL; p = p->ai_next) {
        void *addr;
        char ipstr[INET_ADDRSTRLEN];
        
        struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
        addr = &(ipv4->sin_addr);
        
        inet_ntop(p->ai_family, addr, ipstr, sizeof ipstr);
        printf("%s\n", ipstr);
    }
    
    freeaddrinfo(res); // free the linked list
    return YES;
}

+ (BOOL)isVaildDir:(NSString *)dir {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirector = NO;
    BOOL res = [fileManager fileExistsAtPath:dir isDirectory:&isDirector];
    
    if (res && isDirector) {
        return YES;
    }
    return NO;
}

//创建文件
+ (BOOL)createFileWithPath:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]) {
            NSLog(@"Error creating directory");
            // 处理创建目录失败的情况
            return NO;
        }
        NSLog(@"success create path: %@",path);
    }
    return YES;
}

//线程TLS 局部变量
__thread struct addrinfo* servinfo = NULL;
+ (time_t)getTimeFromNTP {
    int sockfd = 0, rv;
    struct addrinfo hints, *p;
    //参开NTP协议文档，ox1b 为控制字节，要求服务器返回时间信息
    unsigned char msg[48] = {0x1b};
    unsigned char buf[48];
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    
    char *host = "time.apple.com";
    char *port = "123";
    
    //获取host 服务器地址信息列表
    if ((rv = getaddrinfo(host, port, &hints, &servinfo) != 0 )) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
        printf("NTP服务器信息获取失败，返回当前设备时间戳\n");
        return [self getDeviceTimeStamp];
    }
    printf("NTP服务器信息获取成功\n");
    
    //遍历链表，获取可用的socket连接
    for (p = servinfo; p != NULL; p = p ->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
            perror("socket");
            continue ;
        }
        
        // 设置接收超时时间为5秒
        struct timeval timeout;
        timeout.tv_sec = 0.5;
        timeout.tv_usec = 0;
        if (setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout, sizeof(timeout)) < 0) {
            perror("setsockopt failed");
            close(sockfd);
            continue;
        }
        
        CFAbsoluteTime sendToTime = CFAbsoluteTimeGetCurrent();
        if (sendto(sockfd, msg, sizeof(msg), 0, p->ai_addr, p->ai_addrlen) == -1) {
            perror("sendto");
            close(sockfd);
            continue ;
        }
        printf("sendto NTP服务器成功sockfd:%d\n",sockfd);
        
        struct sockaddr_storage addr;
        socklen_t addr_len = sizeof(addr);
        if ((recvfrom(sockfd, buf, sizeof(buf), 0, (struct sockaddr *)&addr, &addr_len) == -1)) {
            perror("recvfrom");
            close(sockfd);
            continue ;
        }
        
        //recvfrom 函数超时处理
        if (errno == ETIMEDOUT) {
            perror("recvfrom");
            p = NULL;
            break ;
        }
        
        printf("recvfrom NTP服务器成功sockfd:%d\n",sockfd);
        
        NSLog(@"socket 发送请求-返回时间耗时: %f", CFAbsoluteTimeGetCurrent() - sendToTime);
        break ;
    }
    
    if (p == NULL) {
        fprintf(stderr, "Failed to connect\n");
        printf("NTP服务器连接失败，返回当前机设备时间戳\n");
        return [self getDeviceTimeStamp];;
    }
    freeaddrinfo(servinfo);
    
    uint32_t timestamp = ntohl(((uint32_t *)buf)[10]);
    time_t now = timestamp - NTP_TIMESTAMP_DELTA;
    
    struct tm *timeinfo;
    timeinfo = localtime(&now);
    printf("World time: %s\n",asctime(timeinfo));
    close(sockfd);
    
    time_t t = mktime(timeinfo); // 将 struct tm 结构体表示的时间转换为时间戳
    return t;
}

//获取本机时间戳
+ (NSTimeInterval)getDeviceTimeStamp {
    NSDate *currentDate = [NSDate date];
    NSTimeInterval timestamp = [currentDate timeIntervalSince1970];
    return timestamp;
}

+ (NSString *)timeStampToStr:(time_t)timeStamp {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeStamp];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];

    NSString *dateString = [dateFormatter stringFromDate:date];

    return dateString;
}
@end
