//
//  ui/LLLGuestMusic.m  — 4.0
//  免登录音源：不登网易云账号也能听免费曲目。
//

#import "LLLGuestMusic.h"
#import "BaseComponents.h"

static NSString * const kGuestBase = @"https://music.163.com";
static NSString * const kGuestKey  = @"LLL.guestMode";

@interface LLLGuestMusic ()
@property (nonatomic, strong) NSURLSession *session;
- (NSArray<NSDictionary *> *)mapTracks:(NSArray *)tracks;
- (void)probeURL:(NSURL *)u done:(void (^)(BOOL ok))done;
@end

@implementation LLLGuestMusic

+ (instancetype)shared {
    static LLLGuestMusic *g;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ g = [LLLGuestMusic new]; });
    return g;
}

- (instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.defaultSessionConfiguration;
        cfg.HTTPAdditionalHeaders = @{
            @"User-Agent" : @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) "
                            @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 "
                            @"Mobile/15E148 Safari/604.1",
            @"Referer"    : kGuestBase,
        };
        /* 免登录通道不共享 Cookie，避免被当成"半登录"状态被风控 */
        cfg.HTTPCookieStorage = nil;
        cfg.HTTPShouldSetCookies = NO;
        cfg.timeoutIntervalForRequest = 15;
        _session = [NSURLSession sessionWithConfiguration:cfg];

        NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:kGuestKey];
        _enabled = saved ? saved.boolValue : YES;
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kGuestKey];
}

+ (NSString *)capabilityNote {
    return @"免登录可听公开曲库与免费曲目；会员专享曲需要登录账号。";
}

#pragma mark - 请求

- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
           done:(void (^)(id _Nullable json, NSError * _Nullable err))done {
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@", kGuestBase, path];
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
    if (!u) { if (done) done(nil, nil); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:kGuestBase forHTTPHeaderField:@"Referer"];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (done) done(nil, err); return; }
        if (!data.length) { if (done) done(nil, nil); return; }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(je ? nil : obj, je);
    }] resume];
}

- (void)probeURL:(NSURL *)u done:(void (^)(BOOL ok))done {
    if (!u) { if (done) done(NO); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 8;
    [req setValue:kGuestBase forHTTPHeaderField:@"Referer"];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        BOOL ok = NO;
        if (!err && [resp isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *h = (NSHTTPURLResponse *)resp;
            NSString *ctype = [[h allHeaderFields][@"Content-Type"] lowercaseString] ?: @"";
            long long len = h.expectedContentLength;
            if ((h.statusCode == 200 || h.statusCode == 206) &&
                (len <= 0 || len > 32 * 1024) &&
                ([ctype containsString:@"audio"] ||
                 [ctype containsString:@"octet-stream"] ||
                 ctype.length == 0)) {
                ok = YES;
            }
        }
        if (done) done(ok);
    }] resume];
}

#pragma mark - 映射

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
                if ([a isKindOfClass:NSDictionary.class] &&
                    [a[@"name"] isKindOfClass:NSString.class]) {
                    [nm addObject:a[@"name"]];
                }
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
            @"guest"  : @YES,
        }];
    }
    return out;
}

#pragma mark - 搜索

- (void)search:(NSString *)keyword
          done:(void (^)(NSArray<NSDictionary *> * _Nullable, NSString * _Nullable))done {
    NSString *kw = [keyword stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!kw.length) { if (done) done(nil, @"关键词是空的"); return; }

    __weak typeof(self) w = self;
    [self getJSON:@"/api/search/get"
           params:@{ @"s" : kw, @"type" : @"1", @"limit" : @"40", @"offset" : @"0" }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSArray *songs = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *r = json[@"result"];
            if ([r isKindOfClass:NSDictionary.class]) songs = r[@"songs"];
        }
        if (![songs isKindOfClass:NSArray.class]) {
            if (done) done(nil, err ? @"网络错误" : @"搜索没返回结果");
            return;
        }
        if (done) done([s mapTracks:songs], nil);
    }];
}

#pragma mark - 榜单

- (void)loadTopList:(void (^)(NSArray<NSDictionary *> * _Nullable, NSString * _Nullable))done {
    /* 云音乐飙升榜固定 id 19723756，游客可读 */
    __weak typeof(self) w = self;
    [self getJSON:@"/api/v6/playlist/detail"
           params:@{ @"id" : @"19723756", @"n" : @"200" }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSDictionary *pl = [json isKindOfClass:NSDictionary.class] ? json[@"playlist"] : nil;
        NSArray *tracks = [pl isKindOfClass:NSDictionary.class] ? pl[@"tracks"] : nil;
        if (![tracks isKindOfClass:NSArray.class]) {
            if (done) done(nil, @"榜单拿不到");
            return;
        }
        NSArray *mapped = [s mapTracks:tracks];
        if (done) done(mapped, mapped.count ? nil : @"榜单是空的");
    }];
}

#pragma mark - 取流

- (void)resolveStreamURL:(NSNumber *)songID
                duration:(NSTimeInterval)duration
                    done:(void (^)(NSURL * _Nullable, NSString * _Nullable))done {
    if (!songID) { if (done) done(nil, @"没有歌曲 ID"); return; }

    NSString *sidStr = songID.stringValue;
    __weak typeof(self) w = self;

    /* 第一档：外链 mp3，游客直接可用，不走会员鉴权 */
    NSString *outerStr = [NSString stringWithFormat:@"%@/song/media/outer/url?id=%@.mp3",
                          kGuestBase, sidStr];
    NSURL *outer = [NSURL URLWithString:outerStr];

    [self probeURL:outer done:^(BOOL ok) {
        __strong typeof(w) s = w;
        if (!s) return;

        if (ok) {
            if (done) done(outer, nil);
            return;
        }

        /* 第二档：明文 player url（无 Cookie，免费曲给 128k） */
        [s getJSON:@"/api/song/enhance/player/url"
            params:@{ @"ids" : [NSString stringWithFormat:@"[%@]", sidStr], @"br" : @"128000" }
              done:^(id json, NSError *err) {
            __strong typeof(w) s2 = w;
            if (!s2) return;

            NSString *u = nil;
            if ([json isKindOfClass:NSDictionary.class]) {
                NSArray *data = json[@"data"];
                if ([data isKindOfClass:NSArray.class] && data.count) {
                    NSDictionary *d0 = data.firstObject;
                    if ([d0 isKindOfClass:NSDictionary.class] &&
                        [d0[@"url"] isKindOfClass:NSString.class]) {
                        u = d0[@"url"];
                    }
                }
            }
            if (!u.length) {
                if (done) done(nil, @"这首需要登录账号才能听（会员专享）");
                return;
            }

            NSURL *url = [NSURL URLWithString:u];
            if ([url.scheme isEqualToString:@"http"]) {
                NSURL *https = [NSURL URLWithString:
                                [u stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"]];
                if (https) url = https;
            }

            [s2 probeURL:url done:^(BOOL ok2) {
                if (ok2) { if (done) done(url, nil); }
                else { if (done) done(nil, @"音源校验失败，换一首试试"); }
            }];
        }];
    }];
}

@end
