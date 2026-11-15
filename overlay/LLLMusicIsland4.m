//
//  overlay/LLLMusicIsland4.m  — 4.0
//
//  分类实现，全部方法带 lll4 前缀，不动主 @implementation。
//  · 岛上的播放/上一首/下一首/模式键 → LLLIslandCoreBridge → LLLPlayerCore
//  · 网易云封面兜底拉取
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

#pragma mark - 事件（供桥接层替换用）

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

+ (void)lll4_onCloudTap:(id)sender {
    if (gIslandCloudTap) gIslandCloudTap();
}

#pragma mark - 安装

+ (void)lll4_install {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            NSArray<NSArray<NSString *> *> *pairs = @[
                @[ @"onPlay:",     @"lll4_onPlay:" ],
                @[ @"onPrev:",     @"lll4_onPrev:" ],
                @[ @"onNext:",     @"lll4_onNext:" ],
                @[ @"onModeTap:",  @"lll4_onModeTap:" ],
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

#pragma mark - 网易云键

+ (void)lll4_setCloudTapHandler:(void (^)(void))handler {
    gIslandCloudTap = [handler copy];
}

+ (void)lll4_refreshCloudTitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        [LLLMusicIsland refresh];
    });
}

@end
