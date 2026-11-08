//
//  LLLCloudMusic.m
//
//  走网易云网页版那套公开接口（unikey / client/login / nuser / playlist / outer url）。
//  只做三件事：扫码登录、拉「我喜欢的音乐」、拿播放直链。
//

#import "LLLCloudMusic.h"
#import "BaseComponents.h"
#import <CoreImage/CoreImage.h>

static NSString * const kBase      = @"https://music.163.com";
static NSString * const kUserAgent = @"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) "
                                     @"AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";

@interface LLLCloudMusic ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, copy)   NSString *uniKey;
@property (nonatomic, assign) NSInteger pollCount;
@property (nonatomic, copy)   void (^progressBlock)(UIImage *, NSString *);
@property (nonatomic, copy)   void (^doneBlock)(BOOL, NSString *);
@property (nonatomic, assign) BOOL loggedIn;
@property (nonatomic, copy)   NSString *nickname;
@property (nonatomic, assign) long long uid;

- (BOOL)hasCookie;
- (void)pollOnce;
- (void)fetchAccountThen:(void (^)(BOOL ok, NSString *msg))done;
- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
           done:(void (^)(id json, NSError *err))done;
- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
          retry:(NSInteger)retry
           done:(void (^)(id json, NSError *err))done;
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
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.defaultSessionConfiguration;
        cfg.HTTPAdditionalHeaders = @{
            @"User-Agent" : kUserAgent,
            @"Referer"    : kBase,
            @"Origin"     : kBase,
        };
        cfg.timeoutIntervalForRequest = 15;
        _session = [NSURLSession sessionWithConfiguration:cfg];
        _loggedIn = [self hasCookie];
    }
    return self;
}

#pragma mark - Cookie

- (BOOL)hasCookie {
    for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
        if ([c.domain containsString:@"music.163.com"] &&
            ([c.name isEqualToString:@"MUSIC_U"] || [c.name isEqualToString:@"MUSIC_A"])) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - 通用请求

- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
           done:(void (^)(id json, NSError *err))done {
    [self getJSON:path params:params retry:2 done:done];
}

- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
          retry:(NSInteger)retry
           done:(void (^)(id json, NSError *err))done {
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@", kBase, path];
    if (params.count) {
        [url appendString:@"?"];
        __block NSUInteger i = 0;
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            if (i++) [url appendString:@"&"];
            [url appendFormat:@"%@=%@", k, [v stringByAddingPercentEncodingWithAllowedCharacters:
                                             NSCharacterSet.URLQueryAllowedCharacterSet]];
        }];
    }

    NSURL *finalURL = [NSURL URLWithString:url];
    if (!finalURL) {                     // URL 非法直接返回，别把 nil 丢给 requestWithURL（会抛异常崩溃）
        if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-1 userInfo:nil]);
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:finalURL];
    req.HTTPMethod = @"GET";
    [req setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];

    __weak typeof(self) w = self;
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        if (err || !data) {
            if (retry > 0) {
                NSTimeInterval wait = (retry == 2) ? 1.0 : 2.0;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
                               dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                    __strong typeof(w) s2 = w;
                    if (s2) [s2 getJSON:path params:params retry:retry - 1 done:done];
                });
                return;
            }
            if (done) done(nil, err);
            return;
        }

        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (!obj && retry > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                __strong typeof(w) s2 = w;
                if (s2) [s2 getJSON:path params:params retry:retry - 1 done:done];
            });
            return;
        }
        if (done) done(obj, je);
    }] resume];
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

#pragma mark - 登录

- (void)cancelLogin {
    [_pollTimer invalidate];
    _pollTimer = nil;
    _pollCount = 0;
    _uniKey = nil;
}

- (void)startLoginWithQR:(void (^)(UIImage *, NSString *))progress
              completion:(void (^)(BOOL, NSString *))done {
    [self cancelLogin];
    _progressBlock = [progress copy];
    _doneBlock = [done copy];

    __weak typeof(self) w = self;
    [self getJSON:@"/api/login/qrcode/unikey" params:@{ @"type" : @"1" } done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSString *key = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            key = json[@"unikey"];
            if (!key) key = json[@"key"];
        }
        if (!key.length) {
            if (s.doneBlock) s.doneBlock(NO, @"拿不到 unikey，网络或接口变了");
            return;
        }

        s.uniKey = key;
        s.pollCount = 0;

        NSString *content = [NSString stringWithFormat:@"%@/login?codekey=%@", kBase, key];
        UIImage *qr = LLLQRImage(content, 220);
        if (s.progressBlock) s.progressBlock(qr, @"请用网易云 App 扫码");

        // 定时器必须在主线程的 runloop 上创建，否则永远不触发
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) ss2 = w;
            if (!ss2) return;
            ss2.pollTimer = [NSTimer timerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
                __strong typeof(w) sss = w;
                if (!sss) { [t invalidate]; return; }
                [sss pollOnce];
            }];
            [[NSRunLoop mainRunLoop] addTimer:ss2.pollTimer forMode:NSRunLoopCommonModes];
        });
    }];
}

- (void)pollOnce {
    if (!_uniKey.length) { [self cancelLogin]; return; }

    _pollCount++;
    if (_pollCount > 90) {           // 3 分钟
        [self cancelLogin];
        if (_doneBlock) _doneBlock(NO, @"二维码超时，重新来一次");
        return;
    }

    __weak typeof(self) w = self;
    [self getJSON:@"/api/login/qrcode/client/login"
           params:@{ @"key" : _uniKey, @"type" : @"1" }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSInteger code = 800;
        NSString *msg = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            code = [json[@"code"] integerValue];
            msg = json[@"message"];
        }

        if (code == 800) {
            if (s.progressBlock) s.progressBlock(nil, @"等待扫码…");
        } else if (code == 801) {
            if (s.progressBlock) s.progressBlock(nil, @"已扫码，请在手机上确认");
        } else if (code == 802) {
            [s cancelLogin];
            if (s.doneBlock) s.doneBlock(NO, @"已在手机上取消");
        } else if (code == 803) {
            [s cancelLogin];
            s.loggedIn = YES;
            [s fetchAccountThen:^(BOOL ok, NSString *m) {
                if (s.doneBlock) s.doneBlock(ok, ok ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"] : m);
            }];
        } else {
            if (s.progressBlock) s.progressBlock(nil, msg.length ? msg : @"等待中…");
        }
    }];
}

- (void)fetchAccountThen:(void (^)(BOOL, NSString *))done {
    __weak typeof(self) w = self;
    [self getJSON:@"/api/nuser/account/get" params:nil done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *profile = json[@"profile"];
            if ([profile isKindOfClass:NSDictionary.class]) {
                s.nickname = profile[@"nickname"];
                s.uid = [profile[@"userId"] longLongValue];
            }
        }
        // 兜底：从 cookie 里翻 uid
        if (s.uid == 0) {
            for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
                if ([c.name isEqualToString:@"MUSIC_U"] && c.value.length > 30) break;
            }
        }
        if (done) done(YES, nil);
    }];
}

#pragma mark - 我喜欢的音乐

- (void)loadLikedSongs:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    if (![self hasCookie]) { if (done) done(nil, @"还没登录"); return; }

    __weak typeof(self) w = self;
    void (^afterUid)(void) = ^{
        __strong typeof(w) s = w;
        if (!s) return;

        if (s.uid == 0) { if (done) done(nil, @"拿不到用户 ID"); return; }

        [s getJSON:@"/api/user/playlist"
            params:@{ @"uid" : [NSString stringWithFormat:@"%lld", s.uid],
                      @"limit" : @"1000", @"offset" : @"0" }
              done:^(id json, NSError *err) {
            __strong typeof(w) ss = w;
            if (!ss) return;

            NSArray *list = nil;
            if ([json isKindOfClass:NSDictionary.class]) list = json[@"playlist"];
            if (![list isKindOfClass:NSArray.class]) { if (done) done(nil, @"歌单接口没返回数据"); return; }

            NSNumber *likedId = nil;
            for (NSDictionary *p in list) {
                if (![p isKindOfClass:NSDictionary.class]) continue;
                if ([p[@"specialType"] integerValue] == 5) { likedId = p[@"id"]; break; }
                if ([p[@"name"] isEqualToString:@"我喜欢的音乐"]) { likedId = p[@"id"]; break; }
            }
            if (!likedId) { if (done) done(nil, @"没找到「我喜欢的音乐」"); return; }

            [ss getJSON:@"/api/v6/playlist/detail"
                params:@{ @"id" : likedId.stringValue, @"n" : @"1000" }
                  done:^(id j2, NSError *e2) {
                NSMutableArray *out = [NSMutableArray array];
                NSDictionary *pl = ([j2 isKindOfClass:NSDictionary.class]) ? j2[@"playlist"] : nil;
                NSArray *tracks = ([pl isKindOfClass:NSDictionary.class]) ? pl[@"tracks"] : nil;
                if ([tracks isKindOfClass:NSArray.class]) {
                    for (NSDictionary *t in tracks) {
                        if (![t isKindOfClass:NSDictionary.class]) continue;
                        NSString *name = t[@"name"];
                        NSArray *ar = t[@"ar"];
                        NSString *artist = @"";
                        if ([ar isKindOfClass:NSArray.class] && ar.count) {
                            NSDictionary *a0 = ar.firstObject;
                            if ([a0 isKindOfClass:NSDictionary.class]) artist = a0[@"name"] ?: @"";
                        }
                        [out addObject:@{ @"id"   : t[@"id"] ?: @0,
                                          @"name" : name ?: @"未知",
                                          @"artist" : artist }];
                    }
                }
                if (done) done(out, out.count ? nil : @"列表是空的");
            }];
        }];
    };

    if (_uid != 0) { afterUid(); return; }
    [self fetchAccountThen:^(BOOL ok, NSString *m) { afterUid(); }];
}

#pragma mark - 搜索

- (void)searchSongs:(NSString *)keyword done:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    if (!keyword.length) { if (done) done(nil, @"关键词是空的"); return; }

    __weak typeof(self) w = self;
    [self getJSON:@"/api/search/get"
           params:@{ @"s" : keyword, @"type" : @"1", @"limit" : @"30", @"offset" : @"0" }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSArray *songs = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *r = json[@"result"];
            if ([r isKindOfClass:NSDictionary.class]) songs = r[@"songs"];
        }
        if (![songs isKindOfClass:NSArray.class]) {
            if (done) done(nil, @"搜索没返回结果");
            return;
        }

        NSMutableArray *out = [NSMutableArray array];
        for (NSDictionary *sg in songs) {
            if (![sg isKindOfClass:NSDictionary.class]) continue;
            NSString *artist = @"";
            NSArray *ar = sg[@"artists"];
            if ([ar isKindOfClass:NSArray.class] && ar.count) {
                NSDictionary *a0 = ar.firstObject;
                if ([a0 isKindOfClass:NSDictionary.class]) artist = a0[@"name"] ?: @"";
            }
            [out addObject:@{ @"id" : sg[@"id"] ?: @0,
                              @"name" : sg[@"name"] ?: @"未知",
                              @"artist" : artist }];
        }
        if (done) done(out, out.count ? nil : @"没搜到歌");
    }];
}

#pragma mark - 播放直链

- (void)resolvePlayURL:(NSNumber *)songID done:(void (^)(NSURL *, NSString *))done {
    if (!songID) { if (done) done(nil, @"没有歌曲 ID"); return; }

    NSString *s = [NSString stringWithFormat:@"%@/song/media/outer/url?id=%@.mp3", kBase, songID];
    NSURL *url = [NSURL URLWithString:s];
    if (done) done(url, nil);   // AVPlayer 会自己跟 302
}

#pragma mark - 退出

- (void)logout {
    [self cancelLogin];
    for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
        if ([c.domain containsString:@"music.163.com"]) {
            [NSHTTPCookieStorage.sharedHTTPCookieStorage deleteCookie:c];
        }
    }
    _loggedIn = NO;
    _nickname = nil;
    _uid = 0;
}

@end
