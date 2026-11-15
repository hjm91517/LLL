//
//  ui/LLLUnblockSource.m
//

#import "LLLUnblockSource.h"
#import "BaseComponents.h"

static NSString * const kBaseKey = @"LLL.unblockBase";

@interface LLLUnblockSource ()
@property (nonatomic, strong) NSURLSession *session;
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
        cfg.HTTPAdditionalHeaders = @{
            @"User-Agent" : @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) "
                            @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 "
                            @"Mobile/15E148 Safari/604.1",
        };
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

+ (NSString *)helpText {
    return @"会员曲靠换源播放：填一个 UnblockNeteaseMusic 兼容服务地址（自建最稳），"
           @"例如 http://192.168.1.10:8080";
}

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

#pragma mark - 换源

- (void)probe:(NSURL *)u done:(void (^)(BOOL ok))done {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 8;
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        BOOL ok = NO;
        if (!e && [r isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *h = (NSHTTPURLResponse *)r;
            NSString *ct = [[h allHeaderFields][@"Content-Type"] lowercaseString] ?: @"";
            if ((h.statusCode == 200 || h.statusCode == 206) &&
                [ct containsString:@"audio"]) {
                ok = YES;
            }
        }
        if (done) done(ok);
    }] resume];
}

- (NSURL *)urlFromJSON:(id)json {
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    id u = json[@"url"];
    if (![u isKindOfClass:NSString.class] || ![u length]) {
        /* UnblockNeteaseMusic 新版可能包一层 data */
        NSDictionary *d = json[@"data"];
        if ([d isKindOfClass:NSDictionary.class]) {
            u = d[@"url"];
        }
    }
    if (![u isKindOfClass:NSString.class] || [u length] < 10) return nil;
    return [NSURL URLWithString:u];
}

- (void)resolveSongID:(NSNumber *)songID
             duration:(NSTimeInterval)duration
                 done:(void (^)(NSURL *, NSString *))done {
    if (!songID) { if (done) done(nil, @"没有歌曲 ID"); return; }

    NSString *base = self.baseURL;
    if (!base.length) {
        if (done) done(nil, @"没配解锁音源地址（会员曲需要它）");
        return;
    }

    NSString *path = [NSString stringWithFormat:
        @"%@/match?id=%@&br=320000&name=&artist=",
        base, songID.stringValue];
    NSURL *u = [NSURL URLWithString:path];
    if (!u) { if (done) done(nil, @"解锁地址不合法"); return; }

    __weak typeof(self) w = self;
    [[_session dataTaskWithRequest:[NSURLRequest requestWithURL:u]
              completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        if (err || !data.length) {
            if (done) done(nil, @"解锁服务没响应");
            return;
        }

        id json = nil;
        @try {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        } @catch (__unused NSException *e) { }

        NSURL *hit = [s urlFromJSON:json];
        if (!hit) { if (done) done(nil, @"解锁服务没找到替代音源"); return; }

        [s probe:hit done:^(BOOL ok) {
            if (ok) { if (done) done(hit, nil); }
            else    { if (done) done(nil, @"解锁源返回的地址不可播"); }
        }];
    }] resume];
}

@end
