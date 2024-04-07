//
//  NSObject+Zombie.m
//  FULogKit
//
//  Created by lsh726 on 2024/4/7.
//

#import "NSObject+Zombie.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/ldsyms.h>

static void *ZombiePointerKey = &ZombiePointerKey;
static NSDictionary *classMap;

@implementation NSObject (Zombie)
//+ (void)load {
//#ifdef DEBUG
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        classMap = [self getAllCustomClass];
//        [self swizzOriginSel:@selector(init) newSel:@selector(swizzledInit)];
//        [self swizzOriginSel:NSSelectorFromString(@"dealloc") newSel:@selector(swizzledDealloc)];
//    });
//#endif
//}

+ (void)swizzOriginSel:(SEL)originSel newSel:(SEL)newSel {
    Method original = class_getInstanceMethod([self class], originSel);
    Method swizzled = class_getInstanceMethod([self class], newSel);
    BOOL addSuccess = class_addMethod([self class],
                                          originSel,
                                          method_getImplementation(swizzled),
                                          method_getTypeEncoding(swizzled));
    if (addSuccess) {
        class_replaceMethod([self class],
                            newSel,
                            method_getImplementation(original),
                            method_getTypeEncoding(original));
        NSLog(@"%@:%s originSel is %s, newSel is %s success",self,__func__, sel_getName(originSel), sel_getName(newSel));
    } else {
        NSLog(@"%@:%s originSel is %s, newSel is %s failed 直接method_exchangeImplementations",self,__func__, sel_getName(originSel), sel_getName(newSel));
        method_exchangeImplementations(original, swizzled);
    }
}

+ (NSDictionary *)getAllCustomClass {
    unsigned int count;
    const char **classes;
    Dl_info info;
    
    dladdr(&_MH_EXECUTE_SYM, &info);
    classes = objc_copyClassNamesForImage(info.dli_fname, &count);
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    
    dispatch_semaphore_t semo = dispatch_semaphore_create(1);
    dispatch_apply(count, dispatch_get_global_queue(0, 0), ^(size_t iteration) {
        dispatch_semaphore_wait(semo, DISPATCH_TIME_FOREVER);
        NSString *className = [NSString stringWithCString:classes[iteration] encoding:NSUTF8StringEncoding];
        Class class = NSClassFromString(className);
        [dic setObject:class forKey:className];
        dispatch_semaphore_signal(semo);
    });
    
    free(classes);
    return [dic copy];
}

- (instancetype)swizzledInit {
    NSObject *instance = [self swizzledInit];
    for (Class v in classMap.allValues) {
        if ([instance isMemberOfClass:v]) {
            objc_setAssociatedObject(instance, ZombiePointerKey, @YES, OBJC_ASSOCIATION_RETAIN);
            break ;
        }
    }
    return instance;
}

- (void)swizzledDealloc {
    //一定要在 [self swizzledDealloc]; 前面，否则 dealloc 会直接把关联变量销毁导致objc_getAssociatedObject获取不到
    NSNumber *isZombie = objc_getAssociatedObject(self, ZombiePointerKey);
    if ([isZombie boolValue]) {
        // 处理野指针标记
        [self handleZombiePointer];
    }
    
    // 调用原始dealloc方法
    [self swizzledDealloc];
}

- (void)handleZombiePointer {
    Class originCls = object_getClass(self);
    // 创建一个新的类名，用于表示这是一个 Zombie 类
    NSString *zombieClassName = [NSString stringWithFormat:@"_LshNSZombie_%@", NSStringFromClass([self class])];
    Class zombieClass = objc_lookUpClass(zombieClassName.UTF8String);
    if (!zombieClass) {
        zombieClass = objc_duplicateClass(originCls, zombieClassName.UTF8String, 0);
    }
    
    // 设置实例的 isa 指针为 Zombie 类
    object_setClass(self, zombieClass);
    // 不主动释放，让系统在对象的 dealloc 方法中处理内存释放
}
@end
