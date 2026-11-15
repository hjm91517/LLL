//
//  ui/LLLCloudLogin.m  — 4.0
//

#import "LLLCloudLogin.h"
#import "MainViewController+Features.h"
#import "MainViewController+Music4.h"
#import "MainViewController+MusicUI4.h"
#import "MainViewController+CloudLists4.h"
#import "LLLCloudMusic.h"
#import "LLLCloudVIP.h"
#import "LLLCloudRequest.h"
#import "LLLPlayerCore.h"
#import "LLLMusicController.h"
#import "LLLNowPlaying.h"
#import "LLLMusicIsland.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

@interface MainViewController (LLLCloudPrivate)
- (void)applyVolume;
@end

/* 本文件用的分类内部方法：先声明再用，避免隐式声明警告 */
@interface MainViewController (CloudLoginInternal)
- (NSArray<NSDictionary *> *)lll4_currentCloudQueue:(NSDictionary *)song;
@end

static void (^gCloseLoginCard)(void) = nil;
static UITextField *gPhoneField = nil;
static UITextField *gCodeField = nil;
static UIButton    *gSendBtn = nil;
static UITextView  *gCookieView = nil;
static UILabel     *gLoginHint = nil;
static WKWebView   *gWebLogin = nil;

/* 常驻宿主：浮窗面板创建时登记，灵动岛入口直接用这一个。 */
static __weak MainViewController *gCloudHostRef = nil;
static MainViewController *gCloudHostOwned = nil;

@implementation MainViewController (CloudLogin)

+ (void)registerCloudHost:(MainViewController *)vc {
    if (vc) gCloudHostRef = vc;
}

+ (MainViewController *)cloudHost {
    MainViewController *vc = gCloudHostRef;
    if (vc) return vc;
    if (!gCloudHostOwned) gCloudHostOwned = [[MainViewController alloc] init];
    return gCloudHostOwned;
}

#pragma mark - 入口

- (void)dismissCloudLoginCard {
    /* 关卡片 = 放弃这次登录：不停轮询的话，几分钟后还会突然弹"登录成功" */
    [[LLLCloudMusic shared] cancelLogin];
    if (gCloseLoginCard) { gCloseLoginCard(); gCloseLoginCard = nil; }
}

- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs {
    [[LLLPlayerCore shared] setCloudQueueSilently:songs];
}

- (void)openCloudMusic {
    LLLCloudMusic *cm = [LLLCloudMusic shared];

    if (cm.loggedIn) {
        NSString *vip = (cm.vipType > 0) ? @"会员" : @"普通";
        NSString *sub = [NSString stringWithFormat:@"%@ · %@",
                         cm.nickname.length ? cm.nickname : @"已登录", vip];
        __weak typeof(self) w = self;
        LLLShowSheet(@"网易云音乐", sub,
                     @[ @"我喜欢的音乐", @"每日推荐", @"搜索音乐", @"重新登录", @"退出登录" ], YES,
                     ^(NSInteger idx) {
            __strong typeof(w) s = w;
            if (!s) return;
            if (idx == 0) [s showLikedSongs];
            else if (idx == 1) [s showDailyRecommend];
            else if (idx == 2) [s searchCloudMusic];
            else if (idx == 3) { [s presentLoginChooser]; }
            else {
                [[LLLCloudMusic shared] logout];
                [LLLMusicIsland refreshCloudButton];
                ShowToast(@"已退出登录", 1.5, YES, NO);
            }
        });
        return;
    }

    [self presentLoginChooser];
}

- (void)presentLoginChooser {
    LLLShowSheet(@"网易云登录", @"网页登录最稳（站点自己过风控）；不想登录可以直接用免登录听",
                 @[ @"网页登录（推荐）", @"扫码登录", @"手机验证码", @"粘贴 Cookie", @"免登录听" ], NO,
                 ^(NSInteger idx) {
        if (idx == 0) [self cloudLoginWeb];
        else if (idx == 1) [self cloudLoginQR];
        else if (idx == 2) [self cloudLoginPhone];
        else if (idx == 3) [self cloudLoginCookie];
        else [self lll4_openGuestMusic];
    });
}

- (void)loginHint:(NSString *)text {
    if (gLoginHint) gLoginHint.text = text;
}

- (void)loginDone:(BOOL)ok msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissCloudLoginCard];
        gPhoneField = nil; gCodeField = nil; gSendBtn = nil; gCookieView = nil; gLoginHint = nil;
        NSString *shown = msg.length ? msg : (ok ? @"登录成功" : @"登录失败");
        ShowToast(shown, 2.6, YES, !ok);
        PlayHaptic(ok);
        [LLLMusicIsland refreshCloudButton];
        [self lll4_refreshLoginButton];
        if (ok) {
            [[LLLMusicController shared] reloadCloudLiked];
            [self showLikedSongs];
        }
    });
}

#pragma mark - 网页登录

- (void)cloudLoginWeb {
    __weak typeof(self) w = self;
    [LLLWebLogin presentWithDone:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (s) [s loginDone:ok msg:msg];
        });
    }];
}

- (void)doHarvestWebCookies {
    WKWebView *wv = gWebLogin;
    if (!wv) { [self loginDone:NO msg:@"网页没有加载"]; return; }

    __weak typeof(self) w = self;
    [wv.configuration.websiteDataStore.httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            NSMutableArray *keep = [NSMutableArray array];
            for (NSHTTPCookie *c in cookies) {
                if ([c.domain containsString:@"163.com"] && c.value.length) [keep addObject:c];
            }
            if (!keep.count) { [s loginHint:@"还没登上：网页里先完成登录"]; PlayHaptic(NO); return; }
            [s loginHint:@"校验中…"];
            [[LLLCloudMusic shared] adoptCookies:keep completion:^(BOOL ok, NSString *msg) {
                __strong typeof(w) s2 = w;
                if (s2) [s2 loginDone:ok msg:msg];
            }];
        });
    }];
}

#pragma mark - 扫码

- (void)cloudLoginQR {
    __block UIImageView *qrView = nil;
    __block UILabel *hint = nil;

    LLLShowCustomCard(320, 520, ^(UIView *card, void (^close)(void)) {
        gCloseLoginCard = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 392);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, w - 32, 24)];
        t.text = @"扫码登录";
        t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        qrView = [[UIImageView alloc] initWithFrame:CGRectMake((w - 200) / 2, 56, 200, 200)];
        qrView.backgroundColor = UIColor.whiteColor;
        qrView.layer.cornerRadius = 10;
        qrView.clipsToBounds = YES;
        qrView.contentMode = UIViewContentModeScaleAspectFit;
        [card addSubview:qrView];

        hint = [[UILabel alloc] initWithFrame:CGRectMake(16, 268, w - 32, 18)];
        hint.text = @"正在获取二维码…";
        hint.font = [UIFont systemFontOfSize:12];
        hint.textColor = [UIColor colorWithWhite:0.7 alpha:1];
        hint.textAlignment = NSTextAlignmentCenter;
        [card addSubview:hint];

        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        cancel.frame = CGRectMake(14, 300, w - 28, 44);
        cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        cancel.layer.cornerRadius = 12;
        [cancel setTitle:@"取消" forState:UIControlStateNormal];
        [cancel setTitleColor:[UIColor colorWithWhite:0.78 alpha:1] forState:UIControlStateNormal];
        cancel.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [cancel addTarget:self action:@selector(dismissCloudLoginCard) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];
    });

    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] startLoginWithQR:^(UIImage *qr, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (qr) qrView.image = qr;
            if (status.length) hint.text = status;
        });
    } completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (s) [s loginDone:ok msg:msg];
        });
    }];
}

#pragma mark - 手机号

- (void)cloudLoginPhone {
    LLLShowCustomCard(320, 460, ^(UIView *card, void (^close)(void)) {
        gCloseLoginCard = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 348);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, w - 32, 24)];
        t.text = @"手机验证码登录";
        t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        gPhoneField = [[UITextField alloc] initWithFrame:CGRectMake(18, 56, w - 36, 42)];
        gPhoneField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        gPhoneField.layer.cornerRadius = 10;
        gPhoneField.textColor = UIColor.whiteColor;
        gPhoneField.tintColor = LLLAccentColor();
        gPhoneField.keyboardType = UIKeyboardTypeNumberPad;
        gPhoneField.placeholder = @"手机号";
        gPhoneField.font = [UIFont systemFontOfSize:15];
        gPhoneField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 42)];
        gPhoneField.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:gPhoneField];

        gCodeField = [[UITextField alloc] initWithFrame:CGRectMake(18, 104, w - 36 - 108, 42)];
        gCodeField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        gCodeField.layer.cornerRadius = 10;
        gCodeField.textColor = UIColor.whiteColor;
        gCodeField.tintColor = LLLAccentColor();
        gCodeField.keyboardType = UIKeyboardTypeNumberPad;
        gCodeField.placeholder = @"短信验证码";
        gCodeField.font = [UIFont systemFontOfSize:15];
        gCodeField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 42)];
        gCodeField.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:gCodeField];

        gSendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        gSendBtn.frame = CGRectMake(w - 18 - 100, 104, 100, 42);
        gSendBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
        gSendBtn.layer.cornerRadius = 10;
        [gSendBtn setTitle:@"发送验证码" forState:UIControlStateNormal];
        [gSendBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        gSendBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [gSendBtn addTarget:self action:@selector(doSendCode) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:gSendBtn];

        UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
        go.frame = CGRectMake(18, 158, w - 36, 44);
        go.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
        go.layer.cornerRadius = 12;
        [go setTitle:@"登录" forState:UIControlStateNormal];
        [go setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        go.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [go addTarget:self action:@selector(doPhoneLogin) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:go];

        gLoginHint = [[UILabel alloc] initWithFrame:CGRectMake(18, 208, w - 36, 32)];
        gLoginHint.text = @"网易已关闭密码登录，只能收短信验证码";
        gLoginHint.numberOfLines = 2;
        gLoginHint.font = [UIFont systemFontOfSize:11];
        gLoginHint.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        gLoginHint.textAlignment = NSTextAlignmentCenter;
        [card addSubview:gLoginHint];

        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        cancel.frame = CGRectMake(18, 252, w - 36, 40);
        cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        cancel.layer.cornerRadius = 12;
        [cancel setTitle:@"取消" forState:UIControlStateNormal];
        [cancel setTitleColor:[UIColor colorWithWhite:0.78 alpha:1] forState:UIControlStateNormal];
        cancel.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [cancel addTarget:self action:@selector(dismissCloudLoginCard) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];
    });
}

- (void)doSendCode {
    NSString *phone = gPhoneField.text;
    if (phone.length < 6) { [self loginHint:@"先把手机号填完"]; PlayHaptic(NO); return; }
    gSendBtn.enabled = NO;
    [self loginHint:@"发送中…"];
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] requestSMSCode:phone done:^(BOOL ok, NSString *msg) {
        __strong typeof(w) s = w;
        if (!s) return;
        [s loginHint:msg];
        PlayHaptic(ok);
        if (!ok) { gSendBtn.enabled = YES; return; }
        __block NSInteger left = 60;
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            left--;
            if (left <= 0) {
                [t invalidate];
                gSendBtn.enabled = YES;
                [gSendBtn setTitle:@"发送验证码" forState:UIControlStateNormal];
            } else {
                [gSendBtn setTitle:[NSString stringWithFormat:@"%lds", (long)left] forState:UIControlStateNormal];
            }
        }];
    }];
}

- (void)doPhoneLogin {
    if (!gPhoneField || !gCodeField) return;
    NSString *phone = gPhoneField.text;
    NSString *code = gCodeField.text;
    if (phone.length < 6 || code.length < 4) {
        [self loginHint:@"手机号或验证码没填完"];
        PlayHaptic(NO);
        return;
    }
    [self loginHint:@"登录中…"];
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loginWithPhone:phone captcha:code completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (s) [s loginDone:ok msg:msg];
        });
    }];
}

#pragma mark - Cookie

- (void)cloudLoginCookie {
    LLLShowCustomCard(320, 420, ^(UIView *card, void (^close)(void)) {
        gCloseLoginCard = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 316);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, w - 32, 24)];
        t.text = @"粘贴 Cookie";
        t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        gCookieView = [[UITextView alloc] initWithFrame:CGRectMake(18, 54, w - 36, 110)];
        gCookieView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        gCookieView.layer.cornerRadius = 10;
        gCookieView.textColor = UIColor.whiteColor;
        gCookieView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        gCookieView.text = @"MUSIC_U=...; __csrf=...";
        [card addSubview:gCookieView];

        UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
        go.frame = CGRectMake(18, 176, w - 36, 44);
        go.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
        go.layer.cornerRadius = 12;
        [go setTitle:@"登录" forState:UIControlStateNormal];
        [go setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        go.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [go addTarget:self action:@selector(doCookieLogin) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:go];

        gLoginHint = [[UILabel alloc] initWithFrame:CGRectMake(18, 226, w - 36, 18)];
        gLoginHint.text = @"整段复制，包含 MUSIC_U";
        gLoginHint.font = [UIFont systemFontOfSize:11];
        gLoginHint.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        gLoginHint.textAlignment = NSTextAlignmentCenter;
        [card addSubview:gLoginHint];

        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        cancel.frame = CGRectMake(18, 252, w - 36, 40);
        cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        cancel.layer.cornerRadius = 12;
        [cancel setTitle:@"取消" forState:UIControlStateNormal];
        [cancel setTitleColor:[UIColor colorWithWhite:0.78 alpha:1] forState:UIControlStateNormal];
        cancel.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [cancel addTarget:self action:@selector(dismissCloudLoginCard) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];
    });
}

- (void)doCookieLogin {
    NSString *raw = gCookieView.text;
    if ([raw rangeOfString:@"MUSIC_U"].location == NSNotFound) {
        [self loginHint:@"里面得有 MUSIC_U"];
        PlayHaptic(NO);
        return;
    }
    [self loginHint:@"校验中…"];
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loginWithCookie:raw completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (s) [s loginDone:ok msg:msg];
        });
    }];
}

#pragma mark - 播放（全部转内核）

- (void)playCloudSong:(NSDictionary *)song {
    if (![song isKindOfClass:NSDictionary.class]) return;
    NSArray<NSDictionary *> *queue = [self lll4_currentCloudQueue:song];
    NSInteger idx = 0;
    for (NSUInteger i = 0; i < queue.count; i++) {
        if ([queue[i][@"id"] isEqual:song[@"id"]]) { idx = (NSInteger)i; break; }
    }
    [[LLLPlayerCore shared] setCloudQueue:queue startAt:idx];
    [LLLMusicIsland refresh];
}

- (NSArray<NSDictionary *> *)lll4_currentCloudQueue:(NSDictionary *)song {
    LLLMusicController *mc = [LLLMusicController shared];
    NSInteger n = [mc rowCount];
    if (n > 0) {
        NSMutableArray *all = [NSMutableArray array];
        for (NSInteger i = 0; i < n; i++) {
            NSDictionary *info = [mc rowInfoAt:i];
            if (info[@"id"]) [all addObject:info];
        }
        if (all.count) return all;
    }
    return @[ song ];
}

- (void)cloudStep:(NSInteger)delta {
    if (delta > 0) [[LLLPlayerCore shared] next];
    else           [[LLLPlayerCore shared] previous];
    [LLLMusicIsland refresh];
}

@end
