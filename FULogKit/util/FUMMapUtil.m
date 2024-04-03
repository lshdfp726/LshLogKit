//
//  FUMMapUtil.m
//  FULogKit
//
//  Created by lsh726 on 2024/3/21.
//

#import "FUMMapUtil.h"
#include <sys/mman.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/sysctl.h>

static size_t EXTEND_SIZE = 0;

//向上页大小(16kb)对齐
#define ALIGINPAGE(newFileSize) ((newFileSize / EXTEND_SIZE) * EXTEND_SIZE + (newFileSize % EXTEND_SIZE == 0?0:EXTEND_SIZE))
//向下页大小(16kb)对齐
#define PREALIGINPAGE(newFileSize) (ALIGINPAGE(newFileSize) == 0?0:(ALIGINPAGE(newFileSize) - EXTEND_SIZE))

@interface FUMMapUtil () {
    int _fd; //打开的文件句柄
    
    void *_mmapData; //mmap 映射起始地址
    size_t _mapFileSize;  // 当前内存映射大小 和 _mmapData 对应
    size_t _contentFileSize; // 记录一次mmap生命周期内预写入磁盘内容的大小
    size_t _mapFileUsedSize; // mmap 映射某一页(16kb)里面的实际数据内容大小
    size_t _originFileSize;  //文件实际内容大小

}

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSLock *lock; //保证内存映射和文件扩展接口线程安全
@end

@implementation FUMMapUtil
+ (void)load {
    int pageSize;
    size_t len = sizeof(pageSize);
    
    if (sysctlbyname("hw.pagesize", &pageSize, &len, NULL, 0) == 0) {
        NSLog(@"%@:%s Page size: %d bytes", self,__func__,pageSize);
        EXTEND_SIZE = pageSize;
    } else {
        NSLog(@"%@:%s Failed to get page size",self, __func__);
        EXTEND_SIZE = 16 * 1024;
    }

}

- (void)dealloc {
    [self destroy];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.FUMMapUtil", NULL);
        _lock = [[NSLock alloc] init];
        _contentFileSize = 0;
        _mapFileUsedSize = 0;
        _originFileSize = 0;
        _mapFileSize = 0;
    }
    return self;
}

- (BOOL)mmapWithPath:(NSString *)path {
    [self.lock lock];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *errorStr = [NSString stringWithFormat:@"Can't find file at path: %@", path];
    if(![fileManager fileExistsAtPath:path]) {
        NSLog(@"%@",errorStr);
        return NO;
    }
    
    int fd = open([path UTF8String], O_RDWR);
    _fd = fd;
    
    size_t fileSize = [self getFilSize:fd];
    if (fileSize == -1) {
        NSLog(@"Failed to get file size.");
        return NO;
    }
    _originFileSize = fileSize;
    
    /**
     * 每次扩展大小都是以标准页大小(16kb)为单位
     * 暂时忽略文件实际内容大小和文件大小不对齐的情况
     * 优化方向: 以16kb为基准，然后查最后一页的数据结尾。
     */
    //文件大小为0,需要扩展EXTEND_SIZE.
    if (fileSize == 0) {
        if (ftruncate(fd, EXTEND_SIZE) == -1) {
            NSLog(@"%@:%s ftruncate扩展文件大小失败",self, __func__);
            perror("ftruncate");
            return NO;
        }
        _mmapData = [self mmapWithFd:fd fileSize:EXTEND_SIZE offset:0];
        _mapFileUsedSize = 0;
    } else {
        //对齐大小
        size_t alignSize = ALIGINPAGE(fileSize);
        //文件剩余未填充字节
        size_t left = alignSize - fileSize;
        //需要扩展文件最终大小
        size_t ftruncateSize = 0;
        //内存映射偏移量
        size_t offset = 0;
        
        if (left == 0) {
            /**
             * 文件大小为 filleSize = n *16kb， ALIGINPAGE(fileSize) = n * 16kb ，offset = n * 16kb
             * 当前文件大小刚好16kb对齐，当前page已经被填满，此时需要扩展新的页，因为当前没有更新内容，所以默认扩展16kb
             * 被映射的页面当前没有内容，所以 _mapFileUsedSize = fileSize - offset = 0
             */
            ftruncateSize = alignSize + EXTEND_SIZE;

            offset = ALIGINPAGE(fileSize);
        } else {
            /**
             * 当前文件大小未对齐，也需要扩展，只不过当前页还有剩余空间，那么就把当前页扩展满即可(16kb)
             * 文件大小为 filleSize = n *16kb + a， ALIGINPAGE(fileSize) = (n + 1) * 16kb，offset = n * 16kb
             * 被映射的页面当前有a字节内容，所以 _mapFileUsedSize = fileSize  - offset = a
             */
            ftruncateSize = alignSize;
            //偏移就从当前页开始
            offset = PREALIGINPAGE(fileSize);
        }
        if (ftruncate(fd, ftruncateSize) == -1) {
            NSLog(@"%@:%s ftruncate扩展文件大小失败",self, __func__);
            perror("ftruncate");
            return NO;
        }
        _mmapData = [self mmapWithFd:fd fileSize:EXTEND_SIZE offset:offset];
        //当前页面已经被使用的大小
        _mapFileUsedSize = fileSize - offset;
    }

    [self.lock unlock];
    NSLog(@"%@:%s",self, __func__);
    return YES;
}

//static int count = 0;
//更新内容
- (BOOL)writeContent:(NSString *)content {
    [self.lock lock];
    const char *c = [content UTF8String];
    size_t len = strlen(c);
//    if (count == 1) {
//        len = 16 * 1024;
//        const char *temp = malloc(len);
//        char *t = (char *)temp;
//        for (int i = 0; i < len; i ++) {
//            *t++ = '1';
//        }
//        c = temp;
//    }
//    count ++;
    //已经使用的大小，当前mmap映射区域已经被使用的大小
    size_t usedSize = _mapFileUsedSize + _contentFileSize;
    //当前mmap映射段的可用的大小
    size_t useSize = _mapFileSize - usedSize;
    //求文件总的实际大小 =  n * 16kb(之前页大小) + usedSize(当前映射页已经被使用的大小)
    size_t t = 0;
    if (ALIGINPAGE(_originFileSize) - _originFileSize == 0) {
        //字节对齐的，0kb，16kb，32kb，48kb
        t = _originFileSize;
    } else {
        // 1kb t = 0 ，17kb t = 16kb ，33kb，t = 32kb
        t = PREALIGINPAGE(_originFileSize);
    }
   
    //文件实际内容大小
    size_t realUsedSize = t + usedSize;
    
    size_t newFileSize = 0;
    //针对新增内容已经大于当前可用大小的情况进行扩容
    if ([self extendSizeWithContentLength:len
                                 fileSize:useSize
                             fileUsedSize:realUsedSize
                             newFileSize:&newFileSize
                                       fd:_fd]) {
        //重新扩展之前先同步当前数据到磁盘
        if (![self mmapSync:_mmapData fileSize:usedSize]) {
            NSLog(@"%@:%s 同步磁盘失败",self, __func__);
            return NO;
        }
        //旧的内容已经刷新到磁盘，清空
        _contentFileSize = _mapFileUsedSize = 0;
        //解除映射
        [self unmmap:_mmapData mapSize:_mapFileSize fd:_fd];
        //因为文件已经进行扩容，并且映射已经被解除，需要更新当前文件实际内容大小
        _originFileSize = realUsedSize;
        
        /**
         * offset 目的就是取当前文件实际内容最后一页大小开始的偏移量
         * ex: 文件大小为15kb， ALIGINPAGE(realUsedSize) = 16kb，offset 取0，  文件大小为17kb， ALIGINPAGE(realUsedSize) = 32kb，offset = 16kb
         */
        size_t offset = 0;
        //为什么这样算: 参考 mmapWithPath 函数里面处理 offset
        if (ALIGINPAGE(realUsedSize) - realUsedSize == 0) {
            //如果已经对其，那么就取对齐的为偏移量
            offset = ALIGINPAGE(realUsedSize);
        } else {
            //未对齐就取向下对齐的
            offset = PREALIGINPAGE(realUsedSize);
        }
        //重新映射大小: 文件扩展的总大小 - 偏移量即可
        _mmapData = [self mmapWithFd:_fd fileSize:newFileSize - offset offset:offset];
        
        //为什么这样算: 参考 mmapWithPath 函数里面处理 _mapFileUsedSize
        _mapFileUsedSize = realUsedSize - offset;
        if (!_mmapData) {
            return NO;
        }
    }
    if (!_mmapData) {
        NSLog(@"%@:%s 内存映射起始地址为空，如果没有报mmap相关错误，那么请检查调用流程",self, __func__);
        return NO;
    }
    
    //当前区间mmap映射: 起始地址 + 当前区间的文件原始内容偏移 + 新增内容偏移
    memcpy(_mmapData + _mapFileUsedSize + _contentFileSize, c, len);
    _contentFileSize += len;
    [self.lock unlock];
    
    return YES;
}


//销毁文件句柄
- (void)destroy {
    if (_mmapData == NULL) {
        NSLog(@"%@:already %s already",self, __func__);
        return ;
    }
    //已经使用的大小，当前mmap映射区域已经被使用的大小 + 当前映射区域内预更新到磁盘的大小
    size_t usedSize = _mapFileUsedSize + _contentFileSize;
    if(![self mmapSync:_mmapData fileSize:usedSize]) {
        NSLog(@"%@:%s 同步磁盘失败",self, __func__);
    }
    
    [self unmmap:_mmapData mapSize:_mapFileSize fd:_fd];
    _mmapData = NULL;
    
    /**
     * 截断文件处理,当前文件实际大小:
     * preAligin:向下取16kb对齐，，_mapFileUsedSize 是当前映射区间实际内大小，_contentFileSize 当前map更新的内容大小
     * ex: _originFileSize = 17kb,  ALIGINPAGE(_originFileSize) = 32kb,      ALIGINPAGE(_originFileSize)  - EXTEND_SIZE = 16kb,
     * _mapFileUsedSize 是1kb ，前面逻辑已经处理好了所以 实际文件大小 =  _contentFileSize + preAligin + _mapFileUsedSize;
     */
    size_t preAligin = 0;
    if (ALIGINPAGE(_originFileSize) - _originFileSize == 0) {//文件实际内容大小16kb字节对齐
        preAligin = _originFileSize;
    } else {
        preAligin = PREALIGINPAGE(_originFileSize); //不是字节对齐，向下取16kb对齐
    }
    
    size_t fileSize = _contentFileSize + preAligin + _mapFileUsedSize;
    if (ftruncate(_fd, fileSize) == -1) {
        NSLog(@"%@:%s ftruncate扩展文件大小失败",self, __func__);
        perror("ftruncate");
    }
    //文件截断之后，都清掉。
    _contentFileSize = _mapFileUsedSize = 0;
    
    NSLog(@"%@:%s",self, __func__);
    if (_fd > 0) close(_fd);
    //文件关闭后，大小清掉，下次打开会重新赋值
    _originFileSize = 0;
}

- (off_t)getFilSize:(int)fd {
    // 获取文件大小
    off_t size = lseek(fd, 0, SEEK_END); // 将文件偏移量移动到文件末尾
    if (size == (off_t)-1) {
        perror("Error getting file size");
        close(fd);
        return 1;
    }
    return size;
}

//同步到磁盘
- (BOOL)mmapSync:(void *)data fileSize:(size_t)fileSize {
    if (msync(data, fileSize, MS_SYNC) == -1) {
        perror("msync");
        NSLog(@"Failed to sync mmap memory to file.");
        return NO;
    }
    NSLog(@"%@:%s fileSize:%zukb- %zubyte",self, __func__,fileSize/EXTEND_SIZE, fileSize % 1024);
    return YES;
}

//mmap
- (void *)mmapWithFd:(int)fd fileSize:(size_t)fileSize offset:(off_t)offset {
    void *mmapedData = mmap(NULL, fileSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, offset);
    if (mmapedData == MAP_FAILED) {
        perror("mmap");
        NSLog(@"Failed to map file to memory.");
        return NULL;
    }
    
    NSLog(@"%@:%s fd:%d mappAddress:%p, fileSize:%zukb",self, __func__, fd ,mmapedData, fileSize/1024);
    _mapFileSize = fileSize;
    return mmapedData;
}

//munmap
- (void)unmmap:(void *)mmapData mapSize:(size_t)mapSize fd:(int)fd {
    if (_mmapData) {
        NSLog(@"%@:%s fd:%d mappAddress:%p, fileSize:%zukb",self, __func__,fd, mmapData,mapSize/1024);
        munmap(_mmapData, mapSize);
    }
}

/**
 * 扩展mmap大小，一旦扩展都是按照页大小来扩展。
 * length 当前新增内容大小
 * fileSize 当前mmap映射区域的可用大小
 * fileUsedSize 当前文件实际的大小
 * fd 当前文件句柄
 * return NO,无需扩展文件大小，YES需要扩展
 */
- (BOOL)extendSizeWithContentLength:(size_t)length
                           fileSize:(size_t)fileSize
                       fileUsedSize:(size_t)fileUsedSize
                                 fd:(int)fd {
    BOOL needMapped = NO;
    //当前需要映射的大小超过
    while (length > fileSize) {
        if (ftruncate(fd, fileSize + fileUsedSize + EXTEND_SIZE) == -1) {
            NSLog(@"%@:%s ftruncate扩展文件大小失败",self, __func__);
            perror("ftruncate");
            return NO;
        }
        fileSize += EXTEND_SIZE;
        needMapped = YES;
    }

    return needMapped;
}

/**
 * 扩展mmap大小，一旦扩展都是按照页大小来扩展。
 * length 当前新增内容大小
 * fileSize 当前mmap映射区域的可用大小
 * fileUsedSize 当前文件实际的大小
 * fd 当前文件句柄
 * newFileSize： 新的文件总大小
 * return NO,无需扩展文件大小，YES需要扩展
 */
- (BOOL)extendSizeWithContentLength:(size_t)length
                           fileSize:(size_t)fileSize
                       fileUsedSize:(size_t)fileUsedSize
                        newFileSize:(size_t *)newFileSize
                                 fd:(int)fd {
    BOOL needMapped = NO;
    //当前需要映射的大小超过
    while (length > fileSize) {
        if (ftruncate(fd, fileSize + fileUsedSize + EXTEND_SIZE) == -1) {
            NSLog(@"%@:%s ftruncate扩展文件大小失败",self, __func__);
            perror("ftruncate");
            return NO;
        }
        fileSize += EXTEND_SIZE;
        needMapped = YES;
    }
    
    *newFileSize = fileSize + fileUsedSize;
    
    return needMapped;
}
@end
