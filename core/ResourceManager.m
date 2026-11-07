#import "ResourceManager.h"
#import "EffectInjector.h"
#import <math.h>

#pragma mark - 工具函数

static NSDictionary* deepMerge(NSDictionary *target, NSDictionary *source) {
    NSMutableDictionary *result = [target mutableCopy] ?: [NSMutableDictionary new];
    for (NSString *key in source) {
        id sv = source[key];
        id tv = result[key];
        if ([sv isKindOfClass:[NSDictionary class]] && [tv isKindOfClass:[NSDictionary class]]) {
            result[key] = deepMerge(tv, sv);
        } else {
            result[key] = sv;
        }
    }
    return result;
}

#pragma mark - JSON 预处理（BOM、注释、尾随逗号）

// 移除 UTF-8 BOM 头 (EF BB BF)
static NSData* stripBOMFromData(NSData *data) {
    if (data.length >= 3) {
        const unsigned char *bytes = data.bytes;
        if (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
            return [data subdataWithRange:NSMakeRange(3, data.length - 3)];
        }
    }
    return data;
}

// 移除 // 和 /* */ 注释，但保留字符串内的内容
static NSString* stripJSONComments(NSString *jsonString) {
    if (!jsonString) return nil;
    NSMutableString *outStr = [NSMutableString string];
    NSUInteger length = jsonString.length;
    BOOL inString = NO;
    BOOL inMultilineComment = NO;
    BOOL inSingleLineComment = NO;
    unichar prevChar = 0;
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [jsonString characterAtIndex:i];
        unichar next = (i + 1 < length) ? [jsonString characterAtIndex:i+1] : 0;
        if (!inMultilineComment && !inSingleLineComment && c == '"' && prevChar != '\\') {
            inString = !inString;
            [outStr appendFormat:@"%C", c];
            prevChar = c;
            continue;
        }
        if (inString) {
            [outStr appendFormat:@"%C", c];
            prevChar = c;
            continue;
        }
        if (!inMultilineComment && !inSingleLineComment) {
            if (c == '/' && next == '/') {
                inSingleLineComment = YES;
                i++;
                prevChar = 0;
                continue;
            } else if (c == '/' && next == '*') {
                inMultilineComment = YES;
                i++;
                prevChar = 0;
                continue;
            }
        }
        if (inSingleLineComment) {
            if (c == '\n' || c == '\r') {
                inSingleLineComment = NO;
                [outStr appendFormat:@"%C", c];
            }
            prevChar = c;
            continue;
        }
        if (inMultilineComment) {
            if (c == '*' && next == '/') {
                inMultilineComment = NO;
                i++;
                [outStr appendString:@" "];
                prevChar = 0;
                continue;
            }
            prevChar = c;
            continue;
        }
        [outStr appendFormat:@"%C", c];
        prevChar = c;
    }
    return outStr;
}

// 移除对象/数组末尾多余的逗号
static NSString* removeTrailingCommas(NSString *jsonString) {
    if (!jsonString) return nil;
    NSMutableString *outStr = [NSMutableString string];
    NSUInteger length = jsonString.length;
    BOOL inString = NO;
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [jsonString characterAtIndex:i];
        if (c == '"' && (i == 0 || [jsonString characterAtIndex:i-1] != '\\')) {
            inString = !inString;
            [outStr appendFormat:@"%C", c];
            continue;
        }
        if (inString) {
            [outStr appendFormat:@"%C", c];
            continue;
        }
        if (c == ',') {
            NSUInteger j = i + 1;
            while (j < length && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[jsonString characterAtIndex:j]]) {
                j++;
            }
            if (j < length && ([jsonString characterAtIndex:j] == '}' || [jsonString characterAtIndex:j] == ']')) {
                continue; // 跳过尾随逗号
            }
        }
        [outStr appendFormat:@"%C", c];
    }
    return outStr;
}

// 完整的 JSON 清理流水线
static NSString* cleanJSONString(NSString *raw) {
    if (!raw) return nil;
    NSString *cleaned = stripJSONComments(raw);
    cleaned = removeTrailingCommas(cleaned);
    return cleaned;
}

#pragma mark - 文件合并（支持 JSON 深度合并）

static BOOL mergeFile(NSString *srcPath, NSString *dstPath) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *ext = dstPath.pathExtension.lowercaseString;
    BOOL isJSON = [ext isEqualToString:@"json"] ||
                  [ext isEqualToString:@"material"] ||
                  [ext isEqualToString:@"fragment"];

    if (isJSON) {
        // 读取源文件，去除 BOM
        NSData *srcData = [NSData dataWithContentsOfFile:srcPath];
        if (!srcData) return NO;
        srcData = stripBOMFromData(srcData);
        NSString *srcRaw = [[NSString alloc] initWithData:srcData encoding:NSUTF8StringEncoding];
        if (!srcRaw) return NO;

        // 清理源文件（注释 + 尾随逗号）
        NSString *cleanSrc = cleanJSONString(srcRaw);
        NSData *cleanData = [cleanSrc dataUsingEncoding:NSUTF8StringEncoding];
        id srcJson = [NSJSONSerialization JSONObjectWithData:cleanData options:0 error:nil];
        if (!srcJson) {
            // 解析失败 → 直接复制源文件（保证不报错）
            NSLog(@"[mergeFile] JSON 解析失败，直接复制: %@", srcPath);
            if ([fm fileExistsAtPath:dstPath]) [fm removeItemAtPath:dstPath error:nil];
            return [fm copyItemAtPath:srcPath toPath:dstPath error:nil];
        }

        // 读取目标文件（同样处理 BOM）
        id dstJson = nil;
        if ([fm fileExistsAtPath:dstPath]) {
            NSData *dstData = [NSData dataWithContentsOfFile:dstPath];
            if (dstData) {
                dstData = stripBOMFromData(dstData);
                NSString *dstRaw = [[NSString alloc] initWithData:dstData encoding:NSUTF8StringEncoding];
                if (dstRaw) {
                    NSString *cleanDst = cleanJSONString(dstRaw);
                    NSData *cleanDstData = [cleanDst dataUsingEncoding:NSUTF8StringEncoding];
                    dstJson = [NSJSONSerialization JSONObjectWithData:cleanDstData options:0 error:nil];
                    if (!dstJson) dstJson = nil; // 解析失败视为无目标
                }
            }
        }

        // 深度合并
        if ([srcJson isKindOfClass:[NSDictionary class]] && [dstJson isKindOfClass:[NSDictionary class]]) {
            NSDictionary *merged = deepMerge(dstJson, srcJson);
            NSData *mergedData = [NSJSONSerialization dataWithJSONObject:merged
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:nil];
            if (!mergedData) return NO;
            return [mergedData writeToFile:dstPath atomically:YES];
        } else {
            // 源或目标不是字典 → 直接覆盖
            if ([fm fileExistsAtPath:dstPath]) [fm removeItemAtPath:dstPath error:nil];
            return [fm copyItemAtPath:srcPath toPath:dstPath error:nil];
        }
    } else {
        // 非 JSON 文件直接覆盖
        if ([fm fileExistsAtPath:dstPath]) [fm removeItemAtPath:dstPath error:nil];
        return [fm copyItemAtPath:srcPath toPath:dstPath error:nil];
    }
}


// 源/目标一致（大小 + mtime 同）→ 跳过，避免每次注入重新解析 JSON
static BOOL sameFile(NSString *a, NSString *b) {
    NSDictionary *fa = [NSFileManager.defaultManager attributesOfItemAtPath:a error:nil];
    NSDictionary *fb = [NSFileManager.defaultManager attributesOfItemAtPath:b error:nil];
    if (!fa || !fb) return NO;
    if (![fa[NSFileSize] isEqualToNumber:fb[NSFileSize]]) return NO;
    NSDate *da = fa[NSFileModificationDate], *db = fb[NSFileModificationDate];
    return da && db && fabs([da timeIntervalSinceDate:db]) < 1.0;
}

static BOOL mergeDir(NSString *srcDir, NSString *dstDir) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *items = [fm contentsOfDirectoryAtPath:srcDir error:nil];
    if (!items) return NO;
    ensureDir(dstDir);

    for (NSString *item in items) {
        if ([item isEqualToString:@"manifest.json"] || [item isEqualToString:@"pack_manifest.json"]) {
            continue;
        }

        NSString *src = [srcDir stringByAppendingPathComponent:item];
        NSString *dst = [dstDir stringByAppendingPathComponent:item];
        BOOL isDir;
        [fm fileExistsAtPath:src isDirectory:&isDir];

        if (isDir) {
            if (!mergeDir(src, dst)) return NO;
        } else {
            if ([fm fileExistsAtPath:dst]) {
                if (sameFile(src, dst)) continue;          // 内容没变，零成本跳过
                if (!mergeFile(src, dst)) return NO;
            } else {
                if (![fm copyItemAtPath:src toPath:dst error:nil]) return NO;
            }
        }
    }
    return YES;
}

static BOOL copyDir(NSString *s, NSString *d, BOOL ow, NSString *skip) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *items = [fm contentsOfDirectoryAtPath:s error:nil];
    if (!items) return NO;
    ensureDir(d);
    for (NSString *f in items) {
        if (skip && [f isEqualToString:skip]) continue;
        NSString *sp = [s stringByAppendingPathComponent:f], *dp = [d stringByAppendingPathComponent:f];
        BOOL dir;
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
    NSArray *items = [fm contentsOfDirectoryAtPath:d error:nil];
    if (!items) return NO;
    BOOL ok = YES;
    for (NSString *f in items) {
        if (![f isEqualToString:keep] && ![fm removeItemAtPath:[d stringByAppendingPathComponent:f] error:nil]) {
            ok = NO;
        }
    }
    return ok;
}

static void cleanCache(NSString *dir, NSRegularExpression *re, NSFileManager *fm,
                       NSMutableArray *del, NSMutableArray *fail) {
    NSString *injectedDir = targetPath();
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dir];
    for (NSString *relativePath in enumerator) {
        NSString *fullPath = [dir stringByAppendingPathComponent:relativePath];
        if ([fullPath hasPrefix:injectedDir]) {
            BOOL d = NO;
            if ([fm fileExistsAtPath:fullPath isDirectory:&d] && d) [enumerator skipDescendants];
            continue;                                    // 整棵子树不再下钻
        }
        BOOL isDir;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
            NSString *fileName = relativePath.lastPathComponent;
            if ([re rangeOfFirstMatchInString:fileName
                                      options:0
                                        range:NSMakeRange(0, fileName.length)].location != NSNotFound) {
                NSError *err = nil;
                if ([fm removeItemAtPath:fullPath error:&err]) {
                    [del addObject:fullPath];
                } else {
                    [fail addObject:fullPath];
                    NSLog(@"[CleanCache] 删除失败: %@, 错误: %@", fullPath, err.localizedDescription);
                }
            }
        }
    }
}

#pragma mark - ResourceManager 实现

@implementation ResourceManager

+ (BOOL)copyDir:(NSString*)s to:(NSString*)d {
    return copyDir(s, d, YES, nil);
}

+ (void)injectMats:(NSArray*)paths names:(NSArray*)names cb:(void(^)(NSArray*,NSArray*))cb {
    dispatch_async(g_fileQueue(), ^{
        NSString *t = targetPath();
        NSMutableArray *ok=[NSMutableArray new], *fail=[NSMutableArray new];
        for (NSUInteger i=0; i<paths.count; i++) {
            if (mergeDir(paths[i], t)) [ok addObject:names[i]];
            else [fail addObject:names[i]];
        }
        if (fail.count == 0) [EffectInjector mergeInto:t];   // 打击特效 overlay 包
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(ok, fail);
        });
    });
}

+ (void)injectPlugins:(NSArray*)paths names:(NSArray*)names type:(NSInteger)type cb:(void(^)(BOOL,NSArray*,NSArray*))cb {
    dispatch_async(g_fileQueue(), ^{
        NSArray<NSString*> *targets;
        if (type == 0) {
            targets = findAllBugudaoTargets();
            if (!targets.count) {
                dispatch_async(dispatch_get_main_queue(), ^{ cb(NO, nil, nil); });
                return;
            }
        } else if (type == 1) {
            targets = @[[packcacheBasePath() stringByAppendingPathComponent:@"b6a76e97-75fa-4f3f-82e3_behavior_packs_ec_nk_ui_beh"]];
            if (![NSFileManager.defaultManager fileExistsAtPath:targets.firstObject]) {
                dispatch_async(dispatch_get_main_queue(), ^{ cb(NO, nil, nil); });
                return;
            }
        } else {
            targets = findAllMisakiTargets();
            if (!targets.count) {
                dispatch_async(dispatch_get_main_queue(), ^{ cb(NO, nil, nil); });
                return;
            }
        }

        NSMutableArray *ok = [NSMutableArray new], *fail = [NSMutableArray new];
        for (NSString *target in targets) {

            NSString *ctx = [target stringByAppendingPathComponent:@"contents.json"];
            if ([NSFileManager.defaultManager fileExistsAtPath:ctx]) {
                [NSFileManager.defaultManager removeItemAtPath:ctx error:nil];
            }
            for (NSUInteger i = 0; i < paths.count; i++) {
                if (mergeDir(paths[i], target)) [ok addObject:names[i]];
                else [fail addObject:names[i]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(YES, ok, fail);
        });
    });
}

+ (void)cleanTarget:(void(^)(BOOL))cb {
    dispatch_async(g_fileQueue(), ^{
        BOOL ok = cleanDir(targetPath(), @"pack_manifest.json");
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(ok);
        });
    });
}

+ (void)killCacheOnce:(void(^)(NSUInteger, NSUInteger))cb {
    dispatch_async(g_fileQueue(), ^{
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *base = neteaseGameBasePath();
        NSRegularExpression *re = killenRegex();
        NSMutableArray *del = [NSMutableArray new];
        NSMutableArray *fail = [NSMutableArray new];
        NSArray *subDirs = @[@"resource_packs", @"packcache", @"storge"];
        for (NSString *sub in subDirs) {
            NSString *dir = [base stringByAppendingPathComponent:sub];
            if ([fm fileExistsAtPath:dir]) {
                cleanCache(dir, re, fm, del, fail);
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(del.count, fail.count);
        });
    });
}

@end