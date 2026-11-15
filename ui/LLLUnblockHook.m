//
//  ui/LLLUnblockHook.m
//  把「换源」接到两条取流路径的最后一步：
//    LLLCloudVIP.resolveStreamURL…  （已登录，eapi 多档都失败时）
//    LLLGuestMusic.resolveStreamURL…（免登录，游客通道失败时）
//  用 swizzle 避免改两个大文件。
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "LLLCloudVIP.h"
#import "LLLGuestMusic.h"
#import "LLLUnblockSource.h"
#import "BaseComponents.h"

typedef void (*LLLResolveIMP)(id, SEL, NSNumber *, NSTimeInterval,
                              void (^)(NSURL *, NSString *));

static LLLResolveIMP gOrigVIP   = NULL;
static LLLResolveIMP gOrigGuest = NULL;

static void LLLSwz_resolveVIP(id self, SEL _cmd, NSNumber *sid, NSTimeInterval dur,
                              void (^done)(NSURL *, NSString *)) {
    if (!gOrigVIP) { if (done) done(nil, @"取流不可用"); return; }
    gOrigVIP(self, _cmd, sid, dur, ^(NSURL *url, NSString *err) {
        if (url) { if (done) done(url, nil); return; }
        /* eapi 全档失败 → 换源 */
        [[LLLUnblockSource shared] resolveSongID:sid duration:dur done:done];
    });
}

static void LLLSwz_resolveGuest(id self, SEL _cmd, NSNumber *sid, NSTimeInterval dur,
                                void (^done)(NSURL *, NSString *)) {
    if (!gOrigGuest) { if (done) done(nil, @"取流不可用"); return; }
    gOrigGuest(self, _cmd, sid, dur, ^(NSURL *url, NSString *err) {
        if (url) { if (done) done(url, nil); return; }
        [[LLLUnblockSource shared] resolveSongID:sid duration:dur done:done];
    });
}

@implementation NSObject (LLLUnblockHook)

+ (void)lll_installUnblockHook {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            SEL sel = @selector(resolveStreamURL:duration:done:);

            Method mv = class_getInstanceMethod([LLLCloudVIP class], sel);
            if (mv) {
                gOrigVIP = (LLLResolveIMP)method_getImplementation(mv);
                method_setImplementation(mv, (IMP)LLLSwz_resolveVIP);
            }

            Method mg = class_getInstanceMethod([LLLGuestMusic class], sel);
            if (mg) {
                gOrigGuest = (LLLResolveIMP)method_getImplementation(mg);
                method_setImplementation(mg, (IMP)LLLSwz_resolveGuest);
            }
        } @catch (NSException *e) {
            lllLog(@"4.0 换源挂钩异常: %@", e);
        }
    });
}

+ (void)load {
    [self lll_installUnblockHook];
}

@end
