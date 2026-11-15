//
//  LLLWebLogin.m
//

#import "LLLWebLogin.h"
#import "LLLCloudMusic.h"
#import "BaseComponents.h"
#import <WebKit/WebKit.h>

static UIWindow *gWin = nil;
static WKWebView *gWeb = nil;
static NSTimer *gPoll = nil;
static void (^gDone)(BOOL, NSString *) = nil;

@interface LLLWebLoginVC : UIViewController
@end

@implementation LLLWebLoginVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];

    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    cfg.websiteDataStore = WKWebsiteDataStore.defaultDataStore;

    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
    wv.translatesAutoresizingMaskIntoConstraints = NO;
    wv.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1];
    [self.view addSubview:wv];
    gWeb = wv;

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
    tip.text = @"在下面的官方页面登录（扫码 / 手机号 / 密码都行），登录成功会自动返回";
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

    [wv loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://music.163.com/login"]]];
}

- (void)onClose {
    [LLLWebLogin dismiss];
}

@end

@implementation LLLWebLogin

+ (BOOL)isShowing { return gWin != nil && !gWin.hidden; }

+ (void)presentWithDone:(void (^)(BOOL, NSString *))done {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gWin) { [gWin makeKeyAndVisible]; return; }
        gDone = [done copy];

        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] &&
                    s.activationState == UISceneActivationStateForegroundActive) { scene = (UIWindowScene *)s; break; }
            }
            gWin = scene ? [[BaseOverlayWindow alloc] initWithWindowScene:scene]
                         : [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        } else {
            gWin = [[BaseOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        }
        gWin.windowLevel = UIWindowLevelAlert + 20;
        gWin.rootViewController = [LLLWebLoginVC new];
        gWin.hidden = NO;

        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            if (!gWin) { [t invalidate]; return; }
            [[WKWebsiteDataStore defaultDataStore].httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
                for (NSHTTPCookie *c in cookies) {
                    if ([c.name isEqualToString:@"MUSIC_U"] && c.value.length > 8 &&
                        [c.domain containsString:@"163.com"]) {
                        [t invalidate];
                        [LLLWebLogin finishWithCookies:cookies];
                        return;
                    }
                }
            }];
        }];
    });
}

+ (void)finishWithCookies:(NSArray<NSHTTPCookie *> *)cookies {
    NSMutableArray<NSHTTPCookie *> *keep = [NSMutableArray array];
    for (NSHTTPCookie *c in cookies) {
        if ([c.domain containsString:@"music.163.com"] || [c.domain containsString:@".163.com"]) {
            [keep addObject:c];
        }
    }
    [self dismiss];
    [[LLLCloudMusic shared] adoptCookies:keep completion:^(BOOL ok, NSString *msg) {
        if (gDone) { gDone(ok, msg); gDone = nil; }
    }];
}

+ (void)dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gPoll invalidate]; gPoll = nil;
        gWin.hidden = YES;
        gWin.rootViewController = nil;
        gWin = nil;
        gWeb = nil;
        if (gDone) { gDone(NO, @"已取消"); gDone = nil; }
    });
}

@end
