//
//  LLLStealth.m
//

#import "LLLStealth.h"
#import "BaseComponents.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <sys/mman.h>
#import <unistd.h>
#import <string.h>
#import <stdlib.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <libkern/OSCacheControl.h>

#pragma mark - 镜像名伪装

/*
 * 【崩溃根修】旧实现在 hook 里用 dlsym(RTLD_NEXT, "dyld_get_image_name") 找原函数，
 * 但 Darwin 的 dlsym 解析符号时会命中 __interpose 表，把「替换函数自己」还回来，
 * 导致 real(index) = LLLFakeImageName(index) 无限自调
 * （崩溃日志：30709 层递归 → SIGSEGV，发生在 dyld 初始化阶段）。
 *
 * 新实现：直接读 task_info(TASK_DYLD_INFO) 的 dyld_all_image_infos 镜像表，
 * 全程不调用被 interpose 的符号、不用 dlsym，结构上不可能递归。
 */
typedef struct {
    const void *loadAddress;
    const char *imageFilePath;
    const void *imageLoadAddress;
} LLLDyldImageInfo;

typedef struct {
    uint32_t version;
    uint32_t infoArrayCount;
    const LLLDyldImageInfo *infoArray;
} LLLDyldInfosHead;

static const char *LLLRealImageName(uint32_t index) {
    task_dyld_info_data_t tinfo;
    mach_msg_type_number_t cnt = TASK_DYLD_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&tinfo, &cnt) != KERN_SUCCESS)
        return NULL;
    if (tinfo.all_image_info_addr == 0)
        return NULL;
    const LLLDyldInfosHead *aii = (const LLLDyldInfosHead *)(uintptr_t)tinfo.all_image_info_addr;
    if (!aii->infoArray || index >= aii->infoArrayCount)
        return NULL;
    return aii->infoArray[index].imageFilePath;
}

static const char *LLLFakeImageName(uint32_t index) {
    const char *n = LLLRealImageName(index);
    if (!n) return NULL;
    if (strstr(n, "bbhj") || strstr(n, "MaterialPackManager") ||
        strstr(n, "LLLOnline") || strstr(n, "LLL_")) {
        return "/usr/lib/libobjc.A.dylib";
    }
    return n;
}

typedef struct { const void *replacement; const void *replacee; } LLLInterpose;

__attribute__((used))
static const LLLInterpose LLLInterposeImageName
    __attribute__((section("__DATA,__interpose"))) = {
        (const void *)&LLLFakeImageName,
        (const void *)&_dyld_get_image_name
    };

#pragma mark - 文件枚举过滤

static BOOL LLLHiddenPath(NSString *path) {
    if (![path isKindOfClass:NSString.class] || path.length == 0) return NO;
    NSString *low = path.lowercaseString;

    // 自定义图标是 .png，别把用户自己的图标一起藏了
    if ([low containsString:@"bbhj"] && ![low hasSuffix:@".png"]) return YES;
    if ([low containsString:@"materialpackmanager"]) return YES;
    if ([low containsString:@"lll_online"]) return YES;
    return NO;
}

@interface NSFileManager (LLLStealth)
- (BOOL)lll_exists:(NSString *)p;
- (BOOL)lll_exists:(NSString *)p isDir:(BOOL *)d;
- (NSArray<NSString *> *)lll_list:(NSString *)p error:(NSError **)e;
@end

@implementation NSFileManager (LLLStealth)

- (BOOL)lll_exists:(NSString *)p {
    if (LLLHiddenPath(p)) return NO;
    return [self lll_exists:p];
}

- (BOOL)lll_exists:(NSString *)p isDir:(BOOL *)d {
    if (LLLHiddenPath(p)) { if (d) *d = NO; return NO; }
    return [self lll_exists:p isDir:d];
}

- (NSArray<NSString *> *)lll_list:(NSString *)p error:(NSError **)e {
    NSArray *raw = [self lll_list:p error:e];
    if (![raw isKindOfClass:NSArray.class] || raw.count == 0) return raw;
    NSMutableArray *kept = [NSMutableArray arrayWithCapacity:raw.count];
    for (id it in raw) {
        if (![it isKindOfClass:NSString.class]) continue;
        NSString *full = [p stringByAppendingPathComponent:it];
        if (LLLHiddenPath(full)) continue;
        [kept addObject:it];
    }
    return kept;
}

@end

static void LLLSwap(Class cls, SEL a, SEL b) {
    Method ma = class_getInstanceMethod(cls, a);
    Method mb = class_getInstanceMethod(cls, b);
    if (ma && mb) method_exchangeImplementations(ma, mb);
}

#pragma mark - BujiFix

BOOL LLLStealthPatchBuji(void) {
    void *sym = dlsym(RTLD_DEFAULT, "bk_dl_req");
    if (!sym) sym = dlsym(RTLD_DEFAULT, "_bk_dl_req");
    if (!sym) {
        lllLog(@"STEALTH: 没找到 bk_dl_req 符号（版本可能变了）");
        return NO;
    }

    uint32_t *code = (uint32_t *)sym;
    if (code[0] == 0xD65F03C0u) {
        lllLog(@"STEALTH: bk_dl_req 已经打过补丁");
        return YES;
    }

    long pageSize = sysconf(_SC_PAGESIZE);
    if (pageSize <= 0) pageSize = 16384;
    uintptr_t page = (uintptr_t)sym & ~((uintptr_t)pageSize - 1);

    if (mprotect((void *)page, (size_t)pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        lllLog(@"STEALTH: mprotect 失败, bk_dl_req=%p", sym);
        return NO;
    }

    const uint32_t patch[2] = { 0xD2800000u, 0xD65F03C0u };   // mov x0,#0 ; ret
    memcpy((void *)sym, patch, sizeof(patch));
    sys_icache_invalidate((void *)sym, sizeof(patch));
    lllLog(@"STEALTH: bk_dl_req 已打成 return (%p)", sym);
    return YES;
}

#pragma mark - 安装

void LLLStealthInstall(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            unsetenv("DYLD_INSERT_LIBRARIES");
            unsetenv("DYLD_FORCE_FLAT_NAMESPACE");

            LLLSwap([NSFileManager class], @selector(fileExistsAtPath:), @selector(lll_exists:));
            LLLSwap([NSFileManager class], @selector(fileExistsAtPath:isDirectory:), @selector(lll_exists:isDir:));
            LLLSwap([NSFileManager class], @selector(contentsOfDirectoryAtPath:error:), @selector(lll_list:error:));

            lllLog(@"STEALTH: 镜像名伪装 + 文件枚举过滤已装");
        } @catch (NSException *e) {
            lllLog(@"STEALTH 安装异常: %@", e.reason);
        }
    });
}
