//
//  LLLZip.m
//

#import "LLLZip.h"
#import "BaseComponents.h"
#import <zlib.h>

static inline uint16_t LLLRd16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static inline uint32_t LLLRd32(const uint8_t *p) {
    return (uint32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24));
}

@implementation LLLZip

+ (NSData *)inflateRaw:(NSData *)src expected:(NSUInteger)expected {
    if (src.length == 0) return [NSData data];

    z_stream st;
    memset(&st, 0, sizeof(st));
    if (inflateInit2(&st, -MAX_WBITS) != Z_OK) return nil;

    NSMutableData *out = [NSMutableData dataWithLength:MAX(expected, (NSUInteger)4096)];
    st.next_in = (Bytef *)src.bytes;
    st.avail_in = (uInt)src.length;

    int rc = Z_OK;
    while (rc != Z_STREAM_END) {
        if (st.total_out >= out.length) [out increaseLengthBy:MAX(expected, (NSUInteger)65536)];
        st.next_out = (Bytef *)out.mutableBytes + st.total_out;
        st.avail_out = (uInt)(out.length - st.total_out);

        rc = inflate(&st, Z_NO_FLUSH);
        if (rc != Z_OK && rc != Z_STREAM_END) { inflateEnd(&st); return nil; }
        if (st.avail_in == 0 && rc != Z_STREAM_END) { inflateEnd(&st); return nil; }
    }

    NSUInteger n = st.total_out;
    inflateEnd(&st);
    [out setLength:n];
    return out;
}

+ (NSArray<NSString *> *)extract:(NSString *)zipPath
                              to:(NSString *)destDir
                           error:(NSString **)err {
    NSData *data = [NSData dataWithContentsOfFile:zipPath];
    if (data.length < 22) {
        if (err) *err = @"压缩包打不开或太小";
        return nil;
    }

    const uint8_t *base = data.bytes;
    NSUInteger len = data.length;

    NSInteger eocd = -1;
    NSUInteger scanFrom = (len > 65557) ? (len - 65557) : 0;
    for (NSInteger i = (NSInteger)len - 22; i >= (NSInteger)scanFrom; i--) {
        if (LLLRd32(base + i) == 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) {
        if (err) *err = @"不是有效的 zip（没找到目录尾）";
        return nil;
    }

    NSUInteger cdCount  = LLLRd16(base + eocd + 10);
    NSUInteger cdOffset = LLLRd32(base + eocd + 16);
    if (cdOffset >= len) {
        if (err) *err = @"zip 目录偏移越界";
        return nil;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:destDir]) {
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSMutableArray<NSString *> *written = [NSMutableArray array];
    NSUInteger p = cdOffset;

    for (NSUInteger i = 0; i < cdCount; i++) {
        if (p + 46 > len || LLLRd32(base + p) != 0x02014b50) break;

        uint16_t method   = LLLRd16(base + p + 10);
        uint32_t compSize = LLLRd32(base + p + 20);
        uint32_t uncompSize = LLLRd32(base + p + 24);
        uint16_t nameLen  = LLLRd16(base + p + 28);
        uint16_t extraLen = LLLRd16(base + p + 30);
        uint16_t cmtLen   = LLLRd16(base + p + 32);
        uint32_t localOff = LLLRd32(base + p + 42);

        if (p + 46 + nameLen > len) break;
        NSString *name = [[NSString alloc] initWithBytes:base + p + 46
                                                  length:nameLen
                                                encoding:NSUTF8StringEncoding];
        if (!name.length) {
            name = [[NSString alloc] initWithBytes:base + p + 46
                                           length:nameLen
                                         encoding:NSISOLatin1StringEncoding];
        }
        p += 46 + nameLen + extraLen + cmtLen;

        if (!name.length) continue;
        if ([name hasPrefix:@"/"] || [name containsString:@".."] || [name containsString:@":"]) continue;

        if ([name hasSuffix:@"/"]) {
            [fm createDirectoryAtPath:[destDir stringByAppendingPathComponent:name]
          withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }

        if (localOff + 30 > len || LLLRd32(base + localOff) != 0x04034b50) continue;
        uint16_t lNameLen  = LLLRd16(base + localOff + 26);
        uint16_t lExtraLen = LLLRd16(base + localOff + 28);
        NSUInteger dataOff = localOff + 30 + lNameLen + lExtraLen;
        if (dataOff + compSize > len) continue;

        NSData *payload = nil;
        NSData *chunk = [data subdataWithRange:NSMakeRange(dataOff, compSize)];
        if (method == 0) payload = chunk;
        else if (method == 8) payload = [self inflateRaw:chunk expected:uncompSize];
        if (!payload) continue;

        NSString *outPath = [destDir stringByAppendingPathComponent:name];
        [fm createDirectoryAtPath:[outPath stringByDeletingLastPathComponent]
      withIntermediateDirectories:YES attributes:nil error:nil];
        if ([payload writeToFile:outPath atomically:YES]) [written addObject:name];
    }

    if (written.count == 0) {
        if (err) *err = @"解出来是空的（压缩方式不支持或包损坏）";
        return nil;
    }
    return written;
}

#pragma mark - 材质包导入

static NSString *LLLCleanPackName(NSString *raw) {
    if (!raw.length) return nil;

    // 去掉 Minecraft 的颜色控制符 §x
    NSMutableString *s = [NSMutableString stringWithCapacity:raw.length];
    unichar prev = 0;
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if (prev == 0xA7) { prev = 0; continue; }
        if (c == 0xA7) { prev = c; continue; }
        [s appendFormat:@"%C", c];
    }

    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"/\\:?%*|\"<>"];
    NSString *flat = [[s componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@"_"];
    flat = [flat stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (flat.length > 64) flat = [flat substringToIndex:64];
    return flat.length ? flat : nil;
}

static NSString *LLLFindManifest(NSString *dir, NSInteger depth) {
    NSString *direct = [dir stringByAppendingPathComponent:@"manifest.json"];
    if ([NSFileManager.defaultManager fileExistsAtPath:direct]) return direct;
    if (depth <= 0) return nil;

    NSArray *items = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *it in items) {
        if ([it hasPrefix:@"."]) continue;
        NSString *full = [dir stringByAppendingPathComponent:it];
        BOOL isDir = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:full isDirectory:&isDir] && isDir) {
            NSString *m = LLLFindManifest(full, depth - 1);
            if (m) return m;
        }
    }
    return nil;
}

+ (NSUInteger)importPendingArchives {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *docs = docsPath();
    NSString *caizhi = caizhiPath();

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    for (NSString *dir in @[ caizhi, docs ]) {
        for (NSString *it in [fm contentsOfDirectoryAtPath:dir error:nil]) {
            NSString *low = it.lowercaseString;
            if ([low hasSuffix:@".zip"] || [low hasSuffix:@".mcpack"] || [low hasSuffix:@".mcaddon"]) {
                [candidates addObject:[dir stringByAppendingPathComponent:it]];
            }
        }
    }
    if (candidates.count == 0) return 0;

    NSString *tmpRoot = [docs stringByAppendingPathComponent:@".lll_unzip"];
    NSUInteger ok = 0;

    for (NSString *zip in candidates) {
        @autoreleasepool {
            NSString *stage = [tmpRoot stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"%u", arc4random()]];
            [fm removeItemAtPath:stage error:nil];

            NSString *err = nil;
            if ([[self extract:zip to:stage error:&err] count] == 0) {
                lllLog(@"ZIP 跳过 %@: %@", zip.lastPathComponent, err ?: @"?");
                [fm removeItemAtPath:stage error:nil];
                continue;
            }

            NSString *manifest = LLLFindManifest(stage, 2);
            NSString *name = nil;
            if (manifest) {
                NSData *d = [NSData dataWithContentsOfFile:manifest];
                id j = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
                if ([j isKindOfClass:NSDictionary.class]) {
                    NSDictionary *h = j[@"header"];
                    if ([h isKindOfClass:NSDictionary.class] && [h[@"name"] isKindOfClass:NSString.class])
                        name = LLLCleanPackName(h[@"name"]);
                }
            }
            if (!name.length) name = LLLCleanPackName(zip.lastPathComponent.stringByDeletingPathExtension);
            if (!name.length) { [fm removeItemAtPath:stage error:nil]; continue; }

            NSString *target = [caizhi stringByAppendingPathComponent:name];
            [fm removeItemAtPath:target error:nil];

            NSString *src = stage;
            if (manifest) {
                NSString *dir = [manifest stringByDeletingLastPathComponent];
                if (![dir isEqualToString:stage]) src = dir;
            }

            NSError *mvErr = nil;
            if ([fm moveItemAtPath:src toPath:target error:&mvErr]) {
                ok++;
                lllLog(@"ZIP 导入: %@", name);
                // 不删用户文件，只归到 .zips 里，避免每次启动重复导入
                NSString *done = [caizhi stringByAppendingPathComponent:@".zips"];
                [fm createDirectoryAtPath:done withIntermediateDirectories:YES attributes:nil error:nil];
                [fm moveItemAtPath:zip
                            toPath:[done stringByAppendingPathComponent:zip.lastPathComponent]
                             error:nil];
            } else {
                lllLog(@"ZIP 导入失败 %@: %@", name, mvErr.localizedDescription);
            }
            [fm removeItemAtPath:stage error:nil];
        }
    }

    [fm removeItemAtPath:tmpRoot error:nil];
    return ok;
}

@end
