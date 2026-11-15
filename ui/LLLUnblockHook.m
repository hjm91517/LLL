//
//  ui/LLLUnblockHook.m
//  取流最后一档：eapi / 游客通道都失败时，走换源（内置酷我）。
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "LLLCloudVIP.h"
#import "LLLGuestMusic.h"
#import "LLLUnblockSource.h"
#import "LLLPlayerCore.h"
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
        LLLPlayerCore *c = [LLLPlayerCore shared];
        [[LLLUnblockSource shared] resolveSongID:sid
                                            name:c.title
                                          artist:c.artist
                                        duration:dur
                                            done:done];
    });
}

static void LLLSwz_resolveGuest(id self, SEL _cmd, NSNumber *sid, NSTimeInterval dur,
                                void (^done)(NSURL *, NSString *)) {
    if (!gOrigGuest) { if (done) done(nil, @"取流不可用"); return; }
    gOrigGuest(self, _cmd, sid, dur, ^(NSURL *url, NSString *err) {
        if (url) { if (done) done(url, nil); return; }
        LLLPlayerCore *c = [LLLPlayerCore shared];
        [[LLLUnblockSource shared] resolveSongID:sid
                                            name:c.title
                                          artist:c.artist
                                        duration:dur
                                            done:done];
    });
}

@implementation NSObject (LLLUnblockHook)

+ (void)load {
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

@end
