//
//  ui/LLLWebLogin.m  — 4.0
//

#import "LLLWebLogin.h"
#import "LLLCloudMusic.h"
#import "BaseComponents.h"
#import <WebKit/WebKit.h>

static UIWindow *gWin = nil;
static NSTimer *gPoll = nil;
static void (^gDone)(BOOL, NSString *) = nil;
static BOOL gFinished = NO;

/* 内部方法先声明再用，避免隐式声明 */
@interface LLLWebLogin (Internal)
+ (void)finishWithCookies:(NSArray<NSHTTPCookie *> *)cookies;
+ (void)hideWindow;
@end

#pragma mark - VC

@interface LLLWebLoginVC : UIViewController
@end

@implementation LLLWebLoginVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) {
        cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }
    cfg.websiteDataStore = WKWebsiteDataStore.defaultDataStore;

    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
    wv.translatesAutoresizingMaskIntoConstraints = NO;
    wv.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];
    wv.opaque = NO;
    if (@available(iOS 11.0, *)) {
        wv.customUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) "
                             @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 "
                             @"Mobile/15E148 Safari/604.1";
    }
    [self.view addSubview:wv];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    close.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    close.layer.cornerRadius = 10;
    [close addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UILabel *tip = [UILabel new];
    tip.translatesAutoresizingMaskIntoConstraints = NO;
    tip.text = @"在官方页面登录（扫码 / 手机号都行），登录成功会自动返回";
    tip.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    tip.font = [UIFont systemFontOfSize:12];
    tip.numberOfLines = 2;
    [self.view addSubview:tip];

    [NSLayoutConstraint activateConstraints:@[
        [tip.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [tip.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [tip.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-10],
        [tip.heightAnchor constraintGreaterThanOrEqualToConstant:34],

        [close.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [close.centerYAnchor constraintEqualToAnchor:tip.centerYAnchor],
        [close.widthAnchor constraintEqualToConstant:64],
        [close.heightAnchor constraintEqualToConstant:34],

        [wv.topAnchor constraintEqualToAnchor:tip.bottomAnchor constant:8],
        [wv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [wv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [wv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [wv loadRequest:[NSURLRequest requestWithURL:
                     [NSURL URLWithString:@"https://music.163.com/login"]]];
}

- (void)onClose {
    [LLLWebLogin dismiss];
}

@end

#pragma mark -

@implementation LLLWebLogin

+ (BOOL)isShowing {
    return gWin != nil && !gWin.hidden && !gFinished;
}

+ (void)presentWithDone:(void (^)(BOOL, NSString *))done {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gWin) { [gWin makeKeyAndVisible]; return; }

        gDone = [done copy];
        gFinished = NO;

        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] &&
                    s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            gWin = scene ? [[BaseOverlayWindow alloc] initWithWindowScene:scene]
                         : [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        } else {
            gWin = [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
        gWin.windowLevel = UIWindowLevelAlert + 20;
        gWin.rootViewController = [LLLWebLoginVC new];
        gWin.hidden = NO;

        [gPoll invalidate];
        gPoll = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            if (!gWin || gFinished) { [t invalidate]; return; }

            [[WKWebsiteDataStore defaultDataStore].httpCookieStore
             getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
                NSMutableArray<NSHTTPCookie *> *keep = [NSMutableArray array];
                BOOL hasMusicU = NO;
                for (NSHTTPCookie *c in cookies) {
                    if (![c.domain containsString:@"163.com"]) continue;
                    [keep addObject:c];
                    if ([c.name isEqualToString:@"MUSIC_U"] && c.value.length > 8) hasMusicU = YES;
                }
                if (hasMusicU && keep.count) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [LLLWebLogin finishWithCookies:keep];
                    });
                }
            }];
        }];
        [[NSRunLoop mainRunLoop] addTimer:gPoll forMode:NSRunLoopCommonModes];
    });
}

+ (void)finishWithCookies:(NSArray<NSHTTPCookie *> *)cookies {
    if (gFinished) return;
    gFinished = YES;

    [gPoll invalidate];
    gPoll = nil;

    /* 先把回调取出来再关窗口，否则 dismiss 会误发一次"已取消" */
    void (^cb)(BOOL, NSString *) = gDone;
    gDone = nil;

    [[LLLCloudMusic shared] adoptCookies:cookies completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [LLLWebLogin hideWindow];
            if (cb) cb(ok, msg);
        });
    }];
}

+ (void)hideWindow {
    UIWindow *win = gWin;
    gWin = nil;
    win.hidden = YES;
    win.rootViewController = nil;
}

+ (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gPoll invalidate];
        gPoll = nil;

        [LLLWebLogin hideWindow];

        void (^cb)(BOOL, NSString *) = gDone;
        gDone = nil;
        gFinished = YES;
        if (cb) cb(NO, @"已取消");
    });
}

@end
