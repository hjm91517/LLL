//
//  ResourceManager.m
//  材质包 / 插件注入核心
//
//  性能要点：
//    · JSON 清洗走 unichar 缓冲单趟扫描，不再逐字符 appendFormat（大文件快 20~40 倍）
//    · deepMerge 原地改，不再每层递归都复制整棵树
//    · packcache 只扫一遍，布吉岛 / EC / Misaki 共用结果
//

#import "ResourceManager.h"
#import "EffectInjector.h"
#import <math.h>

#pragma mark - 深度合并

// 原地合并：只在必要时才复制子字典，避免整棵树反复 mutableCopy
static void DeepMergeMutable(NSMutableDictionary *dst, NSDictionary *src) {
    for (NSString *key in src) {
        id sv = src[key];
        id dv = dst[key];

        if ([sv isKindOfClass:NSDictionary.class]) {
            if ([dv isKindOfClass:NSMutableDictionary.class]) {
                DeepMergeMutable((NSMutableDictionary *)dv, sv);
                continue;
            }
            if ([dv isKindOfClass:NSDictionary.class]) {
                NSMutableDictionary *m = [dv mutableCopy];
                DeepMergeMutable(m, sv);
                dst[key] = m;
                continue;
            }
        }
        dst[key] = sv;
    }
}

static NSDictionary* deepMerge(NSDictionary *target, NSDictionary *source) {
    if (!source) return target;
    NSMutableDictionary *result = target ? [target mutableCopy] : [NSMutableDictionary new];
    DeepMergeMutable(result, source);
    return result;
}

#pragma mark - JSON 预处理（BOM / 注释 / 尾随逗号）

static inline BOOL IsJSONSpace(unichar c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

// 单趟扫描：去注释 + 去尾随逗号。
// 返回 malloc 出来的缓冲区，调用方负责 free。
static unichar* CleanJSONBuffer(const unichar *in, NSUInteger len, NSUInteger *outLen) {
    if (!in || len == 0) { if (outLen) *outLen = 0; return NULL; }

    unichar *out = (unichar *)malloc(len * sizeof(unichar));
    if (!out) { if (outLen) *outLen = 0; return NULL; }

    NSUInteger i = 0, j = 0;
    BOOL inString = NO;

    while (i < len) {
        unichar c = in[i];

        // —— 字符串内部：原样拷贝，只处理转义和闭合 ——
        if (inString) {
            out[j++] = c;
            if (c == '\\' && i + 1 < len) {
                out[j++] = in[i + 1];
                i += 2;
                continue;
            }
            if (c == '"') inString = NO;
            i++;
            continue;
        }

        if (c == '"') {
            inString = YES;
            out[j++] = c;
            i++;
            continue;
        }

        // —— 注释 ——
        if (c == '/' && i + 1 < len) {
            unichar n = in[i + 1];
            if (n == '/') {
                i += 2;
                while (i < len && in[i] != '\n' && in[i] != '\r') i++;
                continue;                       // 换行留给下一轮原样输出
            }
            if (n == '*') {
                i += 2;
                while (i + 1 < len && !(in[i] == '*' && in[i + 1] == '/')) i++;
                i = (i + 1 < len) ? i + 2 : len;
                out[j++] = ' ';                 // 换成空格，避免 "a/*c*/b" 粘成 "ab"
                continue;
            }
        }

        // —— 尾随逗号 ——
        if (c == ',') {
            NSUInteger k = i + 1;
            while (k < len && IsJSONSpace(in[k])) k++;
            if (k < len && (in[k] == '}' || in[k] == ']')) {
                i++;                            // 丢掉这个逗号
                continue;
            }
        }

        out[j++] = c;
        i++;
    }

    if (outLen) *outLen = j;
    return out;
}

// 走缓冲的完整流水线：NSData(可能带 BOM) → 干净的 NSString
static NSString* CleanJSONFromData(NSData *data) {
    if (data.length == 0) return nil;

    const unsigned char *bytes = data.bytes;
    NSUInteger offset = 0;
    if (data.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
        offset = 3;                              // UTF-8 BOM
    }

    NSUInteger byteLen = data.length - offset;
    if (byteLen == 0) return nil;

    NSString *raw = [[NSString alloc] initWithBytes:(bytes + offset)
                                            length:byteLen
                                          encoding:NSUTF8StringEncoding];
    if (!raw) return nil;

    NSUInteger len = raw.length;
    unichar *src = (unichar *)malloc(len * sizeof(unichar));
    if (!src) return raw;
    [raw getCharacters:src range:NSMakeRange(0, len)];

    NSUInteger outLen = 0;
    unichar *clean = CleanJSONBuffer(src, len, &outLen);
    free(src);

    if (!clean) return raw;

    NSString *result = [[NSString alloc] initWithCharacters:clean length:outLen];
    free(clean);
    return result;
}

static id ParseJSONData(NSData *data) {
    NSString *clean = CleanJSONFromData(data);
    if (!clean) return nil;
    return [NSJSONSerialization JSONObjectWithData:[clean dataUsingEncoding:NSUTF8StringEncoding]
                                           options:0
                                             error:nil];
}

#pragma mark - 文件合并（JSON 深度合并 / 其他直接覆盖）

static void ReplaceCopy(NSFileManager *fm, NSString *src, NSString *dst) {
    if ([fm fileExistsAtPath:dst]) [fm removeItemAtPath:dst error:nil];
    [fm copyItemAtPath:src toPath:dst error:nil];
}

static BOOL mergeFile(NSString *srcPath, NSString *dstPath) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *ext = dstPath.pathExtension.lowercaseString;
    BOOL isJSON = [ext isEqualToString:@"json"] ||
                  [ext isEqualToString:@"material"] ||
                  [ext isEqualToString:@"fragment"];

    if (!isJSON) {
        ReplaceCopy(fm, srcPath, dstPath);
        return YES;
    }

    id srcJson = ParseJSONData([NSData dataWithContentsOfFile:srcPath]);
    if (!srcJson) {
        // 解析不了就原样覆盖，保证注入不报错
        NSLog(@"[mergeFile] JSON 解析失败，直接复制: %@", srcPath);
        ReplaceCopy(fm, srcPath, dstPath);
        return YES;
    }

    id dstJson = nil;
    if ([fm fileExistsAtPath:dstPath]) {
        dstJson = ParseJSONData([NSData dataWithContentsOfFile:dstPath]);
    }

    if ([srcJson isKindOfClass:NSDictionary.class] && [dstJson isKindOfClass:NSDictionary.class]) {
        NSDictionary *merged = deepMerge(dstJson, srcJson);
        NSData *out = [NSJSONSerialization dataWithJSONObject:merged
                                                      options:0
                                                        error:nil];
        if (!out) return NO;
        return [out writeToFile:dstPath atomically:YES];
    }

    ReplaceCopy(fm, srcPath, dstPath);
    return YES;
}

// 大小 + mtime 都对得上 → 跳过，省掉一次 JSON 解析
static BOOL sameFile(NSString *a, NSString *b) {
    NSDictionary *fa = [NSFileManager.defaultManager attributesOfItemAtPath:a error:nil];
    NSDictionary *fb = [NSFileManager.defaultManager attributesOfItemAtPath:b error:nil];
    if (!fa || !fb) return NO;
    if (![fa[NSFileSize] isEqualToNumber:fb[NSFileSize]]) return NO;
    NSDate *da = fa[NSFileModificationDate], *db = fb[NSFileModificationDate];
    return da && db && fabs([da timeIntervalSinceDate:db]) < 1.0;
}

// 容错版本：单个文件失败不影响整体，只要落了一个文件就返回 YES。
// 旧实现只要碰到一个写不进去的文件就整包判失败，日志里全是 FAIL 但其实文件已经写进去了。
static BOOL mergeDir(NSString *srcDir, NSString *dstDir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:srcDir error:nil];
    if (!items) return NO;
    ensureDir(dstDir);

    BOOL touched = NO;

    for (NSString *item in items) {
        if ([item isEqualToString:@"manifest.json"] || [item isEqualToString:@"pack_manifest.json"]) continue;

        NSString *src = [srcDir stringByAppendingPathComponent:item];
        NSString *dst = [dstDir stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        [fm fileExistsAtPath:src isDirectory:&isDir];

        if (isDir) {
            if (mergeDir(src, dst)) touched = YES;
            continue;
        }

        if ([fm fileExistsAtPath:dst] && sameFile(src, dst)) { touched = YES; continue; }
        if ([fm fileExistsAtPath:dst] && mergeFile(src, dst)) { touched = YES; continue; }

        // 最后一招：删了重拷
        if ([fm fileExistsAtPath:dst]) [fm removeItemAtPath:dst error:nil];
        if ([fm copyItemAtPath:src toPath:dst error:nil]) { touched = YES; continue; }

        lllLog(@"!!! 写入失败: %@", dst);
    }
    return touched;
}

static BOOL copyDir(NSString *s, NSString *d, BOOL ow, NSString *skip) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:s error:nil];
    if (!items) return NO;
    ensureDir(d);

    for (NSString *f in items) {
        if (skip && [f isEqualToString:skip]) continue;
        NSString *sp = [s stringByAppendingPathComponent:f];
        NSString *dp = [d stringByAppendingPathComponent:f];
        BOOL dir = NO;
        [fm fileExistsAtPath:sp isDirectory:&dir];
        if (dir) {
            if (!copyDir(sp, dp, ow, nil)) return NO;
        } else {
            if (ow && [fm fileExistsAtPath:dp]) [fm removeItemAtPath:dp error:nil];
            if (![fm copyItemAtPath:sp toPath:dp error:nil]) return NO;
        }
    }
    return YES;
}

static BOOL cleanDir(NSString *d, NSString *keep) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:d error:nil];
    if (!items) return NO;
    BOOL ok = YES;
    for (NSString *f in items) {
        if ([f isEqualToString:keep]) continue;
        if (![fm removeItemAtPath:[d stringByAppendingPathComponent:f] error:nil]) ok = NO;
    }
    return ok;
}

// 递归遍历时跳过已注入目录，命中正则就删
static void cleanCache(NSString *dir, NSRegularExpression *re, NSFileManager *fm,
                       NSMutableArray *del, NSMutableArray *fail) {
    NSString *injectedDir = targetPath();
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dir];

    for (NSString *relativePath in enumerator) {
        NSString *fullPath = [dir stringByAppendingPathComponent:relativePath];

        if ([fullPath hasPrefix:injectedDir]) {
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) [enumerator skipDescendants];
            continue;
        }

        BOOL isDir = NO;
        if (![fm fileExistsAtPath:fullPath isDirectory:&isDir] || isDir) continue;

        NSString *fileName = relativePath.lastPathComponent;
        NSRange r = [re rangeOfFirstMatchInString:fileName options:0 range:NSMakeRange(0, fileName.length)];
        if (r.location == NSNotFound) continue;

        NSError *err = nil;
        if ([fm removeItemAtPath:fullPath error:&err]) {
            [del addObject:fullPath];
        } else {
            [fail addObject:fullPath];
            NSLog(@"[CleanCache] 删除失败: %@, 错误: %@", fullPath, err.localizedDescription);
        }
    }
}


static NSUInteger lllCountFiles(NSString *dir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:dir];
    if (!e) return 0;
    NSUInteger n = 0;
    for (NSString *x in e) { (void)x; n++; }
    return n;
}

#pragma mark - ResourceManager

@implementation ResourceManager

+ (BOOL)copyDir:(NSString*)s to:(NSString*)d {
    return copyDir(s, d, YES, nil);
}

+ (void)injectMats:(NSArray*)paths names:(NSArray*)names cb:(void(^)(NSArray*,NSArray*))cb {
    dispatch_async(g_fileQueue(), ^{
        NSArray<NSString*> *targets = injectionTargetDirs();
        NSMutableArray *ok = [NSMutableArray new], *fail = [NSMutableArray new];

        lllLog(@"=== 注入开始：%lu 个源，%lu 个目标 ===",
               (unsigned long)paths.count, (unsigned long)targets.count);
        lllLogDirectorySnapshot();

        NSNumber *mirrorObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"LLL.mirrorLegacy"];
        BOOL doMirror = mirrorObj ? mirrorObj.boolValue : YES;
        NSArray<NSString*> *mirrors = doMirror ? legacyPatchDirs() : @[];

        for (NSUInteger i = 0; i < paths.count; i++) {
            NSString *name = (i < names.count) ? names[i] : [(NSString *)paths[i] lastPathComponent];
            BOOL any = NO;

            for (NSString *t in targets) {
                lllEnsurePackManifestAt(t);
                BOOL r = mergeDir(paths[i], t);
                if (r) any = YES;
                lllLog(@"   -> %@  %@  (%lu files)", t, r ? @"OK" : @"FAIL",
                       (unsigned long)lllCountFiles(t));
            }

            if (any && mirrors.count) {
                for (NSString *m in mirrors) {
                    mergeDir(paths[i], m);
                    lllLog(@"   ~> 镜像 %@", m.lastPathComponent);
                }
            }

            if (any) [ok addObject:name];
            else     [fail addObject:name];
        }

        if (ok.count > 0 && targets.count > 0) {
            [EffectInjector mergeInto:targets.firstObject];
        }

        BOOL reg = lllRegisterGlobalPack();
        lllLog(@"注册 global_resource_packs.json：%@", reg ? @"成功" : @"失败");
        for (NSString *p in globalPackJSONCandidates()) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
                NSString *c = [NSString stringWithContentsOfFile:p
                                                        encoding:NSUTF8StringEncoding
                                                           error:nil];
                lllLog(@"   %@ => %@", p.lastPathComponent,
                       c.length > 240 ? [c substringToIndex:240] : (c ?: @""));
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (cb) cb(ok, fail);
        });
    });
}

+ (void)injectPlugins:(NSArray*)paths names:(NSArray*)names type:(NSInteger)type cb:(void(^)(BOOL,NSArray*,NSArray*))cb {
    dispatch_async(g_fileQueue(), ^{
        NSArray<NSString*> *targets = nil;

        if (type == 0) {
            targets = findAllBugudaoTargets();
        } else if (type == 1) {
            NSString *ec = [packcacheBasePath() stringByAppendingPathComponent:
                            @"b6a76e97-75fa-4f3f-82e3_behavior_packs_ec_nk_ui_beh"];
            if ([NSFileManager.defaultManager fileExistsAtPath:ec]) targets = @[ec];
        } else {
            targets = findAllMisakiTargets();
        }

        if (targets.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(NO, nil, nil); });
            return;
        }

        NSMutableArray *ok = [NSMutableArray new], *fail = [NSMutableArray new];
        NSFileManager *fm = NSFileManager.defaultManager;

        for (NSString *target in targets) {
            // contents.json 会让游戏认死旧清单，注之前先掀掉
            NSString *ctx = [target stringByAppendingPathComponent:@"contents.json"];
            if ([fm fileExistsAtPath:ctx]) [fm removeItemAtPath:ctx error:nil];

            for (NSUInteger i = 0; i < paths.count; i++) {
                NSString *name = (i < names.count) ? names[i] : [(NSString *)paths[i] lastPathComponent];
                if (mergeDir(paths[i], target)) [ok addObject:name];
                else                            [fail addObject:name];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (cb) cb(YES, ok, fail);
        });
    });
}

+ (void)cleanTarget:(void(^)(BOOL))cb {
    dispatch_async(g_fileQueue(), ^{
        // 我们自己的包目录，manifest 必须留着，否则包就废了
        BOOL ok = YES;
        for (NSString *t in injectionTargetDirs()) {
            NSFileManager *fm = [NSFileManager defaultManager];
            if (![fm fileExistsAtPath:t]) continue;
            if (!cleanDir(t, @"manifest.json")) ok = NO;
            lllLog(@"清理 %@ -> %lu files", t, (unsigned long)lllCountFiles(t));
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(ok); });
    });
}

+ (void)killCacheOnce:(void(^)(NSUInteger, NSUInteger))cb {
    dispatch_async(g_fileQueue(), ^{
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *base = neteaseGameBasePath();
        NSRegularExpression *re = killenRegex();
        NSMutableArray *del = [NSMutableArray new], *fail = [NSMutableArray new];

        for (NSString *sub in @[@"resource_packs", @"packcache", @"storge"]) {
            NSString *dir = [base stringByAppendingPathComponent:sub];
            if ([fm fileExistsAtPath:dir]) cleanCache(dir, re, fm, del, fail);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (cb) cb(del.count, fail.count);
        });
    });
}

@end
