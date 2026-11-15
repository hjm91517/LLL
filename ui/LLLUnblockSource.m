//
//  ui/LLLUnblockSource.m
//  会员曲换源：内置酷我通道（默认可用）+ 可选外部解锁服务。
//

#import "LLLUnblockSource.h"
#import "BaseComponents.h"

static NSString * const kBaseKey = @"LLL.unblockBase";
static NSString * const kKWUA =
    @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) "
    @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1";

@interface LLLUnblockSource ()
@property (nonatomic, strong) NSURLSession *session;

- (void)tryServer:(NSNumber *)sid done:(void (^)(NSURL *u, NSString *e))done;
- (void)tryKuwo:(NSString *)name artist:(NSString *)artist
           done:(void (^)(NSURL *u, NSString *e))done;
- (void)probeAudio:(NSURL *)u done:(void (^)(BOOL ok))done;
- (NSURL *)urlFromJSON:(id)json;
@end

@implementation LLLUnblockSource

+ (instancetype)shared {
    static LLLUnblockSource *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [LLLUnblockSource new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.defaultSessionConfiguration;
        cfg.timeoutIntervalForRequest = 12;
        cfg.HTTPAdditionalHeaders = @{ @"User-Agent" : kKWUA };
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

+ (NSString *)helpText {
    return @"会员曲默认走内置酷我换源，无需配置即可播放大多数曲目；"
           @"如需更高命中率，可再填一个 UnblockNeteaseMusic 服务地址。";
}

#pragma mark - 配置

- (NSString *)baseURL {
    NSString *v = [NSUserDefaults.standardUserDefaults stringForKey:kBaseKey];
    v = [v stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!v.length) return nil;
    if (![v hasPrefix:@"http"]) v = [@"http://" stringByAppendingString:v];
    while ([v hasSuffix:@"/"]) v = [v substringToIndex:v.length - 1];
    return v;
}

- (void)setBaseURL:(NSString *)url {
    NSString *v = [url stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!v.length) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kBaseKey];
        return;
    }
    [NSUserDefaults.standardUserDefaults setObject:v forKey:kBaseKey];
}

- (BOOL)isConfigured { return self.baseURL.length > 0; }

#pragma mark - 探测

- (void)probeAudio:(NSURL *)u done:(void (^)(BOOL))done {
    if (!u) { if (done) done(NO); return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 8;
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        BOOL ok = NO;
        if (!e && [r isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *h = (NSHTTPURLResponse *)r;
            NSString *ct = [[h allHeaderFields][@"Content-Type"] lowercaseString] ?: @"";
            if ((h.statusCode == 200 || h.statusCode == 206) &&
                ([ct containsString:@"audio"] || [ct containsString:@"octet-stream"])) {
                ok = YES;
            }
        }
        if (done) done(ok);
    }] resume];
}

#pragma mark - 外部解锁服务（可选）

- (NSURL *)urlFromJSON:(id)json {
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    id u = json[@"url"];
    if (![u isKindOfClass:NSString.class] || ![u length]) {
        NSDictionary *d = json[@"data"];
        if ([d isKindOfClass:NSDictionary.class]) u = d[@"url"];
    }
    if (![u isKindOfClass:NSString.class] || [u length] < 10) return nil;
    return [NSURL URLWithString:u];
}

- (void)tryServer:(NSNumber *)sid done:(void (^)(NSURL *, NSString *))done {
    NSString *base = self.baseURL;
    if (!base.length) { if (done) done(nil, @"未配置解锁服务"); return; }

    NSString *p = [NSString stringWithFormat:@"%@/match?id=%@&br=320000", base, sid.stringValue];
    NSURL *u = [NSURL URLWithString:p];
    if (!u) { if (done) done(nil, @"解锁地址不合法"); return; }

    __weak typeof(self) w = self;
    [[_session dataTaskWithRequest:[NSURLRequest requestWithURL:u]
              completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (err || !data.length) { if (done) done(nil, @"解锁服务无响应"); return; }

        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSURL *hit = [s urlFromJSON:json];
        if (!hit) { if (done) done(nil, @"解锁服务没找到替代源"); return; }

        [s probeAudio:hit done:^(BOOL ok) {
            if (ok) { if (done) done(hit, nil); }
            else    { if (done) done(nil, @"解锁源地址不可播"); }
        }];
    }] resume];
}

#pragma mark - 酷我（内置，默认通道）

- (void)tryKuwo:(NSString *)name artist:(NSString *)artist
           done:(void (^)(NSURL *, NSString *))done {
    NSString *kw = [NSString stringWithFormat:@"%@ %@", name ?: @"", artist ?: @""];
    kw = [kw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!kw.length) { if (done) done(nil, @"缺少歌名"); return; }

    NSString *q = [kw stringByAddingPercentEncodingWithAllowedCharacters:
                   NSCharacterSet.URLQueryAllowedCharacterSet] ?: @"";
    NSString *sUrl = [NSString stringWithFormat:
        @"http://search.kuwo.cn/r.s?all=%@&ft=music&itemset=web_2013&client=kt&pn=0&rn=5&rformat=json&encoding=utf8", q];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:sUrl]];
    [req setValue:kKWUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"http://www.kuwo.cn" forHTTPHeaderField:@"Referer"];

    __weak typeof(self) w = self;
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (err || !data.length) { if (done) done(nil, @"酷我搜索失败"); return; }

        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        NSRegularExpression *re =
            [NSRegularExpression regularExpressionWithPattern:@"MUSIC_(\\d+)" options:0 error:nil];
        NSArray *m = [re matchesInString:text options:0 range:NSMakeRange(0, text.length)];
        if (!m.count) { if (done) done(nil, @"酷我没搜到这首"); return; }

        NSString *rid = nil;
        for (NSTextCheckingResult *r in m) {
            if (r.numberOfRanges > 1) {
                rid = [text substringWithRange:[r rangeAtIndex:1]];
                break;
            }
        }
        if (!rid.length) { if (done) done(nil, @"酷我没搜到这首"); return; }

        NSString *c = [NSString stringWithFormat:
            @"https://antiserver.kuwo.cn/anti.s?type=convert_url&format=mp3&response=url&rid=MUSIC_%@", rid];
        NSMutableURLRequest *r2 = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:c]];
        [r2 setValue:kKWUA forHTTPHeaderField:@"User-Agent"];
        [r2 setValue:@"http://www.kuwo.cn" forHTTPHeaderField:@"Referer"];

        [[s.session dataTaskWithRequest:r2 completionHandler:^(NSData *d2, NSURLResponse *p2, NSError *e2) {
            __strong typeof(w) s2 = w;
            if (!s2) return;
            if (e2 || !d2.length) { if (done) done(nil, @"酷我取流失败"); return; }

            NSString *uStr = [[[NSString alloc] initWithData:d2 encoding:NSUTF8StringEncoding] ?: @""]
                                .stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet;
            if (![uStr hasPrefix:@"http"]) { if (done) done(nil, @"酷我没给出可用地址"); return; }

            NSURL *u = [NSURL URLWithString:uStr];
            [s2 probeAudio:u done:^(BOOL ok) {
                if (ok) { if (done) done(u, nil); }
                else    { if (done) done(nil, @"酷我地址不可播"); }
            }];
        }] resume];
    }] resume];
}

#pragma mark - 主流程

- (void)resolveSongID:(NSNumber *)songID
                 name:(NSString *)name
               artist:(NSString *)artist
             duration:(NSTimeInterval)duration
                 done:(void (^)(NSURL *, NSString *))done {
    if (!songID && !name.length) { if (done) done(nil, @"没有可用信息"); return; }

    __weak typeof(self) w = self;
    void (^fallback)(NSString *) = ^(NSString *why) {
        __strong typeof(w) s = w;
        if (!s) return;
        [s tryKuwo:name artist:artist done:^(NSURL *u, NSString *e) {
            if (u) { if (done) done(u, nil); return; }
            NSString *msg = e.length ? e : @"换源失败";
            if (done) done(nil, msg);
        }];
    };

    if ([self isConfigured] && songID) {
        [self tryServer:songID done:^(NSURL *u, NSString *e) {
            if (u) { if (done) done(u, nil); return; }
            fallback(e);
        }];
        return;
    }
    fallback(nil);
}

@end
