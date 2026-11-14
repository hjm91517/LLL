//
//  FoliaPayload.m
//  把内嵌的 Folia www 解到沙盒
//

#import "FoliaPayload.h"
#import "LLLZip.h"

#define INCBIN_PREFIX flia
#define INCBIN_STYLE INCBIN_STYLE_SNAKE
#define INCBIN_SILENCE_BITCODE_WARNING
#include "incbin.h"

INCBIN(FoliaZip, "folia-www.zip");

NSString * const kFoliaBundleVersion = @"2.1.5";

static NSString *FoliaDir(void) {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!docs.length) docs = NSHomeDirectory();
    return [docs stringByAppendingPathComponent:@"LLL/folia"];
}

static NSString *FoliaMarker(void) {
    return [FoliaDir() stringByAppendingPathComponent:@"version.txt"];
}

NSString *FoliaWebRoot(void) {
    NSString *www = [FoliaDir() stringByAppendingPathComponent:@"www"];
    NSString *idx = [www stringByAppendingPathComponent:@"index.html"];
    return [[NSFileManager defaultManager] fileExistsAtPath:idx] ? www : nil;
}

static void FoliaReply(void (^done)(BOOL, NSString *, NSString *), BOOL ok, NSString *root, NSString *err) {
    if (!done) return;
    dispatch_async(dispatch_get_main_queue(), ^{ done(ok, root, err); });
}

void FoliaEnsureReady(void (^done)(BOOL, NSString *, NSString *)) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *marker = FoliaMarker();
        NSString *have = [NSString stringWithContentsOfFile:marker
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
        have = [have stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

        if ([have isEqualToString:kFoliaBundleVersion] && FoliaWebRoot()) {
            FoliaReply(done, YES, FoliaWebRoot(), nil);
            return;
        }

        /* 内嵌数据 → 临时 zip（LLLZip 按路径读，图省事不改造它） */
        NSData *blob = [NSData dataWithBytes:flia_folia_zip_data length:flia_folia_zip_size];
        if (blob.length < 1024) {
            FoliaReply(done, NO, nil, @"内嵌 Folia 数据为空");
            return;
        }
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"lll-folia.zip"];
        if (![blob writeToFile:tmp atomically:YES]) {
            FoliaReply(done, NO, nil, @"写临时 zip 失败");
            return;
        }

        /* 旧版本整个换掉，避免残留 chunk 与新 index 对不上 */
        NSString *www = [FoliaDir() stringByAppendingPathComponent:@"www"];
        [fm removeItemAtPath:www error:nil];
        [fm createDirectoryAtPath:www withIntermediateDirectories:YES attributes:nil error:nil];

        NSError *err = nil;
        NSArray<NSString *> *files = [LLLZip extract:tmp to:www error:&err];
        [fm removeItemAtPath:tmp error:nil];

        if (!files.count || !FoliaWebRoot()) {
            FoliaReply(done, NO, nil, err.localizedDescription ?: @"解包失败");
            return;
        }
        [kFoliaBundleVersion writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"[Folia] 解包完成 %lu 个文件 -> %@", (unsigned long)files.count, www);
        FoliaReply(done, YES, www, nil);
    });
}
