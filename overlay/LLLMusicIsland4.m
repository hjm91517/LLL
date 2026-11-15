//
//  overlay/LLLMusicIsland4.m
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>
#import "LLLMusicIsland.h"
#import "LLLMusicIsland4.h"
#import "LLLNowPlaying.h"
#import "LLLCloudMusic.h"
#import "LLLCloudVIP.h"
#import "LLLPlayerCore.h"
#import "LLLIslandCoreBridge.h"
#import "BaseComponents.h"

static void (^gIslandCloudTap)(void) = nil;

@implementation LLLMusicIsland (Island4)

#pragma mark - 事件

+ (void)lll4_onPlay:(id)sender {
    [[LLLIslandCoreBridge shared] togglePlayPause];
    [LLLMusicIsland refresh];
}

+ (void)lll4_onPrev:(id)sender {
    [[LLLIslandCoreBridge shared] playPrevious];
    [LLLMusicIsland refresh];
}

+ (void)lll4_onNext:(id)sender {
    [[LLLIslandCoreBridge shared] playNext];
    [LLLMusicIsland refresh];
}

+ (void)lll4_onModeTap:(id)sender {
    [[LLLIslandCoreBridge shared] cycleMode];
    [LLLMusicIsland refresh];
}

/// 岛上的网易云键：登录后点它 = 打开音乐页；没登录 = 弹登录面板
+ (void)lll4_onCloudTap:(id)sender {
    if (gIslandCloudTap) { gIslandCloudTap(); return; }
    [[LLLCloudMusic shared] refreshAccountIfNeeded:nil];
}

#pragma mark - 安装

+ (void)lll4_install {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            NSArray<NSArray<NSString *> *> *pairs = @[
                @[ @"onPlay:",    @"lll4_onPlay:" ],
                @[ @"onPrev:",    @"lll4_onPrev:" ],
                @[ @"onNext:",    @"lll4_onNext:" ],
                @[ @"onModeTap:", @"lll4_onModeTap:" ],
                @[ @"onCloudTap:", @"lll4_onCloudTap:" ],
            ];
            Class meta = object_getClass((id)self);
            for (NSArray<NSString *> *p in pairs) {
                SEL oldS = sel_registerName(p[0].UTF8String);
                SEL newS = sel_registerName(p[1].UTF8String);
                Method oldM = class_getClassMethod(self, oldS);
                Method newM = class_getClassMethod(self, newS);
                if (!newM) continue;
                if (oldM) {
                    method_setImplementation(oldM, method_getImplementation(newM));
                } else {
                    class_addMethod(meta, oldS,
                                    method_getImplementation(newM),
                                    method_getTypeEncoding(newM));
                }
            }
        } @catch (NSException *e) {
            lllLog(@"4.0 岛事件安装异常: %@", e);
        }
    });
}

#pragma mark - 封面

+ (void)lll4_ensureCloudArtwork {
    LLLNowPlaying *np = [LLLNowPlaying shared];
    if (!np.cloudSource) return;
    if (np.artwork) return;

    NSString *url = np.artworkURL;
    if (!url.length) return;

    UIImage *cached = [[LLLCloudVIP shared] cachedArtwork:url];
    if (cached) {
        [np updateArtwork:cached url:url];
        return;
    }

    static NSMutableSet<NSString *> *inflight;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ inflight = [NSMutableSet set]; });

    @synchronized (inflight) {
        if ([inflight containsObject:url]) return;
        [inflight addObject:url];
    }

    [[LLLCloudVIP shared] artworkFor:url done:^(UIImage *img) {
        @synchronized (inflight) { [inflight removeObject:url]; }
        if (!img) return;
        LLLNowPlaying *cur = [LLLNowPlaying shared];
        /* 图回来时如果已经切歌，别把旧图贴上去 */
        if (![cur.artworkURL isEqualToString:url]) return;
        [cur updateArtwork:img url:url];
        [LLLMusicIsland refresh];
    }];
}

#pragma mark - 模式文案

+ (NSString *)lll4_modeLabel {
    switch ([LLLPlayerCore shared].mode) {
        case LLLPlayModeSingleLoop: return @"单曲";
        case LLLPlayModeShuffle:    return @"随机";
        default:                    return @"顺序";
    }
}

#pragma mark - 对外

+ (void)setCloudLoginHandler:(void (^)(void))handler {
    gIslandCloudTap = [handler copy];
}

+ (void)refreshCloudButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        [LLLMusicIsland refresh];
    });
}

+ (void)refreshModeButton {
    [LLLMusicIsland refresh];
}

@end
