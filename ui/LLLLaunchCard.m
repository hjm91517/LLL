//
//  LLLLaunchCard.m
//  自带窗口 / 遮罩 / 卡片，不依赖 LLLUiKit 的内部静态函数。
//

#import "LLLLaunchCard.h"
#import "LLLAnim.h"
#import "PluginInfo.h"
#import "AppTheme.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"

static UIWindow *gLaunchWin = nil;

/* 普通 UIWindow 透明全屏常驻会把触摸全吃掉（登录/设置都点不了） */
@interface LLLCardWin : UIWindow @end
@implementation LLLCardWin
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *h = [super hitTest:point withEvent:event];
    if (h == self || (h && h == self.rootViewController.view)) return nil;
    return h;
}
@end

static UIWindow *LLLCardWindow(void) {
    if (gLaunchWin) return gLaunchWin;

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    gLaunchWin = scene ? [[BaseOverlayWindow alloc] initWithWindowScene:scene]
                       : [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    gLaunchWin.windowLevel = UIWindowLevelAlert - 1;
    gLaunchWin.backgroundColor = UIColor.clearColor;
    gLaunchWin.rootViewController = [UIViewController new];
    return gLaunchWin;
}

static UIView *LLLCardDim(UIView *host) {
    UIView *dim = [[UIView alloc] initWithFrame:host.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    dim.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{ dim.alpha = 1; }];
    return dim;
}

static UIView *LLLCardBox(CGFloat width) {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 120)];
    card.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.98];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 0.6;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    card.clipsToBounds = YES;
    return card;
}

static CAShapeLayer *LLLRing(CGRect box, CGFloat width, UIColor *color) {
    CAShapeLayer *l = [CAShapeLayer layer];
    CGFloat side = MIN(box.size.width, box.size.height);
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(box), CGRectGetMidY(box))
                                                        radius:(side - width) / 2.0
                                                    startAngle:-M_PI_2
                                                      endAngle:(M_PI * 1.5)
                                                     clockwise:YES];
    l.path = path.CGPath;
    l.fillColor = UIColor.clearColor.CGColor;
    l.strokeColor = color.CGColor;
    l.lineWidth = width;
    l.lineCap = kCALineCapRound;
    l.strokeStart = 0;
    l.strokeEnd = 0;
    return l;
}

static void LLLRingSet(CAShapeLayer *l, CGFloat p) {
    if (!l) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    l.strokeEnd = MAX(0, MIN(1, p));
    [CATransaction commit];
}

#pragma mark - 启动卡片

static UIView *gLCard = nil;
static CAShapeLayer *gLRing = nil;
static UILabel *gLPct = nil, *gLStatus = nil;
static NSTimer *gLTimer = nil;
static CGFloat gLShown = 0, gLTarget = 0.82;
static BOOL gLDone = NO;

static void LLLaunchRefresh(void) {
    LLLRingSet(gLRing, gLShown);
    if (gLPct) gLPct.text = [NSString stringWithFormat:@"%.0f%%", gLShown * 100];
}

void LLLLaunchSetProgress(CGFloat p, NSString *status) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            gLTarget = MAX(0, MIN(1, p));
            if (status.length && gLStatus) gLStatus.text = status;
            if (!gLCard) return;

            if (p >= 0.999) {
                gLDone = YES;
                gLShown = 1;
                LLLaunchRefresh();
                if (gLStatus) gLStatus.text = status.length ? status : @"准备就绪";
                [gLTimer invalidate];
                gLTimer = nil;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    @try {
                        if (!gLCard) return;
                        UIView *card = gLCard;
                        gLCard = nil;
                        /* 【交互修复】连同遮罩一起移除，并隐藏窗口：
                         * 否则透明窗口+暗色遮罩常驻 → 全屏触摸黑洞 */
                        UIView *host = card.superview;
                        [UIView animateWithDuration:0.3 animations:^{
                            card.alpha = 0;
                            for (UIView *v in host.subviews)
                                if (v.tag == 99131 || v.tag == 99141) v.alpha = 0;
                        } completion:^(BOOL f) {
                            [card removeFromSuperview];
                            for (UIView *v in host.subviews)
                                if (v.tag == 99131 || v.tag == 99141) [v removeFromSuperview];
                            gLaunchWin.hidden = YES;
                        }];
                    } @catch (__unused NSException *e) { }
                });
            }
        } @catch (__unused NSException *e) { }
    });
}

void LLLShowLaunch(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (gLCard) return;

            UIWindow *win = LLLCardWindow();
            win.hidden = NO;
            UIView *host = win.rootViewController.view;
            if (!host) return;

            UIView *dim = LLLCardDim(host);
            dim.tag = 99131;
            [host addSubview:dim];

            UIView *card = LLLCardBox(272);
            card.tag = 99132;
            card.frame = CGRectMake(0, 0, 272, 292);
            card.alpha = 0;
            card.transform = CGAffineTransformMakeScale(0.94, 0.94);
            [host addSubview:card];
            gLCard = card;

            UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(18, 20, 236, 26)];
            title.text = @"bbhj online";
            title.font = [UIFont systemFontOfSize:19 weight:UIFontWeightHeavy];
            title.textColor = UIColor.whiteColor;
            title.textAlignment = NSTextAlignmentCenter;
            [card addSubview:title];

            UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(18, 46, 236, 16)];
            sub.text = @"资源注入器 · 正在唤醒";
            sub.font = [UIFont systemFontOfSize:11];
            sub.textColor = [UIColor colorWithWhite:0.55 alpha:1];
            sub.textAlignment = NSTextAlignmentCenter;
            [card addSubview:sub];

            CGRect ringBox = CGRectMake((272 - 108) / 2, 78, 108, 108);
            UIView *ringHost = [[UIView alloc] initWithFrame:ringBox];
            [card addSubview:ringHost];

            CAShapeLayer *track = LLLRing(ringHost.bounds, 8, [UIColor colorWithWhite:1 alpha:0.10]);
            track.strokeEnd = 1;
            [ringHost.layer addSublayer:track];

            gLRing = LLLRing(ringHost.bounds, 8, [UIColor colorWithWhite:0.97 alpha:1]);
            [ringHost.layer addSublayer:gLRing];

            gLPct = [[UILabel alloc] initWithFrame:ringHost.bounds];
            gLPct.text = @"0%";
            gLPct.font = [UIFont monospacedDigitSystemFontOfSize:20 weight:UIFontWeightHeavy];
            gLPct.textColor = UIColor.whiteColor;
            gLPct.textAlignment = NSTextAlignmentCenter;
            [ringHost addSubview:gLPct];

            gLStatus = [[UILabel alloc] initWithFrame:CGRectMake(18, 196, 236, 18)];
            gLStatus.text = @"加载内核…";
            gLStatus.font = [UIFont systemFontOfSize:12];
            gLStatus.textColor = [UIColor colorWithWhite:0.66 alpha:1];
            gLStatus.textAlignment = NSTextAlignmentCenter;
            [card addSubview:gLStatus];

            UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(18, 252, 236, 16)];
            foot.text = [NSString stringWithFormat:@"LLL %@", kPluginVersion];
            foot.font = [UIFont systemFontOfSize:10];
            foot.textColor = [UIColor colorWithWhite:0.34 alpha:1];
            foot.textAlignment = NSTextAlignmentCenter;
            [card addSubview:foot];

            gLShown = 0;
            gLTarget = 0.82;
            gLDone = NO;
            LLLaunchRefresh();

            card.center = CGPointMake(LLLUIKitHostSize(host).width / 2, LLLUIKitHostSize(host).height / 2);
            card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                                  | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            LLLSpring(0.34, 0.86, ^{ card.alpha = 1; card.transform = CGAffineTransformIdentity; });

            gLTimer = [NSTimer timerWithTimeInterval:0.05 repeats:YES block:^(NSTimer *t) {
                @try {
                    if (!gLCard) { [t invalidate]; return; }
                    if (gLDone) return;
                    if (gLTarget > gLShown) gLShown = MIN(gLTarget, gLShown + 0.012);
                    LLLaunchRefresh();
                } @catch (__unused NSException *e) { }
            }];
            [[NSRunLoop mainRunLoop] addTimer:gLTimer forMode:NSRunLoopCommonModes];

            // 兜底：3 秒内没人报进度就自己走完，别把用户挡在启动页
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                LLLLaunchSetProgress(1.0, @"准备就绪");
            });
        } @catch (__unused NSException *e) { }
    });
}

#pragma mark - 注入进度

static UIView *gPCard = nil;
static CAShapeLayer *gPRing = nil;
static UILabel *gPTitle = nil, *gPPct = nil, *gPCounter = nil;
static UITextView *gPLog = nil;
static NSMutableArray<NSString *> *gPLines = nil;
static BOOL gPCancel = NO;

BOOL LLLProgressCancelled(void) { return gPCancel; }

@interface LLLCancelTarget : NSObject
- (void)cancel;
@end

@implementation LLLCancelTarget
- (void)cancel { gPCancel = YES; LLLProgressHide(); }
@end

static LLLCancelTarget *LLLCancelTargetShared(void) {
    static LLLCancelTarget *t;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [LLLCancelTarget new]; });
    return t;
}

void LLLProgressShow(NSString *title) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            gPCancel = NO;
            if (gPCard) {
                gPTitle.text = title.length ? title : @"注入中";
                return;
            }

            UIWindow *win = LLLCardWindow();
            win.hidden = NO;
            UIView *host = win.rootViewController.view;

            UIView *dim = LLLCardDim(host);
            dim.tag = 99141;
            [host addSubview:dim];

            UIView *card = LLLCardBox(300);
            card.tag = 99142;
            card.frame = CGRectMake(0, 0, 300, 356);
            [host addSubview:card];
            gPCard = card;

            gPTitle = [[UILabel alloc] initWithFrame:CGRectMake(18, 16, 264, 22)];
            gPTitle.text = title.length ? title : @"注入中";
            gPTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
            gPTitle.textColor = UIColor.whiteColor;
            [card addSubview:gPTitle];

            CGRect ringBox = CGRectMake(18, 48, 92, 92);
            UIView *ringHost = [[UIView alloc] initWithFrame:ringBox];
            [card addSubview:ringHost];

            CAShapeLayer *track = LLLRing(ringHost.bounds, 7, [UIColor colorWithWhite:1 alpha:0.10]);
            track.strokeEnd = 1;
            [ringHost.layer addSublayer:track];

            gPRing = LLLRing(ringHost.bounds, 7, [UIColor colorWithWhite:0.97 alpha:1]);
            [ringHost.layer addSublayer:gPRing];

            gPPct = [[UILabel alloc] initWithFrame:ringHost.bounds];
            gPPct.text = @"0%";
            gPPct.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightHeavy];
            gPPct.textColor = UIColor.whiteColor;
            gPPct.textAlignment = NSTextAlignmentCenter;
            [ringHost addSubview:gPPct];

            gPCounter = [[UILabel alloc] initWithFrame:CGRectMake(126, 66, 158, 18)];
            gPCounter.text = @"0 / 0";
            gPCounter.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
            gPCounter.textColor = [UIColor colorWithWhite:0.78 alpha:1];
            [card addSubview:gPCounter];

            UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(126, 88, 158, 40)];
            hint.text = @"正在写入资源\n请勿杀进程";
            hint.numberOfLines = 2;
            hint.font = [UIFont systemFontOfSize:11];
            hint.textColor = [UIColor colorWithWhite:0.5 alpha:1];
            [card addSubview:hint];

            gPLog = [[UITextView alloc] initWithFrame:CGRectMake(10, 150, 280, 148)];
            gPLog.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
            gPLog.layer.cornerRadius = 10;
            gPLog.editable = NO;
            gPLog.scrollEnabled = YES;
            gPLog.showsVerticalScrollIndicator = YES;
            gPLog.textColor = [UIColor colorWithWhite:0.78 alpha:1];
            gPLog.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
            gPLog.textContainerInset = UIEdgeInsetsMake(6, 6, 6, 6);
            [card addSubview:gPLog];

            gPLines = [NSMutableArray array];

            UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            cancelBtn.frame = CGRectMake(14, 306, 272, 40);
            cancelBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
            cancelBtn.layer.cornerRadius = 11;
            [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
            [cancelBtn setTitleColor:[UIColor colorWithRed:1 green:0.4 blue:0.4 alpha:1]
                            forState:UIControlStateNormal];
            cancelBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            [cancelBtn addTarget:LLLCancelTargetShared()
                         action:@selector(cancel)
               forControlEvents:UIControlEventTouchUpInside];
            [card addSubview:cancelBtn];

            card.center = CGPointMake(LLLUIKitHostSize(host).width / 2, LLLUIKitHostSize(host).height / 2);
            card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                                  | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            card.alpha = 0;
            card.transform = CGAffineTransformMakeScale(0.94, 0.94);
            LLLSpring(0.32, 0.86, ^{ card.alpha = 1; card.transform = CGAffineTransformIdentity; });
        } @catch (__unused NSException *e) { }
    });
}

void LLLProgressSetPercent(CGFloat p) {
    if (p < 0) p = 0;
    if (p > 1) p = 1;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (gPPct) gPPct.text = [NSString stringWithFormat:@"%.0f%%", p * 100];
            LLLRingSet(gPRing, p);
        } @catch (__unused NSException *e) { }
    });
}

void LLLProgressUpdate(NSString *counter) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPCounter && counter.length) gPCounter.text = counter;
    });
}

void LLLProgressLine(NSString *line) {
    if (!line.length) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gPLog || !gPLines) return;
            [gPLines addObject:line];
            while (gPLines.count > 40) [gPLines removeObjectAtIndex:0];
            gPLog.text = [gPLines componentsJoinedByString:@"\n"];
            if (gPLog.text.length > 0)
                [gPLog scrollRangeToVisible:NSMakeRange(gPLog.text.length - 1, 1)];
        } @catch (__unused NSException *e) { }
    });
}

void LLLProgressHide(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!gPCard) return;
            UIView *card = gPCard;
            gPCard = nil; gPTitle = nil; gPCounter = nil; gPLog = nil;
            gPRing = nil; gPPct = nil;
            [gPLines removeAllObjects]; gPLines = nil;

            UIView *host = card.superview;
            UIView *dim = nil;
            for (UIView *v in host.subviews) if (v.tag == 99141) { dim = v; break; }
            [UIView animateWithDuration:0.2 animations:^{ card.alpha = 0; dim.alpha = 0; }
                             completion:^(BOOL f) {
                [card removeFromSuperview];
                [dim removeFromSuperview];
                gLaunchWin.hidden = YES;
                gLaunchWin.hidden = YES;   /* 【交互修复】内容清空后必须藏窗，否则吞掉全部触摸 */
            }];
        } @catch (__unused NSException *e) { }
    });
}
