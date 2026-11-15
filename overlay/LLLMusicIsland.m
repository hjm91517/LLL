//
//  LLLMusicIsland.m
//  仿 Apple 灵动岛：胶囊态 ↔ 展开态，弹簧过渡，封面 + 跑马灯 + 波形 + 进度
//

#import "LLLMusicIsland.h"
#import "LLLNowPlaying.h"
#import "BaseComponents.h"
#import "LLLCloudLogin.h"
#import "LLLCloudMusic.h"
#import "CacheCleaner.h"
#import <math.h>
#import "LLLAnim.h"
#import "AppTheme.h"
#import <AVFoundation/AVFoundation.h>

static const CGFloat kCompactW = 218, kCompactH = 38;
static const CGFloat kExpandW  = 372, kExpandH  = 248;

static UIWindow   *gWin    = nil;
static UIView     *gHost   = nil;
static UIView     *gPill   = nil;

static UIImageView *gArtSm = nil, *gArtLg = nil;
static UILabel     *gTitleSm = nil, *gTitleLg = nil, *gArtistLg = nil;
static UIView      *gTitleClip = nil;   /* 跑马灯裁剪层：文字只能在这一格内滚动 */
static UILabel     *gTimeLg = nil, *gDurLg = nil;
static UIView      *gBarsBox = nil;
static NSArray<UIView *> *gBars = nil;
static UIView      *gTrack = nil, *gFill = nil;
static UIView      *gCtrlRow = nil;
static UIButton    *gPlayBtn = nil, *gPrevBtn = nil, *gNextBtn = nil, *gCloseBtn = nil;
/* v2.2 新增：可拖进度条 / 独立音量 / 网易云入口 / 清缓存整合 */
static UISlider    *gSeekSld = nil, *gVolSld = nil;
static UILabel     *gVolIcon = nil, *gCacheLabel = nil;
static UIButton    *gCloudBtn = nil, *gCacheBtn = nil;
static BOOL         gSeeking = NO, gVolDragging = NO;
static AVPlayerLayer *gVidSm = nil, *gVidLg = nil;   /* 本地 mp4/mov 时把画面投到封面位 */

static NSTimer     *gTick = nil, *gCollapseTimer = nil;
static BOOL         gShowing = NO, gExpanded = NO, gBuilding = NO;
static NSString    *gLegacyTitle = nil;
/* v3.3：临时标题（清缓存进度等）。非空时盖住歌名，3 秒后自动还原 */
static NSString    *gTransientText = nil;
static BOOL         gLegacyPlaying = NO;
static void (^gTapHandler)(void) = nil;

#pragma mark - 穿透宿主

@interface LLLIslandHostView : UIView <UIGestureRecognizerDelegate>
@end
@implementation LLLIslandHostView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    return (v == self) ? nil : v;
}
/* 【进度可拖修复】胶囊上的 tap/长按手势会拦截滑条与按钮的触摸：
 * 展开态下，落点在滑条或按钮（含控制行内按钮）上时，手势不得开始 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    UIView *pill = self.subviews.firstObject;
    if (!pill || pill.isHidden || pill.tag != 777001) return YES;
    CGPoint p = [g locationInView:pill];
    for (UIView *v in pill.subviews) {
        if (v.isHidden) continue;
        if ([v isKindOfClass:[UISlider class]] && CGRectContainsPoint(v.frame, p)) return NO;
        if (v.tag == 777 && CGRectContainsPoint(v.frame, p)) {
            for (UIView *b in v.subviews) {
                if (b.isHidden) continue;
                CGRect bf = [pill convertRect:b.frame fromView:v];
                if (CGRectContainsPoint(bf, p)) return NO;
            }
        }
    }
    return YES;
}
@end

@interface LLLMusicIsland ()
+ (void)tick;
+ (void)buildIfNeeded;
+ (void)layoutForExpanded:(BOOL)expanded animated:(BOOL)animated;
+ (void)daemonStart;
+ (void)daemonStop;
+ (void)applyContent;
+ (void)scheduleCollapse;
+ (void)showIsland;
+ (void)attachVideo:(nullable AVPlayer *)player;
+ (CGRect)pillRectForWidth:(CGFloat)w height:(CGFloat)h;
+ (void)onTap:(UIGestureRecognizer *)g;
+ (void)onLongPress:(UILongPressGestureRecognizer *)g;
+ (void)seekChanged:(UISlider *)sld;
+ (void)seekEnded:(UISlider *)sld;
+ (void)volChanged:(UISlider *)sld;
+ (void)onCloudTap:(id)sender;
+ (void)onCacheTap:(id)sender;
+ (void)onPrev:(id)s;
+ (void)onPlay:(id)s;
+ (void)onNext:(id)s;
+ (void)onClose:(id)s;
@end

/* 音量图标用 SF Symbol，不用 emoji */
static void LLLSetVolIcon(UILabel *l, float v) {
    if (!l) return;
    if (@available(iOS 13.0, *)) {
        NSString *sym = (v < 0.02f) ? @"speaker.slash.fill"
                        : ((v < 0.5f) ? @"speaker.wave.1.fill" : @"speaker.wave.3.fill");
        UIImage *img = [UIImage systemImageNamed:sym];
        if (img) {
            img = [img imageWithTintColor:[UIColor colorWithWhite:0.88 alpha:1]
                           renderingMode:UIImageRenderingModeAlwaysOriginal];
            NSTextAttachment *att = [NSTextAttachment new];
            att.image = img;
            att.bounds = CGRectMake(0, -2, img.size.width, img.size.height);
            l.attributedText = [NSAttributedString attributedStringWithAttachment:att];
            return;
        }
    }
    l.text = @"";
}

@implementation LLLMusicIsland

#pragma mark - 窗口

+ (UIWindow *)islandWindow {
    if (gWin) return gWin;

    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }
    /* 【交互修复】窗口本体也要穿透（双保险：宿主视图已穿透） */
    gWin = scene ? [[BaseOverlayWindow alloc] initWithWindowScene:scene]
                 : [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    return gWin;
}

+ (CGFloat)topInset {
    CGFloat top = 20;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                UIStatusBarManager *m = ((UIWindowScene *)s).statusBarManager;
                if (m) top = MAX(10, CGRectGetHeight(m.statusBarFrame));
                break;
            }
        }
    }
    return top;
}

#pragma mark - 构建

+ (UILabel *)label:(CGFloat)size weight:(UIFontWeight)w color:(UIColor *)c {
    UILabel *l = [UILabel new];
    l.font = [UIFont systemFontOfSize:size weight:w];
    l.textColor = c;
    l.lineBreakMode = NSLineBreakByClipping;
    return l;
}

+ (UIButton *)button:(NSString *)sym fallback:(NSString *)txt size:(CGFloat)s {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:s weight:UIImageSymbolWeightSemibold];
        UIImage *img = [UIImage systemImageNamed:sym withConfiguration:cfg];
        if (img) [b setImage:img forState:UIControlStateNormal];
        else [b setTitle:txt forState:UIControlStateNormal];
    } else {
        [b setTitle:txt forState:UIControlStateNormal];
    }
    b.tintColor = [UIColor colorWithWhite:0.97 alpha:1];
    b.titleLabel.font = [UIFont systemFontOfSize:s weight:UIFontWeightSemibold];
    return b;
}

+ (void)buildIfNeeded {
    if (gPill || gBuilding) return;
    gBuilding = YES;

    gWin = [self islandWindow];
    gWin.windowLevel = UIWindowLevelStatusBar + 500;
    gWin.backgroundColor = UIColor.clearColor;
    gWin.opaque = NO;
    gWin.userInteractionEnabled = YES;
    /* 【占全屏修复】窗口和胶囊同尺寸：覆盖层不再整屏铺开，游戏区域一个像素都不占 */
    gWin.frame = [self pillRectForWidth:kCompactW height:kCompactH];

    gHost = [[LLLIslandHostView alloc] initWithFrame:CGRectMake(0, 0, kCompactW, kCompactH)];
    gHost.backgroundColor = UIColor.clearColor;
    gHost.autoresizingMask = UIViewAutoresizingNone;
    UIViewController *vc = [UIViewController new];
    vc.view = gHost;
    gWin.rootViewController = vc;
    gWin.hidden = NO;

    gPill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCompactW, kCompactH)];
    gPill.tag = 777001;
    gPill.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.94];
    gPill.layer.cornerRadius = kCompactH / 2.0;
    gPill.layer.cornerCurve = kCACornerCurveContinuous;
    gPill.layer.borderWidth = 0.6;
    gPill.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    gPill.clipsToBounds = YES;
    gPill.userInteractionEnabled = YES;
    gPill.alpha = 0;
    [gHost addSubview:gPill];

    UITapGestureRecognizer *ptap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
    ptap.delegate = (id<UIGestureRecognizerDelegate>)gHost;   /* 让滑条/按钮触摸不被手势拦截（见 LLLIslandHostView） */
    [gPill addGestureRecognizer:ptap];
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    lp.delegate = (id<UIGestureRecognizerDelegate>)gHost;
    lp.minimumPressDuration = 0.6;
    [gPill addGestureRecognizer:lp];

    gArtSm = [[UIImageView alloc] initWithFrame:CGRectMake(7, 7, 24, 24)];
    gArtSm.contentMode = UIViewContentModeScaleAspectFill;
    gArtSm.layer.cornerRadius = 12;
    gArtSm.clipsToBounds = YES;
    gArtSm.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    [gPill addSubview:gArtSm];

    gArtLg = [[UIImageView alloc] initWithFrame:CGRectMake(18, 18, 52, 52)];
    gArtLg.contentMode = UIViewContentModeScaleAspectFill;
    gArtLg.layer.cornerRadius = 14;
    gArtLg.layer.cornerCurve = kCACornerCurveContinuous;
    gArtLg.clipsToBounds = YES;
    gArtLg.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    gArtLg.hidden = YES;
    [gPill addSubview:gArtLg];

    /* 【跑马灯越界修复】标题外面套一层裁剪视图。
       以前直接把 label 左移，文字会滑出胶囊、压到封面甚至飘到岛外 */
    gTitleClip = [[UIView alloc] initWithFrame:CGRectMake(39, 0, 120, kCompactH)];
    gTitleClip.clipsToBounds = YES;
    gTitleClip.backgroundColor = UIColor.clearColor;
    gTitleClip.userInteractionEnabled = NO;
    [gPill addSubview:gTitleClip];

    gTitleSm = [self label:12 weight:UIFontWeightSemibold color:UIColor.whiteColor];
    gTitleSm.frame = CGRectMake(0, 0, 120, kCompactH);
    [gTitleClip addSubview:gTitleSm];

    gTitleLg = [self label:15 weight:UIFontWeightSemibold color:UIColor.whiteColor];
    gTitleLg.frame = CGRectMake(86, 16, kExpandW - 86 - 46, 20);
    gTitleLg.hidden = YES;
    [gPill addSubview:gTitleLg];

    gArtistLg = [self label:11 weight:UIFontWeightRegular color:[UIColor colorWithWhite:0.62 alpha:1]];
    gArtistLg.frame = CGRectMake(86, 42, kExpandW - 86 - 46, 16);
    gArtistLg.hidden = YES;
    [gPill addSubview:gArtistLg];

    gBarsBox = [[UIView alloc] initWithFrame:CGRectMake(kCompactW - 44, 12, 22, 14)];
    [gPill addSubview:gBarsBox];
    NSMutableArray *bars = [NSMutableArray array];
    for (int i = 0; i < 4; i++) {
        UIView *b = [[UIView alloc] initWithFrame:CGRectMake(i * 6, 4, 3, 6)];
        b.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1];
        b.layer.cornerRadius = 1.5;
        [gBarsBox addSubview:b];
        [bars addObject:b];
    }
    gBars = bars;

    /* v2.2：可拖动进度条（点按式旧进度条只有 tap，拖不了进度） */
    gSeekSld = [[UISlider alloc] initWithFrame:CGRectMake(18, 80, kExpandW - 36, 30)];
    gSeekSld.minimumTrackTintColor = [LLLAccentColor() colorWithAlphaComponent:0.95];
    gSeekSld.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.18];
    gSeekSld.thumbTintColor = UIColor.whiteColor;
    gSeekSld.minimumValue = 0; gSeekSld.maximumValue = 1;
    gSeekSld.hidden = YES;
    [gSeekSld addTarget:self action:@selector(seekChanged:)
       forControlEvents:UIControlEventValueChanged];
    [gSeekSld addTarget:self action:@selector(seekEnded:)
       forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [gPill addSubview:gSeekSld];

    gTimeLg = [self label:10 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.72 alpha:1]];
    gTimeLg.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
    gTimeLg.frame = CGRectMake(18, 110, 60, 14);
    gTimeLg.hidden = YES;
    [gPill addSubview:gTimeLg];

    gDurLg = [self label:10 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.62 alpha:1]];
    gDurLg.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
    gDurLg.textAlignment = NSTextAlignmentRight;
    gDurLg.frame = CGRectMake(kExpandW - 78, 110, 60, 14);
    gDurLg.hidden = YES;
    [gPill addSubview:gDurLg];

    /* v2.2：独立音量（只调音乐播放器，不动系统音量） */
    gVolIcon = [self label:14 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.85 alpha:1]];
    LLLSetVolIcon(gVolIcon, 0.8f);
    gVolIcon.frame = CGRectMake(18, 138, 24, 26);
    gVolIcon.hidden = YES;
    [gPill addSubview:gVolIcon];

    gVolSld = [[UISlider alloc] initWithFrame:CGRectMake(46, 140, kExpandW - 64, 26)];
    gVolSld.minimumTrackTintColor = [UIColor colorWithWhite:0.96 alpha:0.9];
    gVolSld.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.18];
    gVolSld.thumbTintColor = UIColor.whiteColor;
    gVolSld.minimumValue = 0; gVolSld.maximumValue = 1;
    gVolSld.hidden = YES;
    [gVolSld addTarget:self action:@selector(volChanged:)
       forControlEvents:UIControlEventValueChanged];
    [gPill addSubview:gVolSld];

    gCtrlRow = [[UIView alloc] initWithFrame:CGRectMake(0, 168, kExpandW, 34)];
    gCtrlRow.hidden = YES;
    [gPill addSubview:gCtrlRow];

    gPrevBtn = [self button:@"backward.fill" fallback:@"<<" size:15];
    gPrevBtn.frame = CGRectMake(14, 1, 44, 32);
    [gPrevBtn addTarget:self action:@selector(onPrev:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gPrevBtn];

    gPlayBtn = [self button:@"play.fill" fallback:@"PLAY" size:17];
    gPlayBtn.frame = CGRectMake(58, -1, 48, 36);
    gPlayBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    gPlayBtn.layer.cornerRadius = 18;
    gPlayBtn.layer.cornerCurve = kCACornerCurveContinuous;
    [gPlayBtn addTarget:self action:@selector(onPlay:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gPlayBtn];

    gNextBtn = [self button:@"forward.fill" fallback:@">>" size:15];
    gNextBtn.frame = CGRectMake(106, 1, 44, 32);
    [gNextBtn addTarget:self action:@selector(onNext:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gNextBtn];

    /* v2.2：网易云入口（未登录 → 登录面板；已登录 → 我喜欢的/搜索/退出） */
    gCloudBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    gCloudBtn.frame = CGRectMake(158, 2, 118, 30);
    gCloudBtn.backgroundColor = [LLLAccentColor() colorWithAlphaComponent:0.30];
    gCloudBtn.layer.cornerRadius = 15;
    gCloudBtn.layer.cornerCurve = kCACornerCurveContinuous;
    gCloudBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    gCloudBtn.tintColor = UIColor.whiteColor;
    gCloudBtn.titleLabel.textColor = UIColor.whiteColor;
    [gCloudBtn setTitle:@"网易云 · 登录" forState:UIControlStateNormal];
    [gCloudBtn addTarget:self action:@selector(onCloudTap:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gCloudBtn];

    /* v2.2：清缓存与自动清缓存监控合并进灵动岛 */
    gCacheBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    gCacheBtn.frame = CGRectMake(280, 2, 76, 30);
    gCacheBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    gCacheBtn.layer.cornerRadius = 15;
    gCacheBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    gCacheBtn.tintColor = UIColor.whiteColor;
    gCacheBtn.titleLabel.textColor = UIColor.whiteColor;
    [gCacheBtn setTitle:@"清缓存" forState:UIControlStateNormal];
    [gCacheBtn addTarget:self action:@selector(onCacheTap:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gCacheBtn];

    gCacheLabel = [self label:10 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.55 alpha:1]];
    gCacheLabel.frame = CGRectMake(18, 206, kExpandW - 36, 18);
    gCacheLabel.text = @"自动清缓存 · 每 30 秒巡检";
    gCacheLabel.hidden = YES;
    [gPill addSubview:gCacheLabel];

    gCloseBtn = [self button:@"chevron.down" fallback:@"v" size:11];
    gCloseBtn.frame = CGRectMake(kExpandW - 40, 16, 28, 28);
    gCloseBtn.hidden = YES;
    [gCloseBtn addTarget:self action:@selector(onClose:) forControlEvents:UIControlEventTouchUpInside];
    [gPill addSubview:gCloseBtn];

    [self layoutForExpanded:NO animated:NO];
    [self applyContent];

    [[NSNotificationCenter defaultCenter] addObserverForName:LLLNowPlayingDidChange
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *note) {
        @try {
            if ([LLLNowPlaying shared].hasTrack) [LLLMusicIsland showIsland];
            [LLLMusicIsland applyContent];
        } @catch (__unused NSException *e) { }
    }];

    gBuilding = NO;
}

#pragma mark - 布局

/* 胶囊在屏幕坐标里的落点：水平居中，状态栏下方 6pt */
+ (CGRect)pillRectForWidth:(CGFloat)w height:(CGFloat)h {
    CGSize screen = UIScreen.mainScreen.bounds.size;
    if (screen.width < 10 || screen.height < 10) screen = CGSizeMake(390, 844);
    CGFloat x = floorf((screen.width - w) / 2.0f);
    CGFloat y = [self topInset] + 6;
    if (@available(iOS 11.0, *)) {
        UIWindow *key = UIApplication.sharedApplication.keyWindow;
        if (key) {
            UIEdgeInsets si = key.safeAreaInsets;
            CGFloat maxTop = screen.height - h - 12;
            /* 有刘海/灵动岛的真机：状态栏高度已经包含安全区，别再加一次 */
            if (si.top > 0) y = MAX(y, si.top + 4);
            if (y > maxTop) y = MAX(8, maxTop);
        }
    }
    return CGRectMake(x, y, w, h);
}

+ (void)layoutForExpanded:(BOOL)expanded animated:(BOOL)animated {
    if (!gPill) return;
    CGFloat w = expanded ? kExpandW : kCompactW;
    CGFloat h = expanded ? kExpandH : kCompactH;

    void (^apply)(void) = ^{
        CGRect win = [self pillRectForWidth:w height:h];
        /* 窗口 = 胶囊：宿主、根视图、胶囊三者同框，没有整屏遮罩可挡 */
        gWin.frame = win;
        gHost.frame = CGRectMake(0, 0, w, h);
        gPill.frame = CGRectMake(0, 0, w, h);
        gPill.layer.cornerRadius = expanded ? 26 : (kCompactH / 2.0);

        gArtSm.hidden = expanded;
        gTitleSm.hidden = expanded;
        gTitleClip.hidden = expanded;
        gBarsBox.hidden = expanded;

        gArtLg.hidden = !expanded;
        gTitleLg.hidden = !expanded;
        gArtistLg.hidden = !expanded;
        gSeekSld.hidden = !expanded;
        gTimeLg.hidden = !expanded;
        gDurLg.hidden = !expanded;
        gVolIcon.hidden = !expanded;
        gVolSld.hidden = !expanded;
        gCtrlRow.hidden = !expanded;
        gCacheLabel.hidden = !expanded;
        gCloseBtn.hidden = !expanded;
    };

    if (animated) LLLSpring(0.38, 0.80, apply);
    else apply();
}

+ (void)setExpanded:(BOOL)expanded {
    [self buildIfNeeded];
    gExpanded = expanded;
    if (gCollapseTimer) { [gCollapseTimer invalidate]; gCollapseTimer = nil; }
    [self layoutForExpanded:expanded animated:YES];
    [self applyContent];
}

+ (void)toggleExpanded {
    [self setExpanded:!gExpanded];
}

#pragma mark - 内容

static NSString *LLLClock(NSTimeInterval t) {
    if (t < 0 || !isfinite(t)) t = 0;
    NSInteger s = (NSInteger)t;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(s / 60), (long)(s % 60)];
}

+ (void)applyContent {
    if (!gPill) return;
    LLLNowPlaying *np = [LLLNowPlaying shared];

    NSString *title = gTransientText.length ? gTransientText : (np.title.length ? np.title : gLegacyTitle);
    BOOL playing = np.hasTrack ? np.playing : gLegacyPlaying;
    if (!title.length) title = @"未在播放";

    if (![gTitleSm.text isEqualToString:title]) {
        gTitleSm.text = title;
        gTitleLg.text = title;
        [gTitleSm.layer removeAnimationForKey:@"marquee"];
        CGFloat avail = 120;
        CGSize sz = [title sizeWithAttributes:@{ NSFontAttributeName: gTitleSm.font }];
        if (sz.width > avail + 1) {
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
            a.fromValue = @0;
            a.toValue = @(-(sz.width - avail));
            a.duration = MAX(2.4, (sz.width - avail) / 22.0);
            a.autoreverses = YES;
            a.repeatCount = HUGE_VALF;
            a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [gTitleSm.layer addAnimation:a forKey:@"marquee"];
        }
    }

    gArtistLg.text = np.artist.length ? np.artist : (np.hasTrack ? @"网易云音乐" : @"bbhj online");

    UIImage *art = np.artwork;
    if (art) {
        gArtSm.image = art;
        gArtLg.image = art;
        gArtSm.contentMode = UIViewContentModeScaleAspectFill;
        gArtLg.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        gArtSm.image = nil;
        gArtLg.image = nil;
        gArtSm.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        gArtLg.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    }

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
        UIImage *img = [UIImage systemImageNamed:(playing ? @"pause.fill" : @"play.fill") withConfiguration:cfg];
        if (img) [gPlayBtn setImage:img forState:UIControlStateNormal];
    }

    double d = np.duration, e = np.elapsed;
    gDurLg.text = LLLClock(d);
    gTimeLg.text = LLLClock(e);
    CGFloat ratio = (d > 0.5) ? (CGFloat)(e / d) : 0;
    ratio = MAX(0, MIN(1, ratio));
    if (!gSeeking && fabs(gSeekSld.value - (double)ratio) > 0.001) gSeekSld.value = ratio;

    /* 独立音量：来自 LLL.volume（applyVolume 只作用于音乐播放器，不动系统音量） */
    {
        float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];
        if (v <= 0.001f) v = 0.8f;
        if (fabs(gVolSld.value - (double)v) > 0.001) gVolSld.value = v;
    }

    /* 网易云登录状态实时同步到岛上按钮 */
    NSString *cloudTitle = @"网易云 · 登录";
    if ([LLLCloudMusic shared].loggedIn) {
        NSString *nick = [LLLCloudMusic shared].nickname;
        cloudTitle = nick.length ? [NSString stringWithFormat:@"网易云 · %@", nick]
                                 : @"网易云 · 已登录";
    }
    if (![gCloudBtn titleForState:UIControlStateNormal] || ![[gCloudBtn titleForState:UIControlStateNormal] isEqualToString:cloudTitle]) {
        [gCloudBtn setTitle:cloudTitle forState:UIControlStateNormal];
    }
}

+ (void)tick {
    if (!gShowing) return;
    [self applyContent];

    LLLNowPlaying *np = [LLLNowPlaying shared];
    BOOL playing = np.hasTrack ? np.playing : gLegacyPlaying;

    for (NSUInteger i = 0; i < gBars.count; i++) {
        UIView *b = gBars[i];
        CGFloat target = playing ? (4 + (CGFloat)arc4random_uniform(11)) : 3;
        CGRect f = b.frame;
        f.origin.y = 14 - target;
        f.size.height = target;
        b.frame = f;
    }
}

#pragma mark - 显隐

+ (void)daemonStart {
    if (gTick) return;
    gTick = [NSTimer timerWithTimeInterval:0.12 repeats:YES block:^(NSTimer *t) {
        @try { [LLLMusicIsland tick]; } @catch (__unused NSException *e) { }
    }];
    [[NSRunLoop mainRunLoop] addTimer:gTick forMode:NSRunLoopCommonModes];
}

+ (void)daemonStop {
    [gTick invalidate];
    gTick = nil;
}

+ (void)scheduleCollapse {
    [gCollapseTimer invalidate];
    gCollapseTimer = [NSTimer timerWithTimeInterval:6.0 repeats:NO block:^(NSTimer *t) {
        @try {
            if (![LLLNowPlaying shared].playing && !gLegacyPlaying) {
                [LLLMusicIsland setExpanded:NO];
                [LLLMusicIsland hide];
            }
        } @catch (__unused NSException *e) { }
    }];
    [[NSRunLoop mainRunLoop] addTimer:gCollapseTimer forMode:NSRunLoopCommonModes];
}

+ (void)showIsland {
    [self buildIfNeeded];
    if (!gPill) return;
    [self daemonStart];

    /* 【不显示修复】hide 会把整个 window 藏起来；这里必须先把 window 拉回来，
       否则胶囊动画跑在隐藏窗口上 = 灵动岛彻底消失（清缓存后再也看不到岛的原因） */
    gWin.hidden = NO;
    gWin.alpha = 1;

    [self applyContent];

    if (!gShowing) {
        gShowing = YES;
        gPill.hidden = NO;
        gPill.alpha = 0;
        gPill.transform = CGAffineTransformMakeScale(0.82, 0.82);
        LLLSpring(0.42, 0.76, ^{
            gPill.alpha = 1;
            gPill.transform = CGAffineTransformIdentity;
        });
    } else if (gPill.hidden) {
        gPill.hidden = NO;
        gPill.alpha = 1;
    }
    [self layoutForExpanded:gExpanded animated:YES];
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gPill || !gShowing) return;
            gShowing = NO;
            gExpanded = NO;
            gSeeking = NO;
            gTransientText = nil;
            [self daemonStop];
            [gCollapseTimer invalidate];
            gCollapseTimer = nil;
            [gPill.layer removeAllAnimations];
            [gTitleSm.layer removeAllAnimations];
            [UIView animateWithDuration:0.22 animations:^{
                gPill.alpha = 0;
                gPill.transform = CGAffineTransformMakeScale(0.86, 0.86);
            } completion:^(BOOL f) {
                gPill.hidden = YES;
                gWin.hidden = YES;
                gPill.transform = CGAffineTransformIdentity;
            }];
        } @catch (__unused NSException *e) { }
    });
}

/* 本地视频：同一个 AVPlayer 可以挂多个 AVPlayerLayer，封面位直接出画面 */
+ (void)attachVideo:(AVPlayer *)player {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [gVidSm removeFromSuperlayer]; gVidSm = nil;
            [gVidLg removeFromSuperlayer]; gVidLg = nil;
            if (!player || !gArtSm || !gArtLg) return;

            gVidSm = [AVPlayerLayer playerLayerWithPlayer:player];
            gVidSm.videoGravity = AVLayerVideoGravityResizeAspectFill;
            gVidSm.frame = gArtSm.bounds;
            [gArtSm.layer addSublayer:gVidSm];

            gVidLg = [AVPlayerLayer playerLayerWithPlayer:player];
            gVidLg.videoGravity = AVLayerVideoGravityResizeAspectFill;
            gVidLg.frame = gArtLg.bounds;
            [gArtLg.layer addSublayer:gVidLg];

            gArtSm.image = nil;
            gArtLg.image = nil;
        } @catch (__unused NSException *e) { }
    });
}

+ (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { if (gPill) [self applyContent]; }
        @catch (__unused NSException *e) { }
    });
}

#pragma mark - 事件

+ (void)onTap:(UIGestureRecognizer *)g {
    if (gTapHandler) { gTapHandler(); return; }
    [self toggleExpanded];
}

+ (void)onLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self hide];
}

+ (void)onPrev:(id)s { [[LLLNowPlaying shared] send:LLLNPCommandPrevious value:0]; }
+ (void)onNext:(id)s { [[LLLNowPlaying shared] send:LLLNPCommandNext value:0]; }
+ (void)onClose:(id)s { [self setExpanded:NO]; }

/* v2.2：拖动进度 —— 拖动中只刷显示，松手才真正 seek */
+ (void)seekChanged:(UISlider *)sld {
    gSeeking = YES;
    LLLNowPlaying *np = [LLLNowPlaying shared];
    double d = np.duration;
    if (d > 0.5) {
        gTimeLg.text = LLLClock(sld.value * d);
    }
}
+ (void)seekEnded:(UISlider *)sld {
    gSeeking = NO;
    LLLNowPlaying *np = [LLLNowPlaying shared];
    double d = np.duration;
    if (d > 0.5) {
        [[LLLNowPlaying shared] send:LLLNPCommandSeek value:(sld.value * d)];
        PlayHaptic(YES);
    }
}

/* v2.2：独立音量 —— 只作用于音乐播放器（applyVolume），不影响系统音量 */
+ (void)volChanged:(UISlider *)sld {
    double v = sld.value;
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"LLL.volume"];
    LLLSetVolIcon(gVolIcon, (float)v);
    [[LLLNowPlaying shared] send:LLLNPCommandVolume value:v];

    /* 没播过网易云时命令桥是空的，滑条就成了摆设；这里直接找宿主应用音量 */
    MainViewController *host = [MainViewController cloudHost];
    if ([host respondsToSelector:@selector(applyVolume)]) {
        [host performSelector:@selector(applyVolume)];
    }
}

+ (void)onCacheTap:(id)sender {
    PlayHaptic(YES);
    gTransientText = @"正在清理缓存…";
    [self applyContent];
    if (gCacheLabel) gCacheLabel.text = gTransientText;
    /* LLLCacheCleanNow 内部只做一次 dispatch，真正的枚举在后台队列，主线程不卡 */
    LLLCacheCleanNow();
}

+ (void)onCloudTap:(id)sender {
    /* 【网易云入口修复】用常驻宿主 VC，不要每次 new 一个没人持有的控制器：
       临时 VC 会被 ARC 立刻回收，登录回调全打到 nil 上 → 点了没反应 */
    MainViewController *vc = [MainViewController cloudHost];
    [vc openCloudMusic];
}

/* 供 CacheCleaner 调用：自动清缓存的状态合并显示在灵动岛上 */
+ (void)clearCacheLabel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gCacheLabel) {
            gCacheLabel.text = @"";
            gCacheLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1];
        }
        gTransientText = nil;
        [self applyContent];
    });
}

+ (void)showCacheStatus:(NSString *)text count:(NSUInteger)count isError:(BOOL)isError {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self buildIfNeeded];
            if (!gCacheLabel) return;

            NSMutableString *t = [NSMutableString string];
            if (text.length) [t appendString:text];
            if (count > 0) [t appendFormat:@" · %lu 个", (unsigned long)count];
            NSString *line = [t copy];

            /* 【清缓存看不到岛修复】胶囊态也要能看见结果：临时盖住歌名 */
            gTransientText = line;
            if (!gShowing) [self showIsland];
            [self applyContent];

            gCacheLabel.text = line;
            if (isError) {
                gCacheLabel.textColor = [UIColor colorWithRed:1 green:0.42 blue:0.42 alpha:1];
            } else if ([text containsString:@"已清除"] || [text containsString:@"清理完毕"]) {
                gCacheLabel.textColor = [UIColor colorWithRed:0.30 green:0.85 blue:0.45 alpha:1];
            } else {
                gCacheLabel.textColor = [UIColor colorWithRed:1 green:0.62 blue:0.20 alpha:1];
            }
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearCacheLabel) object:nil];
            [self performSelector:@selector(clearCacheLabel) withObject:nil afterDelay:3.0];

            /* 没在放歌就把岛收回去，别一直挂在屏幕上 */
            LLLNowPlaying *np = [LLLNowPlaying shared];
            if (!np.playing && !gLegacyPlaying) {
                [gCollapseTimer invalidate];
                gCollapseTimer = [NSTimer timerWithTimeInterval:4.0 repeats:NO block:^(NSTimer *tm) {
                    @try {
                        if (![LLLNowPlaying shared].playing && !gLegacyPlaying) {
                            [LLLMusicIsland setExpanded:NO];
                            [LLLMusicIsland hide];
                        }
                    } @catch (__unused NSException *e) { }
                }];
                [[NSRunLoop mainRunLoop] addTimer:gCollapseTimer forMode:NSRunLoopCommonModes];
            }
        } @catch (__unused NSException *e) { }
    });
}

+ (void)onPlay:(id)s {
    LLLNowPlaying *np = [LLLNowPlaying shared];
    if (np.hasTrack) [np setPlaying:!np.playing];
    else gLegacyPlaying = !gLegacyPlaying;
    [np send:LLLNPCommandTogglePlay value:0];
    [self applyContent];
}

/* 旧点按式 seek 已由 UISlider（seekChanged/seekEnded）取代 */

#pragma mark - 对外

+ (void)setTapHandler:(void (^)(void))handler {
    gTapHandler = [handler copy];
}

+ (void)updateTitle:(NSString *)title playing:(BOOL)playing {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            gLegacyTitle = [title copy];
            gLegacyPlaying = playing;
            [self showIsland];
            if (!playing) [self scheduleCollapse];
            else {
                [gCollapseTimer invalidate];
                gCollapseTimer = nil;
            }
        } @catch (__unused NSException *e) { }
    });
}

@end
