//
//  ui/LLLUnblockHook.m
//  取流最后一档：eapi / 游客通道都失败时，走换源。
//  换源需要歌名+歌手（酷我按关键词搜），从内核当前曲目取。
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

static void LLLSwz_after(id self, SEL _cmd, NSNumber *sid, NSTimeInterval dur,
                         void (^done)(NSURL *, NSString *), BOOL ok, NSURL *url) {
    if (ok && url) { if (done) done(url, nil); return; }

    LLLPlayerCore *c = [LLLPlayerCore shared];
    NSString *name = c.title;
    NSString *artist = c.artist;

    /* 内核标题对不上时，用当前曲目字典兜底 */
    NSDictionary *song = c.currentSong;
    if ([song isKindOfClass:NSDictionary.class]) {
        if (!name.length)   name = song[@"name"];
        if (!artist.length) artist = song[@"artist"];
    }

    [[LLLUnblockSource shared] resolveSongID:sid
                                        name:name
                                      artist:artist
                                    duration:dur
                                        done:done];
}

static void LLLSwz_resolveVIP(id self, SEL _cmd, NSNumber *sid, NSTimeInterval dur,
                              void (^done)(NSURL *, NSString *)) {
    if (!gOrigVIP) { if (done) done(nil, @"取流不可用"); return; }
    __weak typeof(self) wself = self;
    gOrigVIP(wself, _cmd, sid, dur, ^(NSURL *url, NSString *err) {
        LLLSwz_after(wself, _cmd, sid, dur, done, url != nil, url);
    });
}

static void LLLSwz_resolveGuest(id self, SEL _cmd, NSNumber *sid, NSTimeInterval dur,
                                void (^done)(NSURL *, NSString *)) {
    if (!gOrigGuest) { if (done) done(nil, @"取流不可用"); return; }
    __weak typeof(self) wself = self;
    gOrigGuest(wself, _cmd, sid, dur, ^(NSURL *url, NSString *err) {
        LLLSwz_after(wself, _cmd, sid, dur, done, url != nil, url);
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
            } else {
                lllLog(@"4.0 换源: LLLCloudVIP 方法缺失");
            }

            Method mg = class_getInstanceMethod([LLLGuestMusic class], sel);
            if (mg) {
                gOrigGuest = (LLLResolveIMP)method_getImplementation(mg);
                method_setImplementation(mg, (IMP)LLLSwz_resolveGuest);
            } else {
                lllLog(@"4.0 换源: LLLGuestMusic 方法缺失");
            }
        } @catch (NSException *e) {
            lllLog(@"4.0 换源挂钩异常: %@", e);
        }
    });
}

@end
