//
//  LLLMusicIsland.m
//  仿灵动岛胶囊：顶部常驻，左侧音符图标，中间歌名，右侧随音乐跳动的波形
//

#import "LLLMusicIsland.h"
#import "LLLAnim.h"
#import "AppTheme.h"

static UIWindow        *gIslandWin   = nil;
static UIView          *gCapsule     = nil;
static UILabel         *gTitleLabel  = nil;
static UIImageView     *gIcon        = nil;
static NSArray<UIView *> *gBars      = nil;
static NSTimer         *gBarTimer    = nil;
static NSTimer         *gHideTimer   = nil;
static void (^gTapHandler)(void)     = nil;
static BOOL             gShowing     = NO;

@implementation LLLMusicIsland

#pragma mark - 窗口

+ (UIWindow *)islandWindow {
    if (gIslandWin) return gIslandWin;

    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        gIslandWin = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                           : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    } else {
        gIslandWin = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }

    gIslandWin.windowLevel = UIWindowLevelStatusBar + 500;
    gIslandWin.backgroundColor = UIColor.clearColor;
    gIslandWin.userInteractionEnabled = NO;
    gIslandWin.rootViewController = [UIViewController new];
    return gIslandWin;
}

#pragma mark - 构建

+ (CGFloat)topInset {
    CGFloat top = 14;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                UIStatusBarManager *m = ((UIWindowScene *)s).statusBarManager;
                if (m) top = MAX(8, CGRectGetHeight(m.statusBarFrame));
                break;
            }
        }
    }
    return top;
}

+ (void)buildIfNeeded {
    if (gCapsule) return;

    UIWindow *win = [self islandWindow];
    UIView *host = win.rootViewController.view;
    CGFloat w = MAX(host.bounds.size.width, 320);

    gCapsule = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 236, 40)];
    gCapsule.center = CGPointMake(w / 2, [self topInset] + 24);
    gCapsule.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.92];
    gCapsule.layer.cornerRadius = 20;
    gCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    gCapsule.layer.borderWidth = 0.6;
    gCapsule.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.14].CGColor;
    gCapsule.clipsToBounds = YES;
    gCapsule.userInteractionEnabled = YES;
    [host addSubview:gCapsule];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [gCapsule addGestureRecognizer:tap];

    // 音符图标
    gIcon = [[UIImageView alloc] initWithFrame:CGRectMake(14, 11, 18, 18)];
    gIcon.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
        gIcon.image = [UIImage systemImageNamed:@"music.note" withConfiguration:cfg];
    }
    gIcon.tintColor = LLLAccentColor();
    [gCapsule addSubview:gIcon];

    // 歌名
    gTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(38, 0, 140, 40)];
    gTitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    gTitleLabel.textColor = UIColor.whiteColor;
    gTitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    gTitleLabel.text = @"未在播放";
    [gCapsule addSubview:gTitleLabel];

    // 波形 4 根
    NSMutableArray *bars = [NSMutableArray array];
    for (int i = 0; i < 4; i++) {
        UIView *b = [[UIView alloc] initWithFrame:CGRectMake(186 + i * 8, 14, 4, 12)];
        b.backgroundColor = LLLAccentColor();
        b.layer.cornerRadius = 2;
        [gCapsule addSubview:b];
        [bars addObject:b];
    }
    gBars = bars;

    gCapsule.alpha = 0;
    gCapsule.transform = CGAffineTransformMakeScale(0.6, 0.6);
}

#pragma mark - 波形动画

+ (void)startBars {
    if (gBarTimer) return;
    gBarTimer = [NSTimer timerWithTimeInterval:0.18 repeats:YES block:^(NSTimer *t) {
        for (NSUInteger i = 0; i < gBars.count; i++) {
            UIView *b = gBars[i];
            CGFloat h = 6 + (CGFloat)(arc4random_uniform(14));
            [UIView animateWithDuration:0.16
                                  delay:(0.02 * i)
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                CGRect f = b.frame;
                f.origin.y = 20 - h;
                f.size.height = h;
                b.frame = f;
            } completion:nil];
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:gBarTimer forMode:NSRunLoopCommonModes];
}

+ (void)stopBars {
    [gBarTimer invalidate];
    gBarTimer = nil;
    for (UIView *b in gBars) {
        CGRect f = b.frame;
        f.origin.y = 14;
        f.size.height = 12;
        b.frame = f;
    }
}

#pragma mark - 对外

+ (void)setTapHandler:(void (^)(void))handler {
    gTapHandler = [handler copy];
}

+ (void)handleTap {
    if (gTapHandler) gTapHandler();
}

+ (void)updateTitle:(NSString *)title playing:(BOOL)playing {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [self buildIfNeeded];
            if (!gCapsule) return;

            [gHideTimer invalidate];
            gHideTimer = nil;

            if (title.length) gTitleLabel.text = title;

            if (!gShowing) {
                gShowing = YES;
                gCapsule.hidden = NO;
                gCapsule.alpha = 0;
                gCapsule.transform = CGAffineTransformMakeScale(0.6, 0.6);
                LLLSpring(0.42, 0.78, ^{
                    gCapsule.alpha = 1;
                    gCapsule.transform = CGAffineTransformIdentity;
                });
            }

            if (playing) {
                [self startBars];
            } else {
                [self stopBars];
                gHideTimer = [NSTimer timerWithTimeInterval:2.0 repeats:NO block:^(NSTimer *t) {
                    [LLLMusicIsland hide];
                }];
                [[NSRunLoop mainRunLoop] addTimer:gHideTimer forMode:NSRunLoopCommonModes];
            }
        } @catch (__unused NSException *e) { }
    });
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gCapsule || !gShowing) return;
            gShowing = NO;
            [self stopBars];
            [gHideTimer invalidate];
            gHideTimer = nil;

            [UIView animateWithDuration:0.22 animations:^{
                gCapsule.alpha = 0;
                gCapsule.transform = CGAffineTransformMakeScale(0.7, 0.7);
            } completion:^(BOOL f) {
                gCapsule.hidden = YES;
            }];
        } @catch (__unused NSException *e) { }
    });
}

@end
