//
//  LLLCloudLogin.m
//

#import "LLLCloudLogin.h"
#import "MainViewController+Features.h"
#import "LLLCloudMusic.h"
#import "LLLNowPlaying.h"
#import "LLLMusicIsland.h"
#import "LLLUiKit.h"
#import "BaseComponents.h"
#import <AVFoundation/AVFoundation.h>

@interface MainViewController (LLLCloudPrivate)
- (void)applyVolume;
- (void)startProgressTimer;
@end

static void (^gCloseLoginCard)(void) = nil;
static NSArray<NSDictionary *> *gCloudSongs = nil;
static NSInteger gCloudIndex = -1;

static UITextField *gPhoneField = nil;
static UITextField *gPwdField = nil;
static UITextView  *gCookieView = nil;
static UILabel     *gLoginHint = nil;

@implementation MainViewController (CloudLogin)

#pragma mark - 入口

- (void)dismissCloudLoginCard {
    if (gCloseLoginCard) { gCloseLoginCard(); gCloseLoginCard = nil; }
}

- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs {
    gCloudSongs = songs;
    gCloudIndex = -1;
}

- (void)openCloudMusic {
    LLLCloudMusic *cm = [LLLCloudMusic shared];
    if (cm.loggedIn) {
        LLLShowSheet(@"网易云音乐", cm.nickname.length ? cm.nickname : @"已登录",
                     @[ @"我喜欢的音乐", @"搜索音乐", @"切换账号", @"退出登录" ], YES,
                     ^(NSInteger idx) {
            if (idx == 0) [self showLikedSongs];
            else if (idx == 1) [self searchCloudMusic];
            else if (idx == 2) {
                [[LLLCloudMusic shared] logout];
                [self openCloudMusic];
            } else {
                [[LLLCloudMusic shared] logout];
                ShowToast(@"已退出登录", 1.5, YES, NO);
            }
        });
        return;
    }

    LLLShowSheet(@"网易云登录", @"三种方式任选，登录后自动拉「我喜欢的音乐」",
                 @[ @"扫码登录", @"手机号 + 密码", @"粘贴 Cookie" ], NO, ^(NSInteger idx) {
        if (idx == 0) [self cloudLoginQR];
        else if (idx == 1) [self cloudLoginPhone];
        else if (idx == 2) [self cloudLoginCookie];
    });
}

- (void)loginHint:(NSString *)text {
    if (gLoginHint) gLoginHint.text = text;
}

- (void)loginDone:(BOOL)ok msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissCloudLoginCard];
        gPhoneField = nil; gPwdField = nil; gCookieView = nil; gLoginHint = nil;
        ShowToast(msg.length ? msg : (ok ? @"登录成功" : @"登录失败"), 2.2, YES, !ok);
        PlayHaptic(ok);
        if (ok) [self showLikedSongs];
    });
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

    [[LLLCloudMusic shared] startLoginWithQR:^(UIImage *qr, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (qr) qrView.image = qr;
            if (status.length) hint.text = status;
        });
    } completion:^(BOOL ok, NSString *msg) {
        [self loginDone:ok msg:msg];
    }];
}

#pragma mark - 手机号

- (void)cloudLoginPhone {
    LLLShowCustomCard(320, 420, ^(UIView *card, void (^close)(void)) {
        gCloseLoginCard = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 300);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, w - 32, 24)];
        t.text = @"手机号登录";
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

        gPwdField = [[UITextField alloc] initWithFrame:CGRectMake(18, 104, w - 36, 42)];
        gPwdField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        gPwdField.layer.cornerRadius = 10;
        gPwdField.textColor = UIColor.whiteColor;
        gPwdField.tintColor = LLLAccentColor();
        gPwdField.secureTextEntry = YES;
        gPwdField.placeholder = @"密码";
        gPwdField.font = [UIFont systemFontOfSize:15];
        gPwdField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 42)];
        gPwdField.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:gPwdField];

        UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
        go.frame = CGRectMake(18, 158, w - 36, 44);
        go.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
        go.layer.cornerRadius = 12;
        [go setTitle:@"登录" forState:UIControlStateNormal];
        [go setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        go.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [go addTarget:self action:@selector(doPhoneLogin) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:go];

        gLoginHint = [[UILabel alloc] initWithFrame:CGRectMake(18, 208, w - 36, 18)];
        gLoginHint.text = @"密码只用于网易云接口，不落盘";
        gLoginHint.font = [UIFont systemFontOfSize:11];
        gLoginHint.textColor = [UIColor colorWithWhite:0.5 alpha:1];
        gLoginHint.textAlignment = NSTextAlignmentCenter;
        [card addSubview:gLoginHint];

        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        cancel.frame = CGRectMake(18, 236, w - 36, 40);
        cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        cancel.layer.cornerRadius = 12;
        [cancel setTitle:@"取消" forState:UIControlStateNormal];
        [cancel setTitleColor:[UIColor colorWithWhite:0.78 alpha:1] forState:UIControlStateNormal];
        cancel.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [cancel addTarget:self action:@selector(dismissCloudLoginCard) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];
    });
}

- (void)doPhoneLogin {
    if (!gPhoneField || !gPwdField) return;
    NSString *phone = gPhoneField.text;
    NSString *pwd = gPwdField.text;
    if (phone.length < 6 || pwd.length == 0) {
        [self loginHint:@"手机号或密码没填完"];
        PlayHaptic(NO);
        return;
    }
    [self loginHint:@"登录中…"];
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loginWithPhone:phone password:pwd completion:^(BOOL ok, NSString *msg) {
        __strong typeof(w) s = w;
        if (s) [s loginDone:ok msg:msg];
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
        gLoginHint.text = @"手机端抓包复制整段 Cookie";
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
        __strong typeof(w) s = w;
        if (s) [s loginDone:ok msg:msg];
    }];
}

#pragma mark - 云端播放

- (void)installNowPlayingBridge {
    __weak typeof(self) w = self;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [LLLNowPlaying setCommandHandler:^(LLLNPCommand cmd, double value) {
            __strong typeof(w) s = w;
            if (!s) return;

            if (cmd == LLLNPCommandTogglePlay) {
                if (s.cloudPlayer) {
                    BOOL playing = (s.cloudPlayer.rate > 0.01);
                    if (playing) [s.cloudPlayer pause]; else [s.cloudPlayer play];
                    [[LLLNowPlaying shared] setPlaying:!playing];
                } else {
                    [s togglePlayPause];
                }
            } else if (cmd == LLLNPCommandNext) {
                [s cloudStep:1];
            } else if (cmd == LLLNPCommandPrevious) {
                [s cloudStep:-1];
            } else if (cmd == LLLNPCommandSeek) {
                if (s.cloudPlayer) {
                    [s.cloudPlayer seekToTime:CMTimeMakeWithSeconds(value, 600)];
                    [[LLLNowPlaying shared] updateElapsed:value duration:[LLLNowPlaying shared].duration];
                } else if (s.audioPlayer) {
                    s.audioPlayer.currentTime = value;
                    [[LLLNowPlaying shared] updateElapsed:value duration:[LLLNowPlaying shared].duration];
                }
            } else if (cmd == LLLNPCommandVolume) {
                /* v2.2 灵动岛独立音量：存偏好并应用到所有音乐播放器（不影响系统音量） */
                double v = value;
                if (v < 0) v = 0; if (v > 1) v = 1;
                [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"LLL.volume"];
                [s applyVolume];
            }
        }];
    });
}

- (void)cloudStep:(NSInteger)delta {
    if (gCloudSongs.count == 0) return;
    NSInteger n = (NSInteger)gCloudSongs.count;
    NSInteger base = (gCloudIndex < 0) ? 0 : gCloudIndex;
    gCloudIndex = (base + delta + n) % n;
    [self playCloudSong:gCloudSongs[(NSUInteger)gCloudIndex]];
}

- (void)playCloudSong:(NSDictionary *)song {
    if (![song isKindOfClass:NSDictionary.class]) return;
    [self installNowPlayingBridge];

    NSNumber *sid = song[@"id"];
    gCloudIndex = -1;
    for (NSUInteger i = 0; i < gCloudSongs.count; i++) {
        if ([gCloudSongs[i][@"id"] isEqual:sid]) { gCloudIndex = (NSInteger)i; break; }
    }

    [[LLLNowPlaying shared] beginTrack:(song[@"name"] ?: @"网易云")
                                artist:(song[@"artist"] ?: @"网易云音乐")
                               artwork:nil
                              duration:[song[@"dur"] doubleValue]
                               elapsed:0];

    NSString *pic = song[@"pic"];
    if (pic.length) {
        [[LLLCloudMusic shared] loadArtwork:pic done:^(UIImage *img) {
            if (img) [[LLLNowPlaying shared] updateArtwork:img];
        }];
    }

    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] resolvePlayURL:sid done:^(NSURL *url, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!url) {
                [[LLLNowPlaying shared] setPlaying:NO];
                ShowToast(err.length ? err : @"拿不到播放地址", 2.2, YES, YES);
                return;
            }
            [s.cloudPlayer pause];
            s.cloudPlayer = [AVPlayer playerWithURL:url];
            [s applyVolume];
            [s.cloudPlayer play];
            [LLLMusicIsland updateTitle:(song[@"name"] ?: @"网易云") playing:YES];
            if (s.playerTitle)  s.playerTitle.text  = song[@"name"] ?: @"网易云";
            if (s.playerArtist) s.playerArtist.text = song[@"artist"] ?: @"网易云音乐";
            [s startProgressTimer];
            ShowToast([NSString stringWithFormat:@"播放: %@", song[@"name"]], 2, YES, NO);
        });
    }];
}

@end
