//
//  LLLUiKit.m
//  自制弹层：不用 UIAlertController，走独立 window，任何界面都能弹。
//

#import "LLLUiKit.h"
#import "LLLAnim.h"
#import "AppTheme.h"
#import "BaseComponents.h"
#import <objc/runtime.h>

#pragma mark - 按钮 block 包装

@interface UIButton (LLLBlock)
- (void)lll_onTap:(void (^)(void))block;
@end

@implementation UIButton (LLLBlock)
- (void)lll_onTap:(void (^)(void))block {
    if (!block) return;
    objc_setAssociatedObject(self, @selector(lll_onTap:), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:@selector(lll_handleTap) forControlEvents:UIControlEventTouchUpInside];
}
- (void)lll_handleTap {
    void (^b)(void) = objc_getAssociatedObject(self, @selector(lll_onTap:));
    if (b) b();
}
@end

#pragma mark - 遮罩窗口

static UIWindow *gLLLWin = nil;

static UIWindow *LLLOverlayWindow(void) {
    if (gLLLWin) return gLLLWin;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        /* 【交互修复】必须用 BaseOverlayWindow（带 hitTest 穿透）：
         * 普通 UIWindow 全屏常驻会把所有触摸吞进空的根视图，导致整个界面点不动 */
        gLLLWin = scene ? [[BaseOverlayWindow alloc] initWithWindowScene:scene]
                        : [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    } else {
        gLLLWin = [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    gLLLWin.windowLevel = UIWindowLevelAlert + 100;
    gLLLWin.backgroundColor = UIColor.clearColor;
    gLLLWin.rootViewController = [UIViewController new];
    gLLLWin.hidden = NO;
    return gLLLWin;
}

CGSize LLLUIKitHostSize(UIView *host) {
    CGSize s = host ? host.bounds.size : CGSizeZero;
    if (s.width < 16 || s.height < 16) {
        CGSize scr = UIScreen.mainScreen.bounds.size;
        if (scr.width > 16) s = scr;
    }
    return s;
}

#pragma mark - 启动动画

void LLLShowSplash(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = LLLOverlayWindow();
            UIView *host = win.rootViewController.view;
            if (!host) return;

            UIView *cover = [[UIView alloc] initWithFrame:host.bounds];
            cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            cover.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.97];
            [host addSubview:cover];

            UIView *glow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, 260)];
            glow.center = CGPointMake(LLLUIKitHostSize(host).width / 2,
                                      LLLUIKitHostSize(host).height / 2 - 20);
            glow.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                                  | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            glow.backgroundColor = [LLLAccentColor() colorWithAlphaComponent:0.18];
            glow.layer.cornerRadius = 130;
            glow.alpha = 0;
            [cover addSubview:glow];

            UILabel *title = [UILabel new];
            title.text = @"欢迎使用材质注入器";
            title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
            title.textColor = UIColor.whiteColor;
            title.textAlignment = NSTextAlignmentCenter;
            title.alpha = 0;
            title.translatesAutoresizingMaskIntoConstraints = NO;
            [cover addSubview:title];

            UILabel *sub = [UILabel new];
            sub.text = @"LLL · by 豪蚧二改";
            sub.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
            sub.textColor = [LLLAccentColor() colorWithAlphaComponent:0.92];
            sub.textAlignment = NSTextAlignmentCenter;
            sub.alpha = 0;
            sub.translatesAutoresizingMaskIntoConstraints = NO;
            [cover addSubview:sub];

            [NSLayoutConstraint activateConstraints:@[
                [title.centerXAnchor constraintEqualToAnchor:cover.centerXAnchor],
                [title.centerYAnchor constraintEqualToAnchor:cover.centerYAnchor constant:-12],
                [sub.centerXAnchor constraintEqualToAnchor:cover.centerXAnchor],
                [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
            ]];

            [UIView animateWithDuration:1.4 delay:0.05
                                options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat
                             animations:^{ glow.alpha = 1; } completion:nil];

            title.transform = CGAffineTransformMakeTranslation(0, 14);
            LLLSpring(0.55, 0.86, ^{
                title.alpha = 1;
                title.transform = CGAffineTransformIdentity;
            });

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                LLLSpring(0.5, 0.9, ^{ sub.alpha = 1; });
            });

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.45 animations:^{
                    cover.alpha = 0;
                    cover.transform = CGAffineTransformMakeScale(1.05, 1.05);
                } completion:^(BOOL f) {
                    [cover removeFromSuperview];
                    if (host.subviews.count == 0) win.hidden = YES;
                }];
            });
        } @catch (__unused NSException *e) { }
    });
}


#pragma mark - 列表数据源

@interface LLLListSheet : NSObject <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSArray<NSString *> *items;
@property (nonatomic, copy) void (^onPick)(NSInteger);
@property (nonatomic, copy) void (^onClose)(void);
@end

@implementation LLLListSheet

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"bbhj.cell";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:cid];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        c.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
        c.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        c.textLabel.textColor = UIColor.whiteColor;
        c.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        UIView *sel = [UIView new];
        sel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
        c.selectedBackgroundView = sel;
    }
    c.textLabel.text = (ip.row < (NSInteger)_items.count) ? _items[(NSUInteger)ip.row] : @"";
    return c;
}

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip { return 44; }

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:NO];
    NSInteger idx = ip.row;
    void (^close)(void) = _onClose;
    void (^pick)(NSInteger) = _onPick;
    if (close) close();
    if (pick) pick(idx);
}

@end

#pragma mark - 卡片基座

static UIView *LLLCardDim(UIView *host) {
    UIView *dim = [[UIView alloc] initWithFrame:host.bounds];
    dim.tag = 99011;
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    return dim;
}

static UIView *LLLNewCard(CGFloat width) {
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 10)];
    card.tag = 99012;
    card.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.98];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    card.clipsToBounds = YES;
    return card;
}

static void LLLPresent(UIView *card) {
    UIWindow *win = LLLOverlayWindow();
    win.hidden = NO;
    UIView *host = win.rootViewController.view;

    UIView *dim = LLLCardDim(host);
    [host addSubview:dim];
    [host addSubview:card];

    card.center = CGPointMake(LLLUIKitHostSize(host).width / 2,
                              LLLUIKitHostSize(host).height - card.bounds.size.height / 2 - 30);
    card.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                          | UIViewAutoresizingFlexibleTopMargin;
    dim.alpha = 0;
    card.alpha = 0;
    card.transform = CGAffineTransformMakeTranslation(0, 240);

    [UIView animateWithDuration:0.2 animations:^{ dim.alpha = 1; }];
    LLLSpring(0.42, 0.84, ^{
        card.alpha = 1;
        card.transform = CGAffineTransformIdentity;
    });
}

static void LLLDismissAnimated(UIView *card) {
    UIView *host = card.superview;
    if (!host) return;
    UIView *dim = nil;
    for (UIView *v in host.subviews) {
        if (v.tag == 99011) { dim = v; break; }
    }
    [UIView animateWithDuration:0.2 animations:^{
        card.alpha = 0;
        card.transform = CGAffineTransformMakeTranslation(0, 200);
        dim.alpha = 0;
    } completion:^(BOOL f) {
        [card removeFromSuperview];
        [dim removeFromSuperview];
        if (host.subviews.count == 0) gLLLWin.hidden = YES;
    }];
}

#pragma mark - 弹层 API

void LLLShowSheet(NSString *title,
                  NSString *message,
                  NSArray<NSString *> *buttons,
                  BOOL destructiveLast,
                  void (^cb)(NSInteger)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = LLLOverlayWindow();
            UIView *host = win.rootViewController.view;
            CGFloat w = MIN(360, host.bounds.size.width - 48);
            __block UIView *card = LLLNewCard(w);

            CGFloat y = 18;

            if (title.length) {
                UILabel *l = [UILabel new];
                l.text = title;
                l.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
                l.textColor = UIColor.whiteColor;
                l.textAlignment = NSTextAlignmentCenter;
                l.numberOfLines = 0;
                l.frame = CGRectMake(20, y, w - 40, 22);
                [card addSubview:l];
                y += 30;
            }
            if (message.length) {
                UILabel *l = [UILabel new];
                l.text = message;
                l.font = [UIFont systemFontOfSize:13];
                l.textColor = [UIColor colorWithWhite:0.72 alpha:1];
                l.textAlignment = NSTextAlignmentCenter;
                l.numberOfLines = 0;
                CGSize sz = [l sizeThatFits:CGSizeMake(w - 40, 1000)];
                l.frame = CGRectMake(20, y, w - 40, sz.height);
                [card addSubview:l];
                y += sz.height + 8;
            }
            y += 6;

            for (NSUInteger i = 0; i < buttons.count; i++) {
                UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
                b.frame = CGRectMake(14, y, w - 28, 46);
                b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
                b.layer.cornerRadius = 12;
                b.layer.cornerCurve = kCACornerCurveContinuous;
                BOOL danger = destructiveLast && i == buttons.count - 1 && buttons.count > 1;
                [b setTitle:buttons[i] forState:UIControlStateNormal];
                [b setTitleColor:(danger ? [UIColor colorWithRed:1 green:0.36 blue:0.36 alpha:1]
                                         : UIColor.whiteColor)
                        forState:UIControlStateNormal];
                b.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
                NSInteger idx = (NSInteger)i;
                [b lll_onTap:^{
                    UIView *c = card;
                    LLLDismissAnimated(c);
                    if (cb) cb(idx);
                }];
                [card addSubview:b];
                y += 54;
            }

            y += 4;
            card.frame = CGRectMake(0, 0, w, y);
            LLLPresent(card);
        } @catch (__unused NSException *e) { }
    });
}

void LLLShowList(NSString *title,
                 NSString *message,
                 NSArray<NSString *> *items,
                 void (^cb)(NSInteger)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = LLLOverlayWindow();
            UIView *host = win.rootViewController.view;

            CGFloat w = MIN(380, host.bounds.size.width - 40);
            CGFloat maxH = MIN(560, host.bounds.size.height - 120);
            __block UIView *card = LLLNewCard(w);

            CGFloat y = 16;
            UILabel *l = [UILabel new];
            l.text = title.length ? title : @"请选择";
            l.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
            l.textColor = UIColor.whiteColor;
            l.textAlignment = NSTextAlignmentCenter;
            l.frame = CGRectMake(20, y, w - 40, 22);
            [card addSubview:l];
            y += 28;

            if (message.length) {
                UILabel *m = [UILabel new];
                m.text = message;
                m.font = [UIFont systemFontOfSize:12];
                m.textColor = [UIColor colorWithWhite:0.66 alpha:1];
                m.textAlignment = NSTextAlignmentCenter;
                m.frame = CGRectMake(20, y, w - 40, 16);
                [card addSubview:m];
                y += 22;
            }

            // 懒加载表格：几千条也不卡
            CGFloat tableH = MIN(maxH - y - 68, MAX(80, (CGFloat)items.count * 44.0));
            UITableView *tv = [[UITableView alloc] initWithFrame:CGRectMake(10, y, w - 20, tableH)
                                                           style:UITableViewStylePlain];
            tv.backgroundColor = UIColor.clearColor;
            tv.separatorStyle = UITableViewCellSeparatorStyleNone;
            tv.showsVerticalScrollIndicator = YES;
            tv.indicatorStyle = UIScrollViewIndicatorStyleWhite;

            LLLListSheet *ds2 = [LLLListSheet new];
            ds2.items = items;
            ds2.onPick = cb;
            __block UIView *weakCard = card;
            ds2.onClose = ^{
                UIView *c = weakCard;
                if (c) LLLDismissAnimated(c);
            };
            tv.dataSource = ds2;
            tv.delegate = ds2;
            [card addSubview:tv];

            // 数据源必须被持有，否则会立刻释放
            objc_setAssociatedObject(card, "bbhj.listds", ds2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            y += tableH + 10;

            UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
            cancel.frame = CGRectMake(14, y, w - 28, 44);
            cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
            cancel.layer.cornerRadius = 12;
            [cancel setTitle:@"取消" forState:UIControlStateNormal];
            [cancel setTitleColor:[UIColor colorWithWhite:0.75 alpha:1] forState:UIControlStateNormal];
            cancel.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            [cancel lll_onTap:^{
                UIView *c = card;
                LLLDismissAnimated(c);
            }];
            [card addSubview:cancel];
            y += 54;

            card.frame = CGRectMake(0, 0, w, y);
            LLLPresent(card);
        } @catch (__unused NSException *e) { }
    });
}

void LLLShowCustomCard(CGFloat width, CGFloat maxHeight,
                       void (^build)(UIView *card, void (^close)(void))) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = LLLOverlayWindow();
            UIView *host = win.rootViewController.view;
            CGFloat w = MIN(width, host.bounds.size.width - 40);
            __block UIView *card = LLLNewCard(w);
            __block BOOL closing = NO;
            void (^close)(void) = ^{
                if (closing) return;
                closing = YES;
                LLLDismissAnimated(card);
            };
            if (build) build(card, close);
            if (card.bounds.size.height < 20) card.frame = CGRectMake(0, 0, w, 120);
            if (maxHeight > 0 && card.bounds.size.height > maxHeight) {
                card.frame = CGRectMake(0, 0, w, maxHeight);
            }
            LLLPresent(card);
        } @catch (__unused NSException *e) { }
    });
}


void LLLShowHUD(NSString *text, NSTimeInterval duration) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = LLLOverlayWindow();
            win.hidden = NO;
            UIView *host = win.rootViewController.view;

            UIView *box = [UIView new];
            box.tag = 99013;
            box.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
            box.layer.cornerRadius = 14;
            box.layer.cornerCurve = kCACornerCurveContinuous;

            UILabel *l = [UILabel new];
            l.text = text;
            l.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            l.textColor = UIColor.whiteColor;
            l.numberOfLines = 0;
            CGSize sz = [l sizeThatFits:CGSizeMake(260, 800)];
            l.frame = CGRectMake(18, 14, sz.width, sz.height);
            [box addSubview:l];

            box.frame = CGRectMake(0, 0, sz.width + 36, sz.height + 28);
            box.center = CGPointMake(LLLUIKitHostSize(host).width / 2, LLLUIKitHostSize(host).height / 2);
            box.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                                 | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            box.alpha = 0;
            [host addSubview:box];

            LLLSpring(0.3, 0.9, ^{ box.alpha = 1; });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0.6, duration) * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{ box.alpha = 0; }
                                 completion:^(BOOL f) { [box removeFromSuperview]; }];
            });
        } @catch (__unused NSException *e) { }
    });
}
