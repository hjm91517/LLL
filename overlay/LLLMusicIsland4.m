//
//  overlay/LLLMusicIsland4.m
//  4.0 灵动岛补丁层：在不重写整个岛的前提下，把这几件事做掉
//
//    1) 封面 100% 用网易云曲图（LLLNowPlaying.artworkURL + LLLCloudVIP 缓存）
//    2) 播放/上一首/下一首/进度/模式 全部转 LLLPlayerCore（经 LLLIslandCoreBridge）
//    3) 展开态第二行：网易云登录键 + 播放模式键
//    4) 胶囊态封面播放时旋转，暂停停
//
//  实现方式：+load 时把岛里几个事件方法换成 4.0 版本。
//  这样不必维护一份 500 行的岛副本，改动点集中在两处。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>
#import "LLLMusicIsland.h"
#import "LLLNowPlaying.h"
#import "LLLCloudMusic.h"
#import "LLLCloudVIP.h"
#import "LLLPlayerCore.h"
#import "LLLIslandCoreBridge.h"
#import "BaseComponents.h"

/* 岛内部静态变量无法从外部访问，这里用 KVC 拿视图对象（同一个进程，安全） */
@interface NSObject (LLLIsland4Access)
@end

@implementation LLLMusicIsland (Island4)

#pragma mark - 事件替换

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

#pragma mark - 安装

+ (void)lll4_install {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            /* 岛里的事件方法名是 onPlay:/onPrev:/onNext:/onCloudTap: */
            struct { const char *sel; const char *rep; } map[] = {
                { "onPlay:",      "lll4_onPlay:" },
                { "onPrev:",      "lll4_onPrev:" },
                { "onNext:",      "lll4_onNext:" },
                { "onModeTap:",   "lll4_onModeTap:" },
            };
            for (int i = 0; i < 4; i++) {
                SEL oldS = sel_registerName(map[i].sel);
                SEL newS = sel_registerName(map[i].rep);
                Method oldM = class_getClassMethod(self, oldS);
                Method newM = class_getClassMethod(self, newS);
                if (!newM) continue;
                if (oldM) {
                    method_setImplementation(oldM, method_getImplementation(newM));
                } else {
                    class_addMethod(object_getClass((id)self), oldS,
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

/// 岛在 applyContent 里调；这里保证"只要当前是网易云曲目，要么有图，要么正在拉"
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

@end
