//
//  LLLCloudMusic.m  — 4.0
//
//  接口分两类：
//    1) 明文 api/*：扫码 unikey、搜索、歌单 —— 直接 GET，走 LLLCloudRequest 节流
//    2) 登录：验证码走明文表单；密码登录已被网易关闭
//  取流全部交给 LLLCloudVIP（eapi 多档回退），这里只做转发。
//

#import "LLLCloudMusic.h"
#import "LLLCloudRequest.h"
#import "LLLCloudVIP.h"
#import "BaseComponents.h"
#import <CoreImage/CoreImage.h>

static NSInteger gQRType = 3;

static NSString * const kBase = @"https://music.163.com";

@interface LLLCloudMusic ()
@property (nonatomic, assign) BOOL loggedIn;
@property (nonatomic, copy) NSString *nickname;
@property (nonatomic, assign) long long uid;
@property (nonatomic, assign) NSInteger vipType;

@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, copy) NSString *uniKey;
@property (nonatomic, assign) NSInteger pollCount;
@property (nonatomic, copy) void (^progressBlock)(UIImage *, NSString *);
@property (nonatomic, copy) void (^doneBlock)(BOOL, NSString *);

@property (nonatomic, assign) CFAbsoluteTime lastAccountRefresh;

- (BOOL)hasCookie;
- (void)pollOnce;
- (void)requestQRKey:(NSInteger)type done:(void (^)(NSString *key, NSInteger used))done;
- (void)fetchAccountThen:(void (^)(BOOL ok, NSString *msg))done;
@end

@implementation LLLCloudMusic

+ (instancetype)shared {
    static LLLCloudMusic *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [LLLCloudMusic new]; });
    return m;
}

- (instancetype)init {
    if (self = [super init]) {
        [NSHTTPCookieStorage sharedHTTPCookieStorage].cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        _loggedIn = [self hasCookie];
        _lastAccountRefresh = 0;
    }
    return self;
}

#pragma mark - Cookie

- (BOOL)hasCookie {
    for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
        if ([c.domain containsString:@"music.163.com"] &&
            ([c.name isEqualToString:@"MUSIC_U"] || [c.name isEqualToString:@"MUSIC_A"])) {
            return c.value.length > 0;
        }
    }
    return NO;
}

#pragma mark - 二维码

static UIImage *LLLQRImage(NSString *text, CGFloat side) {
    CIFilter *f = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [f setDefaults];
    [f setValue:[text dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [f setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *ci = f.outputImage;
    if (!ci) return nil;
    CGFloat scale = side / ci.extent.size.width;
    CIImage *scaled = [ci imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    static CIContext *ctx;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ctx = [CIContext contextWithOptions:nil]; });
    CGImageRef cg = [ctx createCGImage:scaled fromRect:scaled.extent];
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return img;
}

- (void)cancelLogin {
    [_pollTimer invalidate];
    _pollTimer = nil;
    _pollCount = 0;
    _uniKey = nil;
}

- (void)requestQRKey:(NSInteger)type done:(void (^)(NSString *, NSInteger))done{
    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] GET:@"/api/login/qrcode/unikey"
                          params:@{ @"type" : [NSString stringWithFormat:@"%ld", (long)type] }
                            kind:LLLReqKindWrite
                         retries:1
                            done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSString *key = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            key = json[@"unikey"];
            if (![key isKindOfClass:NSString.class] || !key.length) {
                key = [json[@"key"] isKindOfClass:NSString.class] ? json[@"key"] : nil;
            }
        }
        /* type=3 拿不到就退成 type=1（网页码） */
        if ((!key || !key.length) && type == 3) {
            [s requestQRKey:1 done:done];
            return;
        }
        if (done) done(([key isKindOfClass:NSString.class] ? key : nil), type);
    }];
}

- (void)startLoginWithQR:(void (^)(UIImage *, NSString *))progress
              completion:(void (^)(BOOL, NSString *))done {
    [self cancelLogin];
    _progressBlock = [progress copy];
    _doneBlock = [done copy];

    __weak typeof(self) w = self;
    [self requestQRKey:3 done:^(NSString *key, NSInteger used) {
        __strong typeof(w) s = w;
        if (!s) return;

        if (!key.length) {
            if (s.doneBlock) s.doneBlock(NO, @"拿不到 unikey，检查网络或接口变化");
            return;
        }

        gQRType = used;
        s.uniKey = key;
        s.pollCount = 0;

        NSString *content = [NSString stringWithFormat:@"%@/login?codekey=%@", kBase, key];
        UIImage *qr = LLLQRImage(content, 220);
        if (s.progressBlock) {
            s.progressBlock(qr, (used == 3) ? @"网易云 App 扫一扫（登录电脑版）"
                                            : @"网易云 App 扫一扫（网页版）");
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s2 = w;
            if (!s2) return;
            s2.pollTimer = [NSTimer timerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
                __strong typeof(w) s3 = w;
                if (!s3) { [t invalidate]; return; }
                [s3 pollOnce];
            }];
            [[NSRunLoop mainRunLoop] addTimer:s2.pollTimer forMode:NSRunLoopCommonModes];
        });
    }];
}

- (void)pollOnce {
    if (!_uniKey.length) { [self cancelLogin]; return; }

    _pollCount++;
    if (_pollCount > 120) {
        [self cancelLogin];
        if (_doneBlock) _doneBlock(NO, @"二维码超时，重新来一次");
        return;
    }

    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] GET:@"/api/login/qrcode/client/login"
                          params:@{ @"key" : _uniKey,
                                    @"type" : [NSString stringWithFormat:@"%ld", (long)gQRType] }
                            kind:LLLReqKindRead
                         retries:0
                            done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSInteger code = 800;
        NSString *msg = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            code = [json[@"code"] integerValue];
            id m = json[@"message"];
            msg = [m isKindOfClass:NSString.class] ? m : nil;
        } else if (err) {
            /* 网络抖动不当作"过期"，继续等下一次轮询 */
            if (s.progressBlock) s.progressBlock(nil, @"网络不稳，重试中…");
            return;
        }

        /* 800 二维码不存在/过期，801 等待扫码，802 已扫码待确认，803 授权成功 */
        if (code == 800) {
            [s cancelLogin];
            if (s.progressBlock) s.progressBlock(nil, @"二维码已过期，重开一次");
            if (s.doneBlock) s.doneBlock(NO, @"二维码已过期");
        } else if (code == 801) {
            if (s.progressBlock) s.progressBlock(nil, @"等待扫码…");
        } else if (code == 802) {
            if (s.progressBlock) s.progressBlock(nil, @"已扫码，请在手机上点确认");
        } else if (code == 803) {
            [s cancelLogin];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [s fetchAccountThen:^(BOOL ok, NSString *m) {
                    s.loggedIn = ok && [s hasCookie];
                    if (s.doneBlock) {
                        s.doneBlock(s.loggedIn,
                                    s.loggedIn
                                    ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                                    : (m ?: @"登录失败"));
                    }
                }];
            });
        } else if ([LLLCloudRequest isRiskCode:code]) {
            [s cancelLogin];
            if (s.progressBlock) s.progressBlock(nil, @"被风控拦了，换网页登录");
            if (s.doneBlock) s.doneBlock(NO, [LLLCloudRequest friendlyMessageForCode:code message:msg]);
        } else {
            if (s.progressBlock) s.progressBlock(nil, msg.length ? msg : @"等待中…");
        }
    }];
}

#pragma mark - 短信 / Cookie

- (void)requestSMSCode:(NSString *)phone done:(void (^)(BOOL, NSString *))done {
    NSString *p = [phone stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (p.length < 6) { if (done) done(NO, @"手机号没填完"); return; }

    [[LLLCloudRequest shared] GET:@"/api/sms/captcha/sent"
                          params:@{ @"cellphone" : p, @"ctcode" : @"86" }
                            kind:LLLReqKindWrite
                         retries:1
                            done:^(id json, NSInteger sc, NSError *err) {
        NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
        id m = [json isKindOfClass:NSDictionary.class] ? (json[@"message"] ?: json[@"msg"]) : nil;
        NSString *msg = [m isKindOfClass:NSString.class] ? m : nil;
        if (err && code != 200) msg = @"网络错误";
        BOOL ok = (code == 200);
        if (done) done(ok, ok ? @"验证码已发送"
                              : [LLLCloudRequest friendlyMessageForCode:code message:msg]);
    }];
}

- (void)loginWithPhone:(NSString *)phone
               captcha:(NSString *)captcha
            completion:(void (^)(BOOL, NSString *))done {
    NSString *p = [phone stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *c = [captcha stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (p.length < 6 || c.length < 4) {
        if (done) done(NO, @"手机号或验证码没填完");
        return;
    }

    NSString *body = [NSString stringWithFormat:
                      @"phone=%@&countrycode=86&captcha=%@&rememberLogin=true",
                      [self formEncode:p], [self formEncode:c]];
    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] POSTForm:@"/api/login/cellphone"
                                  body:body
                                  kind:LLLReqKindWrite
                               retries:1
                                  done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
        id m = [json isKindOfClass:NSDictionary.class] ? (json[@"message"] ?: json[@"msg"]) : nil;
        NSString *msg = [m isKindOfClass:NSString.class] ? m : nil;
        lllLog(@"网易云 验证码登录 code=%ld msg=%@", (long)code, msg ?: @"");
        if (code != 200) {
            if (done) done(NO, [LLLCloudRequest friendlyMessageForCode:code message:msg]);
            return;
        }
        [s fetchAccountThen:^(BOOL ok, NSString *mm) {
            s.loggedIn = ok && [s hasCookie];
            if (done) done(s.loggedIn,
                           s.loggedIn
                           ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                           : (mm ?: @"登录失败"));
        }];
    }];
}

- (NSString *)formEncode:(NSString *)s {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *m = [NSMutableCharacterSet alphanumericCharacterSet];
        [m addCharactersInString:@"-._~"];
        allowed = [m copy];
    });
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

- (void)loginWithCookie:(NSString *)rawCookie completion:(void (^)(BOOL, NSString *))done {
    NSString *raw = [rawCookie stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!raw.length) { if (done) done(NO, @"Cookie 是空的"); return; }
    [[LLLCloudRequest shared] ingestCookieString:raw];

    if (![self hasCookie]) { if (done) done(NO, @"没解析出 MUSIC_U"); return; }

    __weak typeof(self) w = self;
    [self fetchAccountThen:^(BOOL ok, NSString *m) {
        __strong typeof(w) s = w;
        if (!s) return;
        s.loggedIn = ok && [s hasCookie];
        if (done) done(s.loggedIn,
                       s.loggedIn
                       ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                       : (m ?: @"Cookie 已失效，重新抓一个"));
    }];
}

- (void)adoptCookies:(NSArray<NSHTTPCookie *> *)cookies
          completion:(void (^)(BOOL, NSString *))done {
    if (!cookies.count) { if (done) done(NO, @"网页里没拿到登录 Cookie"); return; }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSHTTPCookie *c in cookies) {
        if ([c.domain containsString:@"163.com"] && c.value.length) {
            [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:c];
            [parts addObject:[NSString stringWithFormat:@"%@=%@", c.name, c.value]];
        }
    }
    [[LLLCloudRequest shared] ingestCookieString:[parts componentsJoinedByString:@"; "]];

    if (![self hasCookie]) { if (done) done(NO, @"里面没有 MUSIC_U"); return; }

    __weak typeof(self) w = self;
    [self fetchAccountThen:^(BOOL ok, NSString *m) {
        __strong typeof(w) s = w;
        if (!s) return;
        s.loggedIn = ok && [s hasCookie];
        if (done) done(s.loggedIn,
                       s.loggedIn
                       ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                       : (m ?: @"Cookie 无效"));
    }];
}

- (void)fetchAccountThen:(void (^)(BOOL, NSString *))done {
    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] GET:@"/api/nuser/account/get"
                          params:nil
                            kind:LLLReqKindRead
                         retries:1
                            done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        BOOL ok = NO;
        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *profile = json[@"profile"];
            if ([profile isKindOfClass:NSDictionary.class]) {
                s.nickname = profile[@"nickname"];
                s.uid = [profile[@"userId"] longLongValue];
                s.vipType = [profile[@"vipType"] integerValue];
                ok = (s.uid != 0);
            }
        }
        s.lastAccountRefresh = CFAbsoluteTimeGetCurrent();
        if (done) done(ok, ok ? nil : @"账号信息拿不到，Cookie 可能已失效");
    }];
}

- (void)refreshAccountIfNeeded:(void (^)(BOOL))done {
    /* 30 秒内不重复问，避免来回切页把接口打成风控 */
    if (CFAbsoluteTimeGetCurrent() - _lastAccountRefresh < 30) {
        if (done) done(self.loggedIn);
        return;
    }
    if (![self hasCookie]) {
        _loggedIn = NO;
        if (done) done(NO);
        return;
    }
    __weak typeof(self) w = self;
    [self fetchAccountThen:^(BOOL ok, NSString *m) {
        __strong typeof(w) s = w;
        if (!s) return;
        s.loggedIn = ok;
        if (done) done(ok);
    }];
}

#pragma mark - 歌单 / 搜索

- (NSArray<NSDictionary *> *)mapTracks:(NSArray *)tracks {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *t in tracks) {
        if (![t isKindOfClass:NSDictionary.class]) continue;

        NSString *name = [t[@"name"] isKindOfClass:NSString.class] ? t[@"name"] : @"未知";
        NSString *artist = @"";
        NSString *pic = nil;

        if ([t[@"al"] isKindOfClass:NSDictionary.class]) pic = t[@"al"][@"picUrl"];
        if ((![pic isKindOfClass:NSString.class] || !pic.length) &&
            [t[@"album"] isKindOfClass:NSDictionary.class]) pic = t[@"album"][@"picUrl"];

        NSTimeInterval dur = [t[@"dt"] doubleValue] / 1000.0;
        if (dur <= 0) dur = [t[@"duration"] doubleValue] / 1000.0;

        NSArray *ar = t[@"ar"] ?: t[@"artists"];
        if ([ar isKindOfClass:NSArray.class] && ar.count) {
            NSMutableArray *nm = [NSMutableArray array];
            for (NSDictionary *a in ar) {
                if ([a isKindOfClass:NSDictionary.class] && [a[@"name"] isKindOfClass:NSString.class])
                    [nm addObject:a[@"name"]];
            }
            if (nm.count) artist = [nm componentsJoinedByString:@"/"];
        }

        NSNumber *sid = [t[@"id"] isKindOfClass:NSNumber.class] ? t[@"id"] : @0;
        [out addObject:@{
            @"id"     : sid,
            @"name"   : name,
            @"artist" : artist,
            @"pic"    : ([pic isKindOfClass:NSString.class] ? pic : @""),
            @"dur"    : @(dur),
        }];
    }
    return out;
}

- (void)loadLikedSongs:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    if (![self hasCookie]) { if (done) done(nil, @"还没登录"); return; }

    __weak typeof(self) w = self;
    void (^afterUid)(void) = ^{
        __strong typeof(w) s = w;
        if (!s) return;
        if (s.uid == 0) { if (done) done(nil, @"拿不到用户 ID"); return; }

        [[LLLCloudRequest shared] GET:@"/api/user/playlist"
                              params:@{ @"uid" : [NSString stringWithFormat:@"%lld", s.uid],
                                        @"limit" : @"1000", @"offset" : @"0" }
                                kind:LLLReqKindRead
                             retries:1
                                done:^(id json, NSInteger sc, NSError *err) {
            __strong typeof(w) s2 = w;
            if (!s2) return;

            NSArray *list = [json isKindOfClass:NSDictionary.class] ? json[@"playlist"] : nil;
            if (![list isKindOfClass:NSArray.class]) { if (done) done(nil, @"歌单接口没返回数据"); return; }

            NSNumber *likedId = nil;
            for (NSDictionary *p in list) {
                if (![p isKindOfClass:NSDictionary.class]) continue;
                if ([p[@"specialType"] integerValue] == 5) { likedId = p[@"id"]; break; }
                if ([p[@"name"] isEqualToString:@"我喜欢的音乐"]) { likedId = p[@"id"]; break; }
            }
            if (!likedId) { if (done) done(nil, @"没找到「我喜欢的音乐」"); return; }
            [s2 loadPlaylist:likedId done:done];
        }];
    };

    if (_uid != 0) { afterUid(); return; }
    [self fetchAccountThen:^(BOOL ok, NSString *m) { afterUid(); }];
}

- (void)loadPlaylist:(NSNumber *)pid done:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    if (!pid) { if (done) done(nil, @"没有歌单 ID"); return; }

    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] GET:@"/api/v6/playlist/detail"
                          params:@{ @"id" : pid.stringValue, @"n" : @"1000" }
                            kind:LLLReqKindRead
                         retries:1
                            done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSDictionary *pl = [json isKindOfClass:NSDictionary.class] ? json[@"playlist"] : nil;
        NSArray *tracks = [pl isKindOfClass:NSDictionary.class] ? pl[@"tracks"] : nil;
        if (![tracks isKindOfClass:NSArray.class]) { if (done) done(nil, @"歌单接口没返回数据"); return; }

        NSArray *out = [s mapTracks:tracks];
        if (done) done(out, out.count ? nil : @"歌单是空的");
    }];
}

- (void)searchSongs:(NSString *)keyword done:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    NSString *kw = [keyword stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!kw.length) { if (done) done(nil, @"关键词是空的"); return; }

    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] GET:@"/api/search/get"
                          params:@{ @"s" : kw, @"type" : @"1", @"limit" : @"30", @"offset" : @"0" }
                            kind:LLLReqKindRead
                         retries:1
                            done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSArray *songs = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *r = json[@"result"];
            if ([r isKindOfClass:NSDictionary.class]) songs = r[@"songs"];
        }
        if (![songs isKindOfClass:NSArray.class]) { if (done) done(nil, @"搜索没返回结果"); return; }

        NSArray *out = [s mapTracks:songs];
        if (done) done(out, out.count ? nil : @"没搜到歌");
    }];
}

- (void)loadDailyRecommend:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    if (![self hasCookie]) { if (done) done(nil, @"还没登录"); return; }

    __weak typeof(self) w = self;
    [[LLLCloudRequest shared] GET:@"/api/v3/discovery/recommend/songs"
                          params:nil
                            kind:LLLReqKindRead
                         retries:1
                            done:^(id json, NSInteger sc, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSDictionary *data = [json isKindOfClass:NSDictionary.class] ? json[@"data"] : nil;
        NSArray *daily = [data isKindOfClass:NSDictionary.class] ? data[@"dailySongs"] : nil;
        if (![daily isKindOfClass:NSArray.class]) { if (done) done(nil, @"每日推荐拿不到"); return; }
        NSArray *out = [s mapTracks:daily];
        if (done) done(out, out.count ? nil : @"今天没有推荐");
    }];
}

#pragma mark - 取流 / 封面

- (void)resolvePlayURL:(NSNumber *)songID done:(void (^)(NSURL *, NSString *))done {
    if (!songID) { if (done) done(nil, @"没有歌曲 ID"); return; }
    [[LLLCloudVIP shared] resolveStreamURL:songID duration:0 done:done];
}

- (void)loadArtwork:(NSString *)url done:(void (^)(UIImage *))done {
    if (!url.length) { if (done) done(nil); return; }
    [[LLLCloudVIP shared] artworkFor:url done:done];
}

#pragma mark - 退出

- (void)logout {
    [self cancelLogin];
    for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
        if ([c.domain containsString:@"music.163.com"]) {
            [NSHTTPCookieStorage.sharedHTTPCookieStorage deleteCookie:c];
        }
    }
    [[LLLCloudVIP shared] clearArtworkCache];
    _loggedIn = NO;
    _nickname = nil;
    _uid = 0;
    _vipType = 0;
    _lastAccountRefresh = 0;
}

@end
