//
//  ui/MainViewController+Music4.m  — 4.0
//  音乐页接线：表格、卡片、分段控件全部接到 LLLMusicController / LLLPlayerCore。
//

#import "MainViewController+Music4.h"
#import "MainViewController_Private.h"
#import "MainViewController+MusicUI4.h"
#import "MainViewController+CloudLists4.h"
#import "LLLCloudLogin.h"          /* openCloudMusic / presentLoginChooser */
#import "LLLMusicController.h"
#import "LLLPlayerCore.h"
#import "LLLCloudMusic.h"
#import "LLLIslandCoreBridge.h"
#import "LLLMusicIsland.h"
#import "LLLMusicIsland4.h"        /* lll4_setCloudTapHandler: 在这一层 */
#import "LLLNowPlaying.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import "AppTheme.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>
#import <math.h>

/* 主类里这些方法是私有的，跨文件用必须在本地补声明 */
@interface MainViewController (Music4Internal)
- (void)switchTo:(UITableView *)to hide:(NSArray *)others bar:(UIView *)bar;
- (void)setHeader:(NSString *)title sub:(NSString *)sub;
@end

static void *kLLL4Ticker = &kLLL4Ticker;
static void *kLLL4Installed = &kLLL4Installed;

@implementation MainViewController (Music4)

#pragma mark - 安装

- (void)lll4_installMusicPage {
    if (objc_getAssociatedObject(self, kLLL4Installed)) return;
    objc_setAssociatedObject(self, kLLL4Installed, @YES, OBJC_ASSOCIATION_RETAIN);

    [[LLLMusicController shared] bindHost:self];
    [[LLLIslandCoreBridge shared] install];

    /* 3.12 留下的播放器全部停掉，状态交给内核 */
    [self lll4_stopLegacyPlayers];

    __weak typeof(self) w = self;
    [[LLLIslandCoreBridge shared] setOpenLoginHandler:^{
        __strong typeof(w) s = w;
        if (s) [s openCloudMusic];
    }];
    /* 岛上的网易云键走同一个回调（注意：这是 LLLMusicIsland 的分类方法） */
    [LLLMusicIsland lll4_setCloudTapHandler:^{
        __strong typeof(w) s = w;
        if (s) [s openCloudMusic];
    }];

    [self lll4_installLoginButton];

    /* 内核变化 → 刷卡片 */
    if (!objc_getAssociatedObject(self, kLLL4Ticker)) {
        NSTimer *t = [NSTimer timerWithTimeInterval:0.35 repeats:YES block:^(NSTimer *tm) {
            __strong typeof(w) s = w;
            if (!s) { [tm invalidate]; return; }
            if (s.playerCard.isHidden) return;
            [s lll4_refreshCard];
        }];
        objc_setAssociatedObject(self, kLLL4Ticker, t, OBJC_ASSOCIATION_RETAIN);
        [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    }

    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(lll4_dataChanged)
                                              name:@"LLLMusicDataDidChange"
                                            object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(lll4_coreChanged)
                                              name:LLLPlayerCoreDidChange
                                            object:nil];
}

- (void)lll4_stopLegacyPlayers {
    @try { [self.audioPlayer stop]; } @catch (__unused NSException *e) { }
    self.audioPlayer = nil;

    @try { [self.videoMusicPlayer pause]; } @catch (__unused NSException *e) { }
    self.videoMusicPlayer = nil;

    @try { [self.cloudPlayer pause]; } @catch (__unused NSException *e) { }
    self.cloudPlayer = nil;

    self.isPlaying = NO;
}

#pragma mark - 页面

- (void)lll4_showMusicTab {
    /* 卡片展开：高度给足，不然进度条和控制键会被切掉 */
    self.playerCard.hidden = NO;
    if (self.playerHeight) self.playerHeight.constant = 310;

    /* 旧的第二套控制栏彻底不再出现 */
    self.musicControlBar.hidden = YES;
    self.musicControlBar.alpha = 0;

    LLLMusicController *mc = [LLLMusicController shared];
    [mc reloadLocal];
    if ([mc sourceKind] == LLLMusicSourceKindCloud) [mc reloadCloudLiked];

    self.musicSrcSeg.selectedSegmentIndex = ([mc sourceKind] == LLLMusicSourceKindCloud) ? 1 : 0;

    [self switchTo:self.musict hide:@[self.st, self.qt, self.pt, self.pqt] bar:nil];
    [self.musict reloadData];
    [self lll4_refreshCard];

    [self setHeader:@"音乐播放器"
                sub:[NSString stringWithFormat:@"%ld 首 · %@",
                     (long)[mc rowCount],
                     ([mc sourceKind] == LLLMusicSourceKindCloud) ? @"网易云" : @"本地"]];
}

- (void)lll4_musicSourceChanged:(UISegmentedControl *)seg {
    LLLMusicSourceKind k = (seg.selectedSegmentIndex == 1) ? LLLMusicSourceKindCloud
                                                            : LLLMusicSourceKindLocal;
    LLLMusicController *mc = [LLLMusicController shared];
    [mc setSourceKind:k];

    if (k == LLLMusicSourceKindCloud) {
        if (![LLLCloudMusic shared].loggedIn) {
            /* 没登录也能用：直接进免登录面板，别再把人挡在门外 */
            ShowToast(@"未登录 · 可听免费曲目", 1.8, YES, NO);
            [self lll4_openGuestMusic];
            [self.musict reloadData];
            [self lll4_refreshCard];
            return;
        }
        [mc reloadCloudLiked];
    }
    [self.musict reloadData];
    [self lll4_refreshCard];
}

- (void)lll4_reloadMusicTab {
    [self.musict reloadData];
    [self lll4_refreshCard];
}

- (void)lll4_musicCellPlay:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "idx");
    if (!idx) return;
    [self lll4_didSelectMusicRow:idx.integerValue];
}

- (void)lll4_didSelectMusicRow:(NSInteger)row {
    [[LLLMusicController shared] playRow:row];
    [self lll4_refreshCard];
    [self.musict reloadData];
}

#pragma mark - 卡片按键

- (void)lll4_togglePlayPause { [[LLLMusicController shared] togglePlayPause]; [self lll4_refreshCard]; }
- (void)lll4_next { [[LLLMusicController shared] nextTrack]; [self lll4_refreshCard]; }
- (void)lll4_prev { [[LLLMusicController shared] previousTrack]; [self lll4_refreshCard]; }
- (void)lll4_toggleMode { [[LLLMusicController shared] toggleMode]; [self lll4_refreshCard]; }
- (void)lll4_toggleSpeed { [[LLLMusicController shared] toggleSpeed]; [self lll4_refreshCard]; }

- (void)lll4_seekRatio:(float)ratio {
    [[LLLMusicController shared] seekRatio:ratio];
    [self lll4_refreshCard];
}

#pragma mark - 刷新

- (void)lll4_refreshCard {
    LLLMusicController *mc = [LLLMusicController shared];
    LLLPlayerCore *core = [LLLPlayerCore shared];

    if (self.playerTitle)  self.playerTitle.text  = [mc cardTitle];
    if (self.playerArtist) self.playerArtist.text = [mc cardSubtitle];
    if (self.playerTimeLabel) self.playerTimeLabel.text = [mc cardTimeText];
    if (self.nowPlayingLabel) self.nowPlayingLabel.text = [mc cardTitle];

    BOOL playing = [mc cardPlaying];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
        UIImage *img = [UIImage systemImageNamed:(playing ? @"pause.fill" : @"play.fill")
                               withConfiguration:cfg];
        if (self.playerPlayBtn) [self.playerPlayBtn setImage:img forState:UIControlStateNormal];

        UIImageSymbolConfiguration *mcfg =
            [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
        NSString *sym = @"repeat";
        switch ([mc playMode]) {
            case LLLPlayModeSingleLoop: sym = @"repeat.1"; break;
            case LLLPlayModeShuffle:    sym = @"shuffle"; break;
            default:                    sym = @"repeat"; break;
        }
        if (self.playerModeBtn)
            [self.playerModeBtn setImage:[UIImage systemImageNamed:sym withConfiguration:mcfg]
                                forState:UIControlStateNormal];
    }

    if (self.speedBtn) {
        [self.speedBtn setTitle:[mc isDoubleSpeed] ? @"2x" : @"1x" forState:UIControlStateNormal];
    }
    if (self.modeBtn) {
        NSString *label = @"顺序";
        switch ([mc playMode]) {
            case LLLPlayModeSingleLoop: label = @"单曲"; break;
            case LLLPlayModeShuffle:    label = @"随机"; break;
            default:                    label = @"顺序"; break;
        }
        [self.modeBtn setTitle:label forState:UIControlStateNormal];
    }

    /* 进度条跟着内核走 */
    double total = core.duration;
    if (total > 0.5) {
        double el = [core currentElapsed];
        float r = (float)(el / total);
        if (!isnan(r) && isfinite(r)) {
            r = MAX(0, MIN(1, r));
            if (self.playerProgress && !self.playerProgress.isTracking) self.playerProgress.value = r;
            if (self.progressSlider && !self.progressSlider.isTracking) self.progressSlider.value = r;
        }
    }

    if (self.playerCover && core.artwork) {
        self.playerCover.image = core.artwork;
        self.playerCover.contentMode = UIViewContentModeScaleAspectFill;
    }

    /* 播放中封面转，暂停停 */
    if (self.playerCover) {
        if (playing) {
            if (![self.playerCover.layer animationForKey:@"lll.spin"]) {
                CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
                spin.fromValue = @0;
                spin.toValue = @(M_PI * 2);
                spin.duration = 12.0;
                spin.repeatCount = HUGE_VALF;
                spin.removedOnCompletion = NO;
                [self.playerCover.layer addAnimation:spin forKey:@"lll.spin"];
            }
        } else {
            [self.playerCover.layer removeAnimationForKey:@"lll.spin"];
        }
    }

    self.isPlaying = playing;
    [self lll4_refreshLoginButton];
}

- (void)lll4_dataChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.musict reloadData];
        [self lll4_refreshCard];
    });
}

- (void)lll4_coreChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.playerCard.isHidden) [self lll4_refreshCard];
    });
}

@end
