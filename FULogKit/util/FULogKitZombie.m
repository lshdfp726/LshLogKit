//
//  FULogKitZombie.m
//  FULogKit
//
//  Created by lsh726 on 2024/4/3.
//

#import "FULogKitZombie.h"
#import <objc/runtime.h>

static void *ZombiePointerKey = &ZombiePointerKey;
static NSDictionary *classMap;

@implementation FULogKitZombie
+ (void)load {
#ifdef DEBUG
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classMap = [self getAllCustomClass];
        
        Method originalAllocWithZone = class_getClassMethod([self class], @selector(allocWithZone:));
        Method swizzledAllocWithZone = class_getClassMethod([self class], @selector(swizzledAllocWithZone:));
        method_exchangeImplementations(originalAllocWithZone, swizzledAllocWithZone);

        Method originalDealloc = class_getInstanceMethod([self class], NSSelectorFromString(@"dealloc"));
        Method swizzledDealloc = class_getInstanceMethod([self class], @selector(swizzledDealloc));
        method_exchangeImplementations(originalDealloc, swizzledDealloc);
    });
#endif
}

+ (NSDictionary *)getAllCustomClass {
    unsigned int count;
    Class *classes = objc_copyClassList(&count);
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (unsigned int i = 0; i < count; i++) {
        Class class = classes[i];
        NSString *className = [[NSString alloc] initWithCString:class_getName(class) encoding:NSUTF8StringEncoding];
        NSLog(@"Class name: %s", class_getName(class));
        [dic setObject:class forKey:className];
    }
    
    free(classes);
    return [dic copy];
}

+ (instancetype)swizzledAllocWithZone:(struct _NSZone *)zone {
    id instance = [self swizzledAllocWithZone:zone];
    objc_setAssociatedObject(instance, ZombiePointerKey, @NO, OBJC_ASSOCIATION_RETAIN);
    return instance;
}

- (void)swizzledDealloc {
    //这里的self 已经是swizzledAllocWithZone 的instance， 方法交换导致的
    NSNumber *isZombie = objc_getAssociatedObject(self, ZombiePointerKey);
    if ([isZombie boolValue]) {
        // 处理野指针标记
        [self handleZombiePointer];
    }
    // 调用原始dealloc方法
    [self swizzledDealloc];
    
}

- (void)handleZombiePointer {
    // 创建一个新的类名，用于表示这是一个 Zombie 类
    NSString *zombieClassName = [NSString stringWithFormat:@"_NSZombie_%@", NSStringFromClass([self class])];
    const char *zombieClassNameCString = [zombieClassName UTF8String];
    
    // 创建一个新的 Zombie 类，父类为原始类
    Class originalClass = object_getClass(self);
    Class zombieClass = objc_allocateClassPair(originalClass, zombieClassNameCString, 0);
    
    // 向 Zombie 类中添加原始类的方法实现
    unsigned int methodCount;
    Method *methods = class_copyMethodList(originalClass, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char *types = method_getTypeEncoding(method);
        IMP implementation = class_getMethodImplementation(originalClass, selector);
        class_addMethod(zombieClass, selector, implementation, types);
    }
    free(methods);
    
    // 注册 Zombie 类
    objc_registerClassPair(zombieClass);
    
    // 设置实例的 isa 指针为 Zombie 类
    object_setClass(self, zombieClass);
    
    // 保存原始类名等信息以便上报
    NSString *originalClassName = NSStringFromClass([self class]);
    // 保存 originalClassName 供上报使用
    // ...
    
    // 不主动释放，让系统在对象的 dealloc 方法中处理内存释放
}
@end
