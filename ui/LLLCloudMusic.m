//
//  LLLCloudMusic.m
//
//  接口分两类：
//    1) 明文 api/*：扫码 unikey、搜索、歌单、取流 —— 直接 GET，带 Referer 就行
//    2) weapi：手机号登录必须走加密（明文 /api/login/cellphone 现在返回 401 ENC）
//       params = base64(AES128-CBC(json, 随机16位, iv=0102030405060708))
//       encSecKey = hex(RSA_raw(reverse(随机16位))) —— 裸 RSA，所以走 SecKey 的 Raw 算法
//

#import "LLLCloudMusic.h"
#import "BaseComponents.h"
#import <CoreImage/CoreImage.h>
#import <CommonCrypto/CommonDigest.h>
#import <stdio.h>
#import <stdlib.h>
#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>

/* 扫码类型：3 = PC 客户端码（默认），1 = 网页/手机码（兜底） */
static NSInteger gQRType = 3;

static NSString * const kBase = @"https://music.163.com";
static NSString * const kUA   = @"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) "
                                @"AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";
/* 网易按客户端识别：网页 UA 打 /api/login/* 直接 401 无权限访问. ENC。
   实测这对 UA+cookie 能拿到正常业务码（503 验证码错误 / 801 等待扫码）。 */
static NSString * const kClientUA = @"NeteaseMusic/9.1.60.240711141503(8009060);"
                                    @"Dalvik/2.1.0 (Linux; U; Android 11)";
static NSString * const kClientCookie = @"os=ios; appver=9.1.60";
static NSString * const kIV   = @"0102030405060708";
static NSString * const kRsaN = @"00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b7251523"
                                @"ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c9387011"
                                @"4af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741"
                                @"d546b8e289dc6935b3ece0462db0a22b8e7";
static NSString * const kRsaE = @"010001";

#pragma mark - 小工具

static NSString *LLLMD5Hex(NSString *s) {
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char out[CC_MD5_DIGEST_LENGTH];
    CC_MD5(d.bytes, (CC_LONG)d.length, out);
    NSMutableString *r = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [r appendFormat:@"%02x", out[i]];
    return r;
}

static NSString *LLLHexStr(NSData *d) {
    const uint8_t *p = d.bytes;
    NSMutableString *s = [NSMutableString stringWithCapacity:d.length * 2];
    for (NSUInteger i = 0; i < d.length; i++) [s appendFormat:@"%02x", p[i]];
    return s;
}

static NSData *LLLDataFromHex(NSString *hex) {
    NSMutableData *d = [NSMutableData data];
    NSUInteger n = hex.length / 2;
    for (NSUInteger i = 0; i < n; i++) {
        unsigned int b = 0;
        sscanf([[hex substringWithRange:NSMakeRange(i * 2, 2)] UTF8String], "%x", &b);
        uint8_t v = (uint8_t)b;
        [d appendBytes:&v length:1];
    }
    return d;
}

/* RFC3986 严格编码：base64 里的 + / = 必须转义，
   否则表单解码把 + 还原成空格 → params 解不出来，手机号登录必挂 */
static NSString *LLLFormEncode(NSString *s) {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *m = [NSMutableCharacterSet alphanumericCharacterSet];
        [m addCharactersInString:@"-._~"];
        allowed = [m copy];
    });
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

/* URL query 值：不允许裸 & = ? # + / */
static NSString *LLLQueryEncode(NSString *s) {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *m = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [m removeCharactersInString:@"+&=?#/"];
        allowed = [m copy];
    });
    return [s stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

static NSData *LLLAES128(NSData *plain, NSString *key) {
    NSData *k = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *iv = [kIV dataUsingEncoding:NSUTF8StringEncoding];
    if (k.length != 16 || iv.length != 16) return nil;

    size_t outLen = plain.length + kCCBlockSizeAES128;
    void *out = malloc(outLen);
    if (!out) return nil;
    size_t moved = 0;

    CCCryptorStatus st = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                 k.bytes, kCCKeySizeAES128, iv.bytes,
                                 plain.bytes, plain.length, out, outLen, &moved);
    NSData *res = (st == kCCSuccess) ? [NSData dataWithBytes:out length:moved] : nil;
    free(out);
    return res;
}

/* eapi：AES-128-ECB，固定 key e82ckenh8dichen8 */
static NSData *LLLAESECB(NSData *plain) {
    static NSData *k;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ k = [@"e82ckenh8dichen8" dataUsingEncoding:NSUTF8StringEncoding]; });
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

static NSMutableData *LLLTLV(uint8_t tag, NSData *val) {
    NSMutableData *d = [NSMutableData data];
    [d appendBytes:&tag length:1];
    NSUInteger n = val.length;
    if (n < 0x80) {
        uint8_t b = (uint8_t)n;
        [d appendBytes:&b length:1];
    } else if (n <= 0xFF) {
        uint8_t b[2] = { 0x81, (uint8_t)n };
        [d appendBytes:b length:2];
    } else {
        uint8_t b[3] = { 0x82, (uint8_t)(n >> 8), (uint8_t)(n & 0xFF) };
        [d appendBytes:b length:3];
    }
    [d appendData:val];
    return d;
}

static NSData *LLLDERInt(NSData *raw) {
    NSUInteger i = 0;
    const uint8_t *p = raw.bytes;
    while (i + 1 < raw.length && p[i] == 0) i++;
    NSMutableData *v = [NSMutableData dataWithBytes:p + i length:raw.length - i];
    if (v.length && (((const uint8_t *)v.bytes)[0] & 0x80)) {
        uint8_t zero = 0;
        [v replaceBytesInRange:NSMakeRange(0, 0) withBytes:&zero length:1];
    }
    return LLLTLV(0x02, v);
}

static SecKeyRef LLLRSAPublicKey(void) {
    static SecKeyRef key;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableData *rsa = [NSMutableData data];
        [rsa appendData:LLLDERInt(LLLDataFromHex(kRsaN))];
        [rsa appendData:LLLDERInt(LLLDataFromHex(kRsaE))];
        NSData *seq = LLLTLV(0x30, rsa);

        static const uint8_t oidBytes[] = { 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01 };
        NSData *oid = [NSData dataWithBytes:oidBytes length:sizeof(oidBytes)];
        static const uint8_t nullBytes[] = { 0x05, 0x00 };
        NSData *nul = [NSData dataWithBytes:nullBytes length:2];

        NSMutableData *alg = [NSMutableData data];
        [alg appendData:oid];
        [alg appendData:nul];
        NSData *algSeq = LLLTLV(0x30, alg);

        NSMutableData *bit = [NSMutableData data];
        uint8_t zero = 0;
        [bit appendBytes:&zero length:1];
        [bit appendData:seq];

        NSMutableData *spki = [NSMutableData data];
        [spki appendData:algSeq];
        [spki appendData:LLLTLV(0x03, bit)];
        NSData *spkiSeq = LLLTLV(0x30, spki);

        NSDictionary *attrs = @{
            (id)kSecAttrKeyType       : (id)kSecAttrKeyTypeRSA,
            (id)kSecAttrKeyClass      : (id)kSecAttrKeyClassPublic,
            (id)kSecAttrKeySizeInBits : @1024,
        };
        CFErrorRef err = NULL;
        key = SecKeyCreateWithData((__bridge CFDataRef)spkiSeq, (__bridge CFDictionaryRef)attrs, &err);
        if (!key) {
            /* SPKI 被拒时退回 PKCS#1（RSAPublicKey SEQUENCE） */
            key = SecKeyCreateWithData((__bridge CFDataRef)seq, (__bridge CFDictionaryRef)attrs, &err);
        }
        if (!key) lllLog(@"网易云 RSA 公钥构造失败: %@", err);
    });
    return key;
}

/// 裸 RSA 加密 16 位随机串 → 128 字节 → hex
static NSString *LLLEncSecKey(NSString *secret) {
    SecKeyRef key = LLLRSAPublicKey();
    if (!key) return nil;

    NSData *raw = [secret dataUsingEncoding:NSUTF8StringEncoding];
    if (raw.length == 0 || raw.length > 128) return nil;

    NSMutableData *block = [NSMutableData dataWithLength:128];
    uint8_t *p = block.mutableBytes;
    const uint8_t *src = raw.bytes;
    for (NSUInteger i = 0; i < raw.length; i++) p[128 - 1 - i] = src[i];

    CFErrorRef err = NULL;
    CFDataRef out = SecKeyCreateEncryptedData(key, kSecKeyAlgorithmRSAEncryptionRaw,
                                              (__bridge CFDataRef)block, &err);
    if (!out) {
        lllLog(@"网易云 encSecKey 失败: %@", err);
        return nil;
    }
    NSString *hex = LLLHexStr((__bridge NSData *)out);
    CFRelease(out);
    return hex;
}

static NSString *LLLRandomKey(void) {
    NSString *pool = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:16];
    for (int i = 0; i < 16; i++) {
        uint32_t idx = arc4random_uniform((uint32_t)pool.length);
        [s appendFormat:@"%C", [pool characterAtIndex:idx]];
    }
    return s;
}

#pragma mark -

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
- (void)requestQRKey:(NSInteger)type done:(void (^)(NSString *key, NSInteger used))done;
- (void)fetchAccountThen:(void (^)(BOOL ok, NSString *msg))done;
- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
           done:(void (^)(id json, NSError *err))done;
- (void)getClientJSON:(NSString *)path
               params:(NSDictionary<NSString *, NSString *> *)params
                 done:(void (^)(id json, NSError *err))done;
- (void)postEapi:(NSString *)path
          params:(NSDictionary *)params
            done:(void (^)(id json, NSError *err))done;
- (void)postWeapi:(NSString *)path
           params:(NSDictionary *)params
             done:(void (^)(id json, NSError *err))done;
- (NSArray<NSDictionary *> *)mapTracks:(NSArray *)tracks;
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
            @"User-Agent" : kUA,
            @"Referer"    : kBase,
            @"Origin"     : kBase,
        };
        cfg.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        cfg.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        cfg.HTTPShouldSetCookies = YES;
        cfg.timeoutIntervalForRequest = 15;
        _session = [NSURLSession sessionWithConfiguration:cfg];
        [NSHTTPCookieStorage sharedHTTPCookieStorage].cookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
        _loggedIn = [self hasCookie];
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

#pragma mark - 请求

- (void)getJSON:(NSString *)path
         params:(NSDictionary<NSString *, NSString *> *)params
           done:(void (^)(id json, NSError *err))done {
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@", kBase, path];
    if (params.count) {
        [url appendString:@"?"];
        __block NSUInteger i = 0;
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            if (i++) [url appendString:@"&"];
            [url appendFormat:@"%@=%@", LLLQueryEncode(k), LLLQueryEncode(v)];
        }];
    }

    NSURL *finalURL = [NSURL URLWithString:url];
    if (!finalURL) {
        if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-1 userInfo:nil]);
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:finalURL];
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data.length) { if (done) done(nil, err); return; }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(obj, je);
    }] resume];
}

- (void)postEapi:(NSString *)path
          params:(NSDictionary *)params
            done:(void (^)(id json, NSError *err))done {
    NSData *jd = [NSJSONSerialization dataWithJSONObject:params ?: @{} options:0 error:nil];
    NSString *text = [[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding];
    if (!text) { if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-4 userInfo:nil]); return; }

    NSString *digestSrc = [NSString stringWithFormat:@"nobody%@use%@md5forencrypt", path, text];
    NSString *digest = LLLMD5Hex(digestSrc);
    NSString *payload = [NSString stringWithFormat:@"%@-36cd479b6b5-%@-36cd479b6b5-%@", path, text, digest];

    NSData *enc = LLLAESECB([payload dataUsingEncoding:NSUTF8StringEncoding]);
    if (!enc.length) { if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-5 userInfo:nil]); return; }

    NSMutableString *hex = [NSMutableString stringWithCapacity:enc.length * 2];
    const uint8_t *p = enc.bytes;
    for (NSUInteger i = 0; i < enc.length; i++) [hex appendFormat:@"%02X", p[i]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://interface.music.163.com%@", path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"NeteaseMusic/9.1.60.240711141503(8009060);Dalvik/2.1.0 (Linux; U; Android 11)"
           forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    [req setValue:@"os=ios; appver=9.1.60" forHTTPHeaderField:@"Cookie"];
    req.HTTPBody = [[NSString stringWithFormat:@"params=%@", hex] dataUsingEncoding:NSUTF8StringEncoding];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (done) done(nil, err); return; }
        if (!data.length) {
            if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-6 userInfo:nil]);
            return;
        }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(obj, je);
    }] resume];
}

/* 客户端 UA 的 GET：扫码 / 短信这些接口用网页 UA 会被判无权限 */
- (void)getClientJSON:(NSString *)path
               params:(NSDictionary<NSString *, NSString *> *)params
                 done:(void (^)(id json, NSError *err))done {
    NSMutableString *url = [NSMutableString stringWithFormat:@"%@%@", kBase, path];
    if (params.count) {
        [url appendString:@"?"];
        __block NSUInteger i = 0;
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            if (i++) [url appendString:@"&"];
            [url appendFormat:@"%@=%@", LLLQueryEncode(k), LLLQueryEncode(v)];
        }];
    }
    NSURL *u = [NSURL URLWithString:url];
    if (!u) { if (done) done(nil, nil); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:kClientUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    if (![self hasCookie]) [req setValue:kClientCookie forHTTPHeaderField:@"Cookie"];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (done) done(nil, err); return; }
        if (!data.length) { if (done) done(nil, nil); return; }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(obj, je);
    }] resume];
}

- (void)postWeapi:(NSString *)path
           params:(NSDictionary *)params
             done:(void (^)(id json, NSError *err))done {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params ?: @{} options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (!json) { if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-2 userInfo:nil]); return; }

    NSString *secret = LLLRandomKey();
    NSData *aes = LLLAES128([json dataUsingEncoding:NSUTF8StringEncoding], secret);
    NSString *enc = LLLEncSecKey(secret);
    if (!aes || !enc) {
        if (done) done(nil, [NSError errorWithDomain:@"LLLCloud" code:-3 userInfo:nil]);
        return;
    }

    NSString *paramsB64 = [aes base64EncodedStringWithOptions:0];
    NSString *bodyStr = [NSString stringWithFormat:@"params=%@&encSecKey=%@",
                         LLLFormEncode(paramsB64), LLLFormEncode(enc)];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?csrf_token=", kBase, path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    req.HTTPBody = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data.length) { if (done) done(nil, err); return; }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
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

- (void)cancelLogin {
    [_pollTimer invalidate];
    _pollTimer = nil;
    _pollCount = 0;
    _uniKey = nil;
}

/* 要 unikey：3 = PC 客户端码，1 = 网页/手机码。type=3 拿不到就自动退 1 */
- (void)requestQRKey:(NSInteger)type done:(void (^)(NSString *key, NSInteger used))done {
    __weak typeof(self) w = self;
    [self getClientJSON:@"/api/login/qrcode/unikey"
           params:@{ @"type" : [NSString stringWithFormat:@"%ld", (long)type] }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSString *key = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            key = json[@"unikey"];
            if (!key) key = json[@"key"];
        }
        if (!key.length && type == 3) { [s requestQRKey:1 done:done]; return; }
        if (done) done(key, type);
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
    [self getClientJSON:@"/api/login/qrcode/client/login"
           params:@{ @"key" : _uniKey, @"type" : [NSString stringWithFormat:@"%ld", (long)gQRType] }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSInteger code = 800;
        NSString *msg = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            code = [json[@"code"] integerValue];
            msg = json[@"message"];
        }

        /* 实测语义（2026）：800 二维码不存在/过期，801 等待扫码，
           802 已扫码待确认，803 授权成功。旧版把 800/801/802 整体错位了一位，
           所以没扫就显示"已扫码"、一扫码又显示"已取消"。 */
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
            [NSThread sleepForTimeInterval:0.4];
            [s fetchAccountThen:^(BOOL ok, NSString *m) {
                s.loggedIn = ok && [s hasCookie];
                if (s.doneBlock) {
                    s.doneBlock(ok && s.loggedIn,
                                ok ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                                   : (m ?: @"登录失败"));
                }
            }];
        } else {
            if (s.progressBlock) s.progressBlock(nil, msg.length ? msg : @"等待中…");
        }
    }];
}

#pragma mark - 手机号 / Cookie

/* 明文表单 POST（验证码登录走这条，eapi/weapi 都要求 ursToken，密码登录已被关闭） */
- (void)postForm:(NSString *)path body:(NSString *)body done:(void (^)(id json, NSError *err))done {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kBase, path]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [req setValue:kClientUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];
    if (![self hasCookie]) [req setValue:kClientCookie forHTTPHeaderField:@"Cookie"];
    req.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];

    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) { if (done) done(nil, err); return; }
        if (!data.length) { if (done) done(nil, nil); return; }
        NSError *je = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&je];
        if (done) done(obj, je);
    }] resume];
}

- (void)requestSMSCode:(NSString *)phone done:(void (^)(BOOL, NSString *))done {
    NSString *p = [phone stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (p.length < 6) { if (done) done(NO, @"手机号没填完"); return; }

    __weak typeof(self) w = self;
    [self getClientJSON:@"/api/sms/captcha/sent"
           params:@{ @"cellphone" : p, @"ctcode" : @"86" }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
        NSString *msg = [json isKindOfClass:NSDictionary.class] ? (json[@"message"] ?: json[@"msg"]) : nil;
        if (err) msg = @"网络错误";
        BOOL ok = (code == 200);
        if (done) done(ok, ok ? @"验证码已发送" : (msg.length ? msg : @"发送失败"));
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

    NSString *body = [NSString stringWithFormat:@"phone=%@&countrycode=86&captcha=%@&rememberLogin=true",
                      LLLFormEncode(p), LLLFormEncode(c)];
    __weak typeof(self) w = self;
    [self postForm:@"/api/login/cellphone" body:body done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSInteger code = [json isKindOfClass:NSDictionary.class] ? [json[@"code"] integerValue] : -1;
        NSString *msg = [json isKindOfClass:NSDictionary.class] ? (json[@"message"] ?: json[@"msg"]) : nil;
        lllLog(@"网易云 验证码登录 code=%ld msg=%@", (long)code, msg ?: @"");
        if (code != 200) {
            if (err) msg = [NSString stringWithFormat:@"网络错误：%@", err.localizedDescription ?: @"连接失败"];
            if (!msg.length) msg = @"登录失败";
            if (done) done(NO, msg);
            return;
        }
        [s fetchAccountThen:^(BOOL ok, NSString *m) {
            s.loggedIn = ok && [s hasCookie];
            if (done) done(s.loggedIn, s.loggedIn
                            ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                            : (m ?: @"登录失败"));
        }];
    }];
}

- (void)loginWithCookie:(NSString *)rawCookie
             completion:(void (^)(BOOL, NSString *))done {
    NSString *raw = [rawCookie stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!raw.length) { if (done) done(NO, @"Cookie 是空的"); return; }

    NSArray<NSString *> *parts = [raw componentsSeparatedByString:@";"];
    NSUInteger added = 0;
    for (NSString *kv in parts) {
        NSRange eq = [kv rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        NSString *name = [[kv substringToIndex:eq.location]
                          stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *val = [[kv substringFromIndex:eq.location + 1]
                         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!name.length || !val.length) continue;

        NSDictionary *props = @{
            NSHTTPCookieName    : name,
            NSHTTPCookieValue   : val,
            NSHTTPCookieDomain  : @"music.163.com",
            NSHTTPCookiePath    : @"/",
            NSHTTPCookieSecure  : @"TRUE",
        };
        NSHTTPCookie *c = [NSHTTPCookie cookieWithProperties:props];
        if (c) { [NSHTTPCookieStorage.sharedHTTPCookieStorage setCookie:c]; added++; }
    }

    if (!added) { if (done) done(NO, @"没解析出有效的 Cookie"); return; }

    __weak typeof(self) w = self;
    [self fetchAccountThen:^(BOOL ok, NSString *m) {
        __strong typeof(w) s = w;
        if (!s) return;
        s.loggedIn = ok && [s hasCookie];
        if (done) done(s.loggedIn,
                       s.loggedIn ? [NSString stringWithFormat:@"登录成功：%@", s.nickname ?: @"网易云用户"]
                                  : (m ?: @"Cookie 已失效，重新抓一个"));
    }];
}

- (void)fetchAccountThen:(void (^)(BOOL, NSString *))done {
    __weak typeof(self) w = self;
    [self getJSON:@"/api/nuser/account/get" params:nil done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        BOOL ok = NO;
        if ([json isKindOfClass:NSDictionary.class]) {
            NSDictionary *profile = json[@"profile"];
            if ([profile isKindOfClass:NSDictionary.class]) {
                s.nickname = profile[@"nickname"];
                s.uid = [profile[@"userId"] longLongValue];
                ok = (s.uid != 0);
            }
        }
        /* 以前这里 ok||hasCookie 会把"cookie 在但已失效"判成登录成功 → 假成功 */
        if (done) done(ok, ok ? nil : @"账号信息拿不到，Cookie 可能已失效");
    }];
}

#pragma mark - 歌单 / 搜索

- (NSArray<NSDictionary *> *)mapTracks:(NSArray *)tracks {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *t in tracks) {
        if (![t isKindOfClass:NSDictionary.class]) continue;
        NSString *name = t[@"name"];
        NSString *artist = @"";
        NSString *pic = nil;
        if ([t[@"al"] isKindOfClass:NSDictionary.class]) pic = t[@"al"][@"picUrl"];
        if (!pic && [t[@"album"] isKindOfClass:NSDictionary.class]) pic = t[@"album"][@"picUrl"];

        NSTimeInterval dur = [t[@"dt"] doubleValue] / 1000.0;
        if (dur <= 0) dur = [t[@"duration"] doubleValue] / 1000.0;

        NSArray *ar = t[@"ar"] ?: t[@"artists"];
        if ([ar isKindOfClass:NSArray.class] && ar.count) {
            NSDictionary *a0 = ar.firstObject;
            if ([a0 isKindOfClass:NSDictionary.class]) artist = a0[@"name"] ?: @"";
        }
        if (![pic isKindOfClass:NSString.class]) pic = nil;

        [out addObject:@{
            @"id"     : t[@"id"] ?: @0,
            @"name"   : name ?: @"未知",
            @"artist" : artist,
            @"pic"    : pic ?: @"",
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

        [s getJSON:@"/api/user/playlist"
            params:@{ @"uid" : [NSString stringWithFormat:@"%lld", s.uid],
                      @"limit" : @"1000", @"offset" : @"0" }
              done:^(id json, NSError *err) {
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

- (void)loadPlaylist:(NSNumber *)pid
                done:(void (^)(NSArray<NSDictionary *> *, NSString *))done {
    if (!pid) { if (done) done(nil, @"没有歌单 ID"); return; }

    __weak typeof(self) w = self;
    [self getJSON:@"/api/v6/playlist/detail"
           params:@{ @"id" : pid.stringValue, @"n" : @"1000" }
             done:^(id json, NSError *err) {
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
    [self getJSON:@"/api/search/get"
           params:@{ @"s" : kw, @"type" : @"1", @"limit" : @"30", @"offset" : @"0" }
             done:^(id json, NSError *err) {
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

#pragma mark - 取流 / 封面

- (void)resolvePlayURL:(NSNumber *)songID done:(void (^)(NSURL *, NSString *))done {
    if (!songID) { if (done) done(nil, @"没有歌曲 ID"); return; }

    NSString *ids = [NSString stringWithFormat:@"[%@]", songID.stringValue];
    __weak typeof(self) w = self;
    [self getJSON:@"/api/song/enhance/player/url"
           params:@{ @"ids" : ids, @"br" : @"320000" }
             done:^(id json, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        NSString *u = nil;
        if ([json isKindOfClass:NSDictionary.class]) {
            NSArray *data = json[@"data"];
            if ([data isKindOfClass:NSArray.class] && data.count) {
                NSDictionary *d0 = data.firstObject;
                if ([d0 isKindOfClass:NSDictionary.class] && [d0[@"url"] isKindOfClass:NSString.class])
                    u = d0[@"url"];
            }
        }

        /* 【取流修复】接口给的是 302 到一个 403 的假地址时，AVPlayer 会静默不出声。
           先把候选地址 HEAD 一遍（音频流会给 206/200 + audio/mpeg），能播才算数。 */
        NSMutableArray<NSURL *> *cands = [NSMutableArray array];
        NSURL *apiURL = u.length ? [NSURL URLWithString:u] : nil;
        if (apiURL) [cands addObject:apiURL];
        NSURL *outer = [NSURL URLWithString:
                        [NSString stringWithFormat:@"%@/song/media/outer/url?id=%@.mp3", kBase, songID]];
        if (outer) [cands addObject:outer];

        [s probeCandidates:cands
                     index:0
                      done:^(NSURL *hit) {
            if (hit) { if (done) done(hit, nil); return; }
            if (done) done(nil, @"这首歌没有可用播放地址（版权或会员限制）");
        }];
    }];
}

- (void)probeCandidates:(NSArray<NSURL *> *)cands
                  index:(NSUInteger)idx
                   done:(void (^)(NSURL *hit))done {
    if (idx >= cands.count) { if (done) done(nil); return; }

    NSURL *u = cands[idx];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    req.HTTPMethod = @"HEAD";
    req.timeoutInterval = 8;
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [req setValue:kBase forHTTPHeaderField:@"Referer"];

    __weak typeof(self) w = self;
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        __strong typeof(w) s = w;
        if (!s) return;

        BOOL ok = NO;
        if (!err && [resp isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *h = (NSHTTPURLResponse *)resp;
            NSString *ctype = [[h allHeaderFields][@"Content-Type"] lowercaseString] ?: @"";
            long long len = h.expectedContentLength;
            if ((h.statusCode == 200 || h.statusCode == 206) &&
                (len <= 0 || len > 32 * 1024) &&
                ([ctype containsString:@"audio"] || [ctype containsString:@"octet-stream"] || ctype.length == 0)) {
                ok = YES;
            }
        }
        if (ok) { if (done) done(u); return; }
        [s probeCandidates:cands index:idx + 1 done:done];
    }] resume];
}

- (void)loadArtwork:(NSString *)url done:(void (^)(UIImage *))done {
    if (!url.length) { if (done) done(nil); return; }
    NSURL *u = [NSURL URLWithString:url];
    if (!u) { if (done) done(nil); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:kUA forHTTPHeaderField:@"User-Agent"];
    [[_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        UIImage *img = (data.length > 32) ? [UIImage imageWithData:data] : nil;
        if (done) done(img);
    }] resume];
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
