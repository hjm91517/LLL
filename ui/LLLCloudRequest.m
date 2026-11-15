//
//  LLLCloudRequest.m
//

#import "LLLCloudRequest.h"
#import "BaseComponents.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const kBase = @"https://music.163.com";

/* 客户端指纹：网页 UA 打登录/播放接口会被判 401 ENC，必须用客户端串 */
static NSString * const kClientUA = @"NeteaseMusic/9.1.60.240711141503(8009060);"
                                    @"Dalvik/2.1.0 (Linux; U; Android 11)";

@interface LLLCloudRequest ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *lastFireAt;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id> *gates;
@property (nonatomic, assign) NSInteger cooldownUntil;   ///< 被风控后的全局静默截止（epoch 秒）
@end

@implementation LLLCloudRequest

+ (instancetype)shared {
    static LLLCloudRequest *r;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ r = [LLLCloudRequest new]; });
    return r;
}

- (instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.defaultSessionConfiguration;
        cfg.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        cfg.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        cfg.HTTPShouldSetCookies = YES;
        cfg.timeoutIntervalForRequest = 15;
        cfg.timeoutIntervalForResource = 40;
        _session = [NSURLSession sessionWithConfiguration:cfg];

        _lastFireAt = [NSMutableDictionary dictionary];
        _gates = [NSMutableDictionary dictionary];
        for (NSInteger i = 0; i <= 2; i++) _gates[@(i)] = [NSObject new];
    }
    return self;
}

#pragma mark - Cookie

- (NSString *)cookieHeader {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
        if ([c.domain containsString:@"music.163.com"] && c.value.length)
            [parts addObject:[NSString stringWithFormat:@"%@=%@", c.name, c.value]];
    }
    if (!parts.count) return @"os=ios; appver=9.1.60";
    [parts addObject:@"os=ios"];
    [parts addObject:@"appver=9.1.60"];
    return [parts componentsJoinedByString:@"; "];
}

- (void)ingestCookieString:(NSString *)raw {
    if (!raw.length) return;
    for (NSString *kv in [raw componentsSeparatedByString:@";"]) {
        NSRange eq = [kv rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        NSString *name = [[kv substringToIndex:eq.location]
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *val = [[kv substringFromIndex:eq.location + 1]
                         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!name.length || !val.length) continue;

        NSDictionary *props = @{
            NSHTTPCookieName   : name,
            NSHTTPCookieValue  : val,
            NSHTTPCookieDomain : @"music.163.com",
            NSHTTPCookiePath   : @"/",
            NSHTTPCookieSecure : @"TRUE",
        };
        NSHTTPCookie *c = [NSHTTPCookie cookieWithProperties:props];
        if (c) [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:c];
    }
}

#pragma mark - 节流

- (NSTimeInterval)minIntervalForKind:(LLLReqKind)kind {
    switch (kind) {
        case LLLReqKindPlay:  return 0.25;   /* 切歌时别被限速误伤 */
        case LLLReqKindWrite: return 5.0;    /* 登录类，压到最慢 */
        case LLLReqKindRead:
        default:              return 0.5;
    }
}

/// 按 kind 串行排队：同一类请求两次之间至少隔 minInterval，队列不会堆
- (void)enqueue:(LLLReqKind)kind block:(void (^)(void))block {
    id gate = _gates[@(kind)] ?: (_gates[@(kind)] = [NSObject new]);
    @synchronized (gate) {
        NSNumber *lastN = _lastFireAt[@(kind)];
        double last = lastN ? lastN.doubleValue : 0;
        double now = CFAbsoluteTimeGetCurrent();
        double need = [self minIntervalForKind:kind];
        double wait = MAX(0, last + need - now);

        NSInteger cd = self.cooldownUntil;
        NSInteger ts = (NSInteger)[[NSDate date] timeIntervalSince1970];
        if (cd > ts) wait = MAX(wait, (double)(cd - ts));

        _lastFireAt[@(kind)] = @(now + wait);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), block);
    }
}

#pragma mark - 风控识别

+ (BOOL)isRiskCode:(NSInteger)code {
    /* -460 是网易的"请求频繁/校验失败"，400 系列里 401(ENC) 也是风控，
       503 在登录链路里常表示 ursToken/验证码校验被拒 */
    return (code == -460 || code == 460 || code == 401 || code == 503 || code == 250);
}

+ (NSString *)friendlyMessageForCode:(NSInteger)code message:(NSString *)msg {
    if (code == -460 || code == 460) return @"请求太密被限流了，歇几秒再来";
    if (code == 401) return @"接口被风控拦了，换网页登录最稳";
    if (code == 503) return @"验证没通过，重新收一次验证码";
    if (code == 250) return @"账号触发安全校验，去网页端过一次";
    if (msg.length) return msg;
    return [NSString stringWithFormat:@"接口返回 %ld", (long)code];
}

- (void)noteRiskIfNeeded:(NSInteger)code {
    if (![LLLCloudRequest isRiskCode:code]) return;
    /* 撞风控就整体静默 8~20 秒，硬冲只会把 IP 打进黑名单 */
    NSInteger back = 8 + (NSInteger)arc4random_uniform(12);
    self.cooldownUntil = (NSInteger)[[NSDate date] timeIntervalSince1970] + back;
    lllLog(@"网易云风控命中 code=%ld，全局静默 %ld 秒", (long)code, (long)back);
}

#pragma mark - 请求

- (NSMutableURLRequest *)requestForPath:(NSString *)path
                                 params:(NSDictionary<NSString *, NSString *> *)params {
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@", kBase, path];
    if (params.count) {
        [url appendString:@"?"];
        __block NSUInteger i = 0;
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            if (i++) [url appendString:@"&"];
            NSMutableCharacterSet *allow = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
            [allow removeCharactersInString:@"+&=?#/"];
            NSString *ek = [k stringByAddingPercentEncodingWithAllowedCharacters:allow] ?: @"";
            NSString *ev = [v stringByAddingPercentEncodingWithAllowedCharacters:allow] ?: @"";
            [url appendFormat:@"%@=%@", ek, ev];
        }];
    }
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return nil;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:kClientUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    [req setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    return req;
}

- (void)GET:(NSString *)path
     params:(NSDictionary<NSString *, NSString *> *)params
       kind:(LLLReqKind)kind
    retries:(NSInteger)retries
       done:(void (^)(id, NSInteger, NSError *))done {
    __weak typeof(self) w = self;
    [self enqueue:kind block:^{
        __strong typeof(w) s = w;
        if (!s) return;

        NSMutableURLRequest *req = [s requestForPath:path params:params];
        if (!req) { if (done) done(nil, -1, nil); return; }
        [req setValue:[s cookieHeader] forHTTPHeaderField:@"Cookie"];

        [[s.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger sc = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : -1;
            id json = nil;
            if (data.length) {
                json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            }
            NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
            [s noteRiskIfNeeded:code];

            BOOL retryable = (err != nil) || (sc >= 500) || [LLLCloudRequest isRiskCode:code];
            if (retryable && retries > 0) {
                double pause = 0.8 * pow(2.0, (double)(2 - retries));
                pause += arc4random_uniform(600) / 1000.0;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(pause * NSEC_PER_SEC)),
                               dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                    [s GET:path params:params kind:kind retries:retries - 1 done:done];
                });
                return;
            }
            if (done) done(json, sc, err);
        }] resume];
    }];
}

- (void)POSTForm:(NSString *)path
            body:(NSString *)body
            kind:(LLLReqKind)kind
         retries:(NSInteger)retries
            done:(void (^)(id, NSInteger, NSError *))done {
    __weak typeof(self) w = self;
    [self enqueue:kind block:^{
        __strong typeof(w) s = w;
        if (!s) return;

        NSMutableURLRequest *req = [s requestForPath:path params:nil];
        if (!req) { if (done) done(nil, -1, nil); return; }
        req.HTTPMethod = @"POST";
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[s cookieHeader] forHTTPHeaderField:@"Cookie"];
        req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

        [[s.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger sc = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : -1;
            id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
            [s noteRiskIfNeeded:code];

            BOOL retryable = (err != nil) || (sc >= 500);
            if (retryable && retries > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                               dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                    [s POSTForm:path body:body kind:kind retries:retries - 1 done:done];
                });
                return;
            }
            if (done) done(json, sc, err);
        }] resume];
    }];
}

@end
