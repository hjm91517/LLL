//
//  LLLMusicIsland.m
//  仿 Apple 灵动岛：胶囊态 ↔ 展开态，弹簧过渡，封面 + 跑马灯 + 波形 + 进度
//

#import "LLLMusicIsland.h"
#import "LLLNowPlaying.h"
#import <math.h>
#import "LLLAnim.h"
#import "AppTheme.h"

static const CGFloat kCompactW = 218, kCompactH = 38;
static const CGFloat kExpandW  = 348, kExpandH  = 158;

static UIWindow   *gWin    = nil;
static UIView     *gHost   = nil;
static UIView     *gPill   = nil;

static UIImageView *gArtSm = nil, *gArtLg = nil;
static UILabel     *gTitleSm = nil, *gTitleLg = nil, *gArtistLg = nil;
static UILabel     *gTimeLg = nil, *gDurLg = nil;
static UIView      *gBarsBox = nil;
static NSArray<UIView *> *gBars = nil;
static UIView      *gTrack = nil, *gFill = nil;
static UIView      *gCtrlRow = nil;
static UIButton    *gPlayBtn = nil, *gPrevBtn = nil, *gNextBtn = nil, *gCloseBtn = nil;

static NSTimer     *gTick = nil, *gCollapseTimer = nil;
static BOOL         gShowing = NO, gExpanded = NO, gBuilding = NO;
static NSString    *gLegacyTitle = nil;
static BOOL         gLegacyPlaying = NO;
static void (^gTapHandler)(void) = nil;

#pragma mark - 穿透宿主

@interface LLLIslandHostView : UIView
@end
@implementation LLLIslandHostView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    return (v == self) ? nil : v;
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
+ (void)onTap:(UIGestureRecognizer *)g;
+ (void)onLongPress:(UILongPressGestureRecognizer *)g;
+ (void)onPrev:(id)s;
+ (void)onPlay:(id)s;
+ (void)onNext:(id)s;
+ (void)onClose:(id)s;
+ (void)onSeek:(UITapGestureRecognizer *)g;
@end

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
    gWin = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                 : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
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
    gWin.userInteractionEnabled = YES;

    gHost = [[LLLIslandHostView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    gHost.backgroundColor = UIColor.clearColor;
    gHost.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIViewController *vc = [UIViewController new];
    vc.view = gHost;
    gWin.rootViewController = vc;
    gWin.hidden = NO;

    gPill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCompactW, kCompactH)];
    gPill.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.94];
    gPill.layer.cornerRadius = kCompactH / 2.0;
    gPill.layer.cornerCurve = kCACornerCurveContinuous;
    gPill.layer.borderWidth = 0.6;
    gPill.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    gPill.clipsToBounds = YES;
    gPill.userInteractionEnabled = YES;
    gPill.alpha = 0;
    [gHost addSubview:gPill];

    [gPill addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)]];
    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
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

    gTitleSm = [self label:12 weight:UIFontWeightSemibold color:UIColor.whiteColor];
    gTitleSm.frame = CGRectMake(39, 0, 120, kCompactH);
    [gPill addSubview:gTitleSm];

    gTitleLg = [self label:15 weight:UIFontWeightSemibold color:UIColor.whiteColor];
    gTitleLg.frame = CGRectMake(80, 22, kExpandW - 128, 20);
    gTitleLg.hidden = YES;
    [gPill addSubview:gTitleLg];

    gArtistLg = [self label:11 weight:UIFontWeightRegular color:[UIColor colorWithWhite:0.62 alpha:1]];
    gArtistLg.frame = CGRectMake(80, 44, kExpandW - 128, 16);
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

    gTrack = [[UIView alloc] initWithFrame:CGRectMake(18, 92, kExpandW - 36, 4)];
    gTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16];
    gTrack.layer.cornerRadius = 2;
    gTrack.clipsToBounds = YES;
    gTrack.hidden = YES;
    gTrack.userInteractionEnabled = YES;
    [gTrack addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSeek:)]];
    [gPill addSubview:gTrack];

    gFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 4)];
    gFill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.94];
    [gTrack addSubview:gFill];

    gTimeLg = [self label:10 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.72 alpha:1]];
    gTimeLg.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
    gTimeLg.frame = CGRectMake(18, 100, 60, 14);
    gTimeLg.hidden = YES;
    [gPill addSubview:gTimeLg];

    gDurLg = [self label:10 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.62 alpha:1]];
    gDurLg.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
    gDurLg.textAlignment = NSTextAlignmentRight;
    gDurLg.frame = CGRectMake(kExpandW - 78, 100, 60, 14);
    gDurLg.hidden = YES;
    [gPill addSubview:gDurLg];

    gCtrlRow = [[UIView alloc] initWithFrame:CGRectMake(0, 118, kExpandW, 32)];
    gCtrlRow.hidden = YES;
    [gPill addSubview:gCtrlRow];

    gPrevBtn = [self button:@"backward.fill" fallback:@"<<" size:15];
    gPrevBtn.frame = CGRectMake(kExpandW / 2 - 92, 0, 40, 32);
    [gPrevBtn addTarget:self action:@selector(onPrev:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gPrevBtn];

    gPlayBtn = [self button:@"play.fill" fallback:@"PLAY" size:17];
    gPlayBtn.frame = CGRectMake(kExpandW / 2 - 36, -2, 72, 36);
    gPlayBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    gPlayBtn.layer.cornerRadius = 18;
    gPlayBtn.layer.cornerCurve = kCACornerCurveContinuous;
    [gPlayBtn addTarget:self action:@selector(onPlay:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gPlayBtn];

    gNextBtn = [self button:@"forward.fill" fallback:@">>" size:15];
    gNextBtn.frame = CGRectMake(kExpandW / 2 + 52, 0, 40, 32);
    [gNextBtn addTarget:self action:@selector(onNext:) forControlEvents:UIControlEventTouchUpInside];
    [gCtrlRow addSubview:gNextBtn];

    gCloseBtn = [self button:@"chevron.down" fallback:@"v" size:11];
    gCloseBtn.frame = CGRectMake(kExpandW - 40, 18, 28, 28);
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

+ (void)layoutForExpanded:(BOOL)expanded animated:(BOOL)animated {
    if (!gPill) return;
    CGFloat w = expanded ? kExpandW : kCompactW;
    CGFloat h = expanded ? kExpandH : kCompactH;

    void (^apply)(void) = ^{
        CGSize host = gHost.bounds.size;
        if (host.width < 10) host = UIScreen.mainScreen.bounds.size;
        gPill.frame = CGRectMake((host.width - w) / 2.0, [self topInset] + 6, w, h);
        gPill.layer.cornerRadius = expanded ? 30 : (kCompactH / 2.0);

        gArtSm.hidden = expanded;
        gTitleSm.hidden = expanded;
        gBarsBox.hidden = expanded;

        gArtLg.hidden = !expanded;
        gTitleLg.hidden = !expanded;
        gArtistLg.hidden = !expanded;
        gTrack.hidden = !expanded;
        gTimeLg.hidden = !expanded;
        gDurLg.hidden = !expanded;
        gCtrlRow.hidden = !expanded;
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

    NSString *title = np.title.length ? np.title : gLegacyTitle;
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
    CGRect f = gFill.frame;
    f.size.width = gTrack.bounds.size.width * ratio;
    gFill.frame = f;
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
    }
    [self layoutForExpanded:gExpanded animated:YES];
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gPill || !gShowing) return;
            gShowing = NO;
            gExpanded = NO;
            [self daemonStop];
            [gCollapseTimer invalidate];
            gCollapseTimer = nil;
            [gPill.layer removeAllAnimations];
            [UIView animateWithDuration:0.22 animations:^{
                gPill.alpha = 0;
                gPill.transform = CGAffineTransformMakeScale(0.86, 0.86);
            } completion:^(BOOL f) {
                gPill.hidden = YES;
                gPill.transform = CGAffineTransformIdentity;
            }];
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

+ (void)onPlay:(id)s {
    LLLNowPlaying *np = [LLLNowPlaying shared];
    if (np.hasTrack) [np setPlaying:!np.playing];
    else gLegacyPlaying = !gLegacyPlaying;
    [np send:LLLNPCommandTogglePlay value:0];
    [self applyContent];
}

+ (void)onSeek:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:gTrack];
    CGFloat w = MAX(1, gTrack.bounds.size.width);
    double ratio = MAX(0, MIN(1, p.x / w));
    LLLNowPlaying *np = [LLLNowPlaying shared];
    [np send:LLLNPCommandSeek value:ratio * MAX(0.0, np.duration)];
    [np updateElapsed:ratio * np.duration duration:np.duration];
    [self applyContent];
}

#pragma mark - 对外

+ (void)setTapHandler:(void (^)(void))handler {
    gTapHandler = [handler copy];
}

+ (void)updateTitle:(NSString *)title playing:(BOOL)playing {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            gLegacyTitle = [title copy];
            gLegacyPlaying = playing;
            gExpanded = NO;
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
