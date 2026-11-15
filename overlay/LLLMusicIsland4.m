//
//  overlay/LLLMusicIsland4.m  — 4.0
//
//  分类实现，全部方法带 lll4 前缀，不污染主 @implementation。
//  · 岛事件接管：播放/上一首/下一首/模式/网易云 → 桥接层 → LLLPlayerCore
//  · 网易云封面兜底拉取（缺图时异步补）
//  · 4.0 新按键的挂载：login / mode，由 buildIfNeeded 之后调用 lll4_attachButtons
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
#import "AppTheme.h"

static void (^gIslandCloudTap)(void) = nil;
static UIButton *gLoginBtn4 = nil;
static UIButton *gModeBtn4  = nil;
static BOOL gButtonsAttached = NO;

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
    [self lll4_refreshModeButton];
    [LLLMusicIsland refresh];
}

+ (void)lll4_onCloudTap:(id)sender {
    if (gIslandCloudTap) gIslandCloudTap();
}

+ (void)lll4_onLoginTap:(id)sender {
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

#pragma mark - 按键挂载

/// 在岛建好之后，把「登录」「模式」两颗键挂到控制行
+ (BOOL)lll4_attachButtonsToPill:(UIView *)pill {
    if (gButtonsAttached || !pill) return gButtonsAttached;

    UIView *ctrl = nil;
    for (UIView *v in pill.subviews) {
        if (v.tag == 777) { ctrl = v; break; }
    }
    if (!ctrl) return NO;

    /* —— 播放模式键 —— */
    UIButton *mode = [UIButton buttonWithType:UIButtonTypeCustom];
    mode.frame = CGRectMake(154, 2, 56, 30);
    mode.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    mode.layer.cornerRadius = 15;
    mode.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [mode setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [mode setTitle:@"顺序" forState:UIControlStateNormal];
    [mode addTarget:self action:@selector(lll4_onModeTap:)
   forControlEvents:UIControlEventTouchUpInside];
    [ctrl addSubview:mode];
    gModeBtn4 = mode;

    /* —— 网易云登录键（把原来那个改成登录入口，文案随状态变） —— */
    for (UIView *v in ctrl.subviews) {
        if (![v isKindOfClass:[UIButton class]]) continue;
        UIButton *b = (UIButton *)v;
        CGRect f = b.frame;
        if (f.origin.x > 200 && f.origin.x < 300 && f.size.width > 100) {
            /* 这就是主实现里那颗「网易云 · 登录」 */
            [b removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
            [b addTarget:self action:@selector(lll4_onLoginTap:)
        forControlEvents:UIControlEventTouchUpInside];
            b.frame = CGRectMake(216, 2, 60, 30);
            gLoginBtn4 = b;
            break;
        }
    }

    gButtonsAttached = YES;
    [self lll4_refreshModeButton];
    [self lll4_refreshLoginButton];
    return YES;
}

#pragma mark - 文案刷新

+ (void)lll4_refreshModeButton {
    if (!gModeBtn4) return;
    NSString *label = @"顺序";
    switch ([LLLPlayerCore shared].mode) {
        case LLLPlayModeSingleLoop: label = @"单曲"; break;
        case LLLPlayModeShuffle:    label = @"随机"; break;
        default:                    label = @"顺序"; break;
    }
    if (![[gModeBtn4 titleForState:UIControlStateNormal] isEqualToString:label]) {
        [gModeBtn4 setTitle:label forState:UIControlStateNormal];
    }
    gModeBtn4.backgroundColor = ([LLLPlayerCore shared].mode == LLLPlayModeSequential)
        ? [UIColor colorWithWhite:1 alpha:0.12]
        : [LLLAccentColor() colorWithAlphaComponent:0.35];
}

+ (void)lll4_refreshLoginButton {
    if (!gLoginBtn4) return;
    NSString *title = @"登录";
    if ([LLLCloudMusic shared].loggedIn) {
        NSString *nick = [LLLCloudMusic shared].nickname;
        if (!nick.length) nick = @"已登录";
        if (nick.length > 4) nick = [nick substringToIndex:4];
        title = nick;
        gLoginBtn4.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16];
    } else {
        gLoginBtn4.backgroundColor = [LLLAccentColor() colorWithAlphaComponent:0.32];
    }
    if (![[gLoginBtn4 titleForState:UIControlStateNormal] isEqualToString:title]) {
        [gLoginBtn4 setTitle:title forState:UIControlStateNormal];
    }
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

@end
