//
//  LLLCloudVIP.m
//

#import "LLLCloudVIP.h"
#import "LLLCloudMusic.h"
#import "BaseComponents.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

static NSString * const kBase      = @"https://music.163.com";
static NSString * const kEapiHost  = @"https://interface.music.163.com";
static NSString * const kUA        = @"NeteaseMusic/9.1.60.240711141503(8009060);"
                                     @"Dalvik/2.1.0 (Linux; U; Android 11)";
static NSString * const kCookieSeed = @"os=ios; appver=9.1.60";
static NSString * const kEapiKey   = @"e82ckenh8dichen8";

@interface LLLCloudVIP ()
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *artCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *pendingArt;
@end

@implementation LLLCloudVIP

+ (instancetype)shared {
    static LLLCloudVIP *v;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ v = [LLLCloudVIP new]; });
    return v;
}

- (instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration *cfg = NSURLSessionConfiguration.defaultSessionConfiguration;
        cfg.HTTPAdditionalHeaders = @{
            @"User-Agent" : kUA,
            @"Referer"    : kBase,
        };
        cfg.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        cfg.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        cfg.HTTPShouldSetCookies = YES;
        cfg.timeoutIntervalForRequest = 15;
        _session = [NSURLSession sessionWithConfiguration:cfg];

        _artCache = [NSCache new];
        _artCache.countLimit = 120;
        _pendingArt = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)hasLogin {
    return [LLLCloudMusic shared].loggedIn;
}

#pragma mark - 加密工具

static NSString *LLLMD5Hex(NSString *s) {
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char out[CC_MD5_DIGEST_LENGTH];
    CC_MD5(d.bytes, (CC_LONG)d.length, out);
    NSMutableString *r = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [r appendFormat:@"%02x", out[i]];
    return r;
}

static NSData *LLLAESECB(NSData *plain, NSString *key) {
    NSData *k = [key dataUsingEncoding:NSUTF8StringEncoding];
    if (k.length != 16) return nil;
    size_t outLen = plain.length + kCCBlockSizeAES128;
    void *out = malloc(outLen);
    if (!out) return nil;
    size_t moved = 0;
    CCCryptorStatus st = CCCrypt(kCCEncrypt, kCCAlgorithmAES,
                                 kCCOptionECBMode | kCCOptionPKCS7Padding,
                                 k.bytes, kCCKeySizeAES128, NULL,
                                 plain.bytes, plain.length, out, outLen, &moved);
    NSData *res = (st == kCCSuccess) ? [NSData dataWithBytes:out length:moved] : nil;
    free(out);
    return res;
}

/// 全站 Cookie 拼串（eapi 必须带登录态，否则只给试听片段）
- (NSString *)cookieHeader {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSHTTPCookie *c in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
        if ([c.domain containsString:@"music.163.com"] && c.value.length)
            [parts addObject:[NSString stringWithFormat:@"%@=%@", c.name, c.value]];
    }
    if (!parts.count) return kCookieSeed;
    [parts addObject:@"os=ios"];
    [parts addObject:@"appver=9.1.60"];
    return [parts componentsJoinedByString:@"; "];
}

#pragma mark - eapi 请求

- (void)postEapi:(NSString *)path
          params:(NSDictionary *)params
            done:(void (^)(id _Nullable json, NSError * _Nullable err))done {
    NSData *jd = [NSJSONSerialization dataWithJSONObject:params ?: @{} options:0 error:nil];
    NSString *text = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
    if (!text) {
        if (done) done(nil, [NSError errorWithDomain:@"LLLVIP" code:-1 userInfo:nil]);
        return;
    }

    /* eapi 报文格式：path-36cd479b6b5-json-36cd479b6b5-md5("nobody"+path+"use"+json+"md5forencrypt") */
    NSString *digest = LLLMD5Hex([NSString stringWithFormat:@"nobody%@use%@md5forencrypt", path, text]);
    NSString *payload = [NSString stringWithFormat:@"%@-36cd479b6b5-%@-36cd479b6b5-%@", path, text, digest];

    NSData *enc = LLLAESECB([payload dataUsingEncoding:NSUTF8StringEncoding], kEapiKey);
    if (!enc.length) {
        if (done) done(nil, [NSError errorWithDomain:@"LLLVIP" code:-2 userInfo:nil]);
        return;
    }

    NSMutableString *hex = [NSMutableString stringWithCapacity:enc.length * 2];
    const uint8_t *p = enc.bytes;
    for (NSUInteger i = 0; i < enc.length; i++) [hex appendFormat:@"%02X", p[i]];

    NSString *urlStr = [NSString stringWithFormat:@"%@%@", kEapiHost, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    [req setValue:[self cookieHeader] forHTTPHeaderField:@"Cookie"];
    req.HTTPBody = [[NSString stringWithFormat:@"params=%@", hex] dataUsingEncoding:NSUTF8StringEncoding];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (done) done(nil, err); return; }
        if (!data.length) {
            if (done) done(nil, [NSError errorWithDomain:@"LLLVIP" code:-3 userInfo:nil]);
            return;
        }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(je ? nil : obj, je);
    }] resume];
}

- (void)getPlain:(NSString *)path
          params:(NSDictionary<NSString *, NSString *> *)params
            done:(void (^)(id _Nullable json, NSError * _Nullable err))done {
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
    if (!u) { if (done) done(nil, nil); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    [req setValue:[self cookieHeader] forHTTPHeaderField:@"Cookie"];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data.length) { if (done) done(nil, err); return; }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(je ? nil : obj, je);
    }] resume];
}

#pragma mark - 地址探测

/// HEAD 一遍：只有 200/206 + audio 才算能播，302→403 的假地址直接扔掉
- (void)probeURL:(NSURL *)u done:(void (^)(BOOL ok))done {
    if (!u) { if (done) done(NO); return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 8;
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];

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

- (NSURL *)urlFromEapiResult:(id)json {
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    NSArray *data = json[@"data"];
    if (![data isKindOfClass:NSArray.class] || data.count == 0) return nil;
    NSDictionary *d0 = data.firstObject;
    if (![d0 isKindOfClass:NSDictionary.class]) return nil;
    id u = d0[@"url"];
    if (![u isKindOfClass:NSString.class] || [u length] < 10) return nil;
    NSURL *url = [NSURL URLWithString:u];
    /* 网易偶尔给 http:// 的裸地址，AVPlayer 在 ATS 下会拒，强制升级 */
    if ([url.scheme isEqualToString:@"http"]) {
        NSString *s = [u stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
        url = [NSURL URLWithString:s] ?: url;
    }
    return url;
}

#pragma mark - 取流主流程

- (void)resolveStreamURL:(NSNumber *)songID
                duration:(NSTimeInterval)duration
                    done:(void (^)(NSURL * _Nullable, NSString * _Nullable))done {
    if (!songID) { if (done) done(nil, @"没有歌曲 ID"); return; }

    NSString *ids = [NSString stringWithFormat:@"[%@]", songID.stringValue];
    __weak typeof(self) w = self;

    const int kLevelCount = 2;
    NSArray<NSString *> *levels = @[ @"exhigh", @"lossless" ];

    void (^tryPlayerV1)(int) = ^(int li) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (li >= kLevelCount) { [s tryDownloadV1:songID ids:ids duration:duration done:done]; return; }

        NSDictionary *p = @{
            @"ids"         : ids,
            @"level"       : levels[li],
            @"encodeType"  : @"flac",
            @"header"      : @"{\"os\":\"ios\",\"appver\":\"9.1.60\"}",
        };
        [s postEapi:@"/api/song/enhance/player/url/v1" params:p done:^(id json, NSError *err) {
            NSURL *u = [s urlFromEapiResult:json];
            if (!u) { tryPlayerV1(li + 1); return; }
            [s probeURL:u done:^(BOOL ok) {
                if (ok) { if (done) done(u, nil); }
                else    { tryPlayerV1(li + 1); }
            }];
        }];
    };
    tryPlayerV1(0);
}

- (void)tryDownloadV1:(NSNumber *)songID
                  ids:(NSString *)ids
             duration:(NSTimeInterval)duration
                 done:(void (^)(NSURL * _Nullable, NSString * _Nullable))done {
    __weak typeof(self) w = self;
    NSDictionary *p = @{
        @"id"        : songID.stringValue,
        @"br"        : @"320000",
        @"level"     : @"exhigh",
        @"header"    : @"{\"os\":\"ios\",\"appver\":\"9.1.60\"}",
    };
    [self postEapi:@"/api/song/enhance/download/url/v1" params:p done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSURL *u = [s urlFromEapiResult:json];
        if (!u) { [s tryPlainPlayer:songID ids:ids duration:duration done:done]; return; }
        [s probeURL:u done:^(BOOL ok) {
            if (ok) { if (done) done(u, nil); }
            else    { [s tryPlainPlayer:songID ids:ids duration:duration done:done]; }
        }];
    }];
}

- (void)tryPlainPlayer:(NSNumber *)songID
                   ids:(NSString *)ids
              duration:(NSTimeInterval)duration
                  done:(void (^)(NSURL * _Nullable, NSString * _Nullable))done {
    __weak typeof(self) w = self;
    /* 老明文通道：没登录也能出免费曲，会员曲会返回 url=null */
    [self getPlain:@"/api/song/enhance/player/url"
            params:@{ @"ids" : ids, @"br" : @"320000" }
              done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSURL *u = [s urlFromEapiResult:json];
        if (!u) { [s tryOuter:songID done:done]; return; }
        [s probeURL:u done:^(BOOL ok) {
            if (ok) { if (done) done(u, nil); }
            else    { [s tryOuter:songID done:done]; }
        }];
    }];
}

- (void)tryOuter:(NSNumber *)songID done:(void (^)(NSURL * _Nullable, NSString * _Nullable))done {
    NSString *outer = [NSString stringWithFormat:@"%@/song/media/outer/url?id=%@.mp3", kBase, songID];
    NSURL *u = [NSURL URLWithString:outer];
    __weak typeof(self) w = self;
    [self probeURL:u done:^(BOOL ok) {
        __strong typeof(w) s = w;
        if (!ok) {
            if (done) done(nil, @"这首没有可用音源（版权下架或接口调整）");
            return;
        }
        (void)s;
        if (done) done(u, nil);
    }];
}

#pragma mark - 封面

- (NSString *)cachePathForURL:(NSString *)urlString {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [docs stringByAppendingPathComponent:@"LLL/artwork"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    unsigned char out[CC_SHA1_DIGEST_LENGTH];
    NSData *d = [urlString dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA1(d.bytes, (CC_LONG)d.length, out);
    NSMutableString *name = [NSMutableString stringWithCapacity:40];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [name appendFormat:@"%02x", out[i]];
    return [dir stringByAppendingPathComponent:name];
}

- (UIImage *)cachedArtwork:(NSString *)urlString {
    if (!urlString.length) return nil;
    UIImage *mem = [_artCache objectForKey:urlString];
    if (mem) return mem;

    NSString *path = [self cachePathForURL:urlString];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length > 32) {
        UIImage *img = [UIImage imageWithData:data];
        if (img) {
            [_artCache setObject:img forKey:urlString];
            return img;
        }
    }
    return nil;
}

- (void)artworkFor:(NSString *)urlString done:(void (^)(UIImage * _Nullable))done {
    if (!urlString.length) { if (done) done(nil); return; }

    UIImage *hit = [self cachedArtwork:urlString];
    if (hit) { if (done) done(hit); return; }

    @synchronized (self) {
        NSMutableArray *waiters = _pendingArt[urlString];
        if (waiters) {
            /* 同一张图只下载一次，后面排队的等结果 —— 列表滚动时不至于把带宽打满 */
            __weak typeof(self) w = self;
            void (^cb)(UIImage *) = [done copy];
            [waiters addObject:[cb copy]];
            (void)w;
            return;
        }
        _pendingArt[urlString] = [NSMutableArray arrayWithObject:[done copy]];
    }

    __weak typeof(self) w = self;
    NSURL *u = [NSURL URLWithString:urlString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    req.timeoutInterval = 12;

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        UIImage *img = (data.length > 32) ? [UIImage imageWithData:data] : nil;
        if (img) {
            [s.artCache setObject:img forKey:urlString];
            [data writeToFile:[s cachePathForURL:urlString] atomically:YES];
        }

        NSMutableArray *waiters = nil;
        @synchronized (s) {
            waiters = s.pendingArt[urlString];
            [s.pendingArt removeObjectForKey:urlString];
        }
        for (void (^cb)(UIImage *) in [waiters copy]) {
            if (cb) cb(img);
        }
    }] resume];
}

- (void)clearArtworkCache {
    [_artCache removeAllObjects];
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [docs stringByAppendingPathComponent:@"LLL/artwork"];
    [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
}

#pragma mark - VIP 标记

- (void)annotateVIPStatus:(NSArray<NSDictionary *> *)songs
                     done:(void (^)(NSArray<NSDictionary *> *))done {
    if (!songs.count) { if (done) done(songs ?: @[]); return; }

    /* 只批量问一次，别一首一个请求 */
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    NSUInteger limit = MIN(songs.count, (NSUInteger)100);
    for (NSUInteger i = 0; i < limit; i++) {
        NSNumber *sid = songs[i][@"id"];
        if (sid) [ids addObject:sid.stringValue];
    }
    if (!ids.count) { if (done) done(songs); return; }

    NSString *idList = [NSString stringWithFormat:@"[%@]", [ids componentsJoinedByString:@","]];
    __weak typeof(self) w = self;
    NSDictionary *p = @{ @"ids" : idList, @"level" : @"exhigh" };

    [self postEapi:@"/api/song/enhance/player/url/v1" params:p done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (![json isKindOfClass:NSDictionary.class] || ![json[@"data"] isKindOfClass:NSArray.class]) {
            if (done) done(songs);
            return;
        }
        NSMutableDictionary<NSString *, NSNumber *> *map = [NSMutableDictionary dictionary];
        for (NSDictionary *d in json[@"data"]) {
            if (![d isKindOfClass:NSDictionary.class]) continue;
            NSString *key = [d[@"id"] description];
            id url = d[@"url"];
            BOOL ok = ([url isKindOfClass:NSString.class] && [url length] > 10);
            if (key) map[key] = @(ok);
        }

        NSMutableArray *out = [NSMutableArray arrayWithCapacity:songs.count];
        for (NSDictionary *sg in songs) {
            NSMutableDictionary *m = [sg mutableCopy];
            NSString *key = [sg[@"id"] description];
            NSNumber *v = key ? map[key] : nil;
            if (v) m[@"playable"] = v;
            [out addObject:m];
        }
        if (done) done(out);
    }];
}

@end
