//
//  Entry.m
//  LLL / MaterialPackManager 入口
//
//  26.4.2 加入：
//    · Documents/LLL_OFF        文件级总开关，文件 App 里新建一个空文件就能关掉
//    · Documents/LLL_runtime.log 运行日志（启动阶段、加载的 dylib、各步耗时）
//    · Documents/LLL_PATCH_BUJI 可选：把 libBujiFix 的 bk_dl_req 打成直接 return
//    · 启动熔断：60 秒内连续两次被拉起 → 本次不加载
//

#import "FloatMonitor.h"
#import "BaseComponents.h"
#import "PluginInfo.h"
#import "LLLUiKit.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <sys/mman.h>
#import <unistd.h>
#import <string.h>
#import <errno.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>

#pragma mark - 路径 / 日志

static NSString *LLLDocsDir(void) {
    static NSString *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    });
    return d ?: NSHomeDirectory();
}

#define LLLLog(...) lllLog(__VA_ARGS__)

static BOOL LLLFileExists(NSString *name) {
    return [[NSFileManager defaultManager]
            fileExistsAtPath:[LLLDocsDir() stringByAppendingPathComponent:name]];
}

#pragma mark - 加载镜像探测

static intptr_t LLLFindImage(NSString *needle, const struct mach_header_64 **outHeader) {
    uint32_t count = _dyld_image_count();
    const char *n = needle.UTF8String;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, n)) continue;
        if (outHeader) {
            const struct mach_header *h = _dyld_get_image_header(i);
            *outHeader = (const struct mach_header_64 *)h;
        }
        return _dyld_get_image_vmaddr_slide(i);
    }
    if (outHeader) *outHeader = NULL;
    return 0;
}

static void LLLLogLoadedDylibs(void) {
    uint32_t count = _dyld_image_count();
    NSMutableArray *fake = [NSMutableArray array];
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *s = @(name);
        if ([s containsString:@"/Frameworks/"] || [s containsString:@".dylib"]) {
            [fake addObject:s.lastPathComponent];
        }
    }
    LLLLog(@"注入镜像: %@", [fake componentsJoinedByString:@", "]);
}

#pragma mark - 可选：禁用布吉岛那个会崩的 hook

// 抓到的两次崩溃都停在同一处：libBujiFix.dylib +26600 (bk_dl_req) 调 objc_retain，
// 传进去的对象 isa 已经是垃圾值。这里提供一个人为开关，把那函数直接打成 return。
static BOOL LLLPatchBuji(void) {
    const struct mach_header_64 *mh = NULL;
    LLLFindImage(@"libBujiFix", &mh);
    if (!mh) {
        LLLLog(@"PATCH_BUJI: 没找到 libBujiFix");
        return NO;
    }

    // 只处理 arm64 / arm64e
    if (mh->magic != MH_MAGIC_64) {
        LLLLog(@"PATCH_BUJI: 不是 64 位 Mach-O，跳过");
        return NO;
    }

    const size_t offset = 26600;          // bk_dl_req
    uint8_t *target = (uint8_t *)mh + offset;

    long pageSize = sysconf(_SC_PAGESIZE);
    if (pageSize <= 0) pageSize = 16384;
    uintptr_t pageStart = (uintptr_t)target & ~((uintptr_t)pageSize - 1);

    if (mprotect((void *)pageStart, (size_t)pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        LLLLog(@"PATCH_BUJI: mprotect 失败 errno=%d", errno);
        return NO;
    }

    // mov x0, #0 ; ret
    const uint32_t patch[2] = { 0xD2800000u, 0xD65F03C0u };
    memcpy(target, patch, sizeof(patch));
    sys_icache_invalidate(target, sizeof(patch));

    LLLLog(@"PATCH_BUJI: 已把 %p 打成 return", target);
    return YES;
}

#pragma mark - 重复加载检测

// 用户经常把新 dylib 丢进 Frameworks 而不删旧的，结果 (6).dylib 和 (7).dylib 同时被加载，
// 每份都有自己的静态变量 → 两个悬浮球、两套 UI。这里只让"最先被加载的那一份"活着。
static void LLLMarkerFn(void) { }

static BOOL LLLIsDuplicateDylib(void) {
    Dl_info info;
    if (dladdr((void *)&LLLMarkerFn, &info) == 0 || !info.dli_fbase) return NO;

    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "MaterialPackManager")) continue;
        const struct mach_header *h = _dyld_get_image_header(i);
        return (h != (const struct mach_header *)info.dli_fbase);
    }
    return NO;
}

#pragma mark - 授权窗口

static NSString * const kLicStartKey = @"LLL.licenseStart";
static NSString * const kLicEndKey   = @"LLL.licenseEnd";
static NSString * const kLicStartDefault = @"2026-04-24";
static NSString * const kLicEndDefault   = @"2036-12-31";

static NSString * const kBootTimeKey = @"LLL.bootTime";
static NSString * const kStrikesKey  = @"LLL.strikes";
static NSString * const kDisabledKey = @"LLL.disabled";

static NSDateFormatter *DayFormatter(void) {
    static NSDateFormatter *f;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [NSDateFormatter new];
        f.dateFormat = @"yyyy-MM-dd";
        f.timeZone = NSTimeZone.localTimeZone;
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return f;
}

static NSDate *ParseDay(NSString *s, NSCalendar *cal) {
    if (s.length == 0) return nil;
    NSDate *d = [DayFormatter() dateFromString:s];
    return d ? [cal startOfDayForDate:d] : nil;
}

static NSString *SettingOrDefault(NSString *key, NSString *fallback) {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return v.length ? v : fallback;
}

static BOOL LicenseValid(void) {
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *start = ParseDay(SettingOrDefault(kLicStartKey, kLicStartDefault), cal);
    NSDate *end   = ParseDay(SettingOrDefault(kLicEndKey,   kLicEndDefault),   cal);
    if (!start || !end) return YES;
    NSDate *today = [cal startOfDayForDate:[NSDate date]];
    return [today compare:start] != NSOrderedAscending &&
           [today compare:end]   != NSOrderedDescending;
}

static BOOL CrashLoopGuard(void) {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;

    if ([d boolForKey:kDisabledKey]) {
        LLLLog(@"LLL.disabled = YES，跳过");
        return NO;
    }

    double now  = CFAbsoluteTimeGetCurrent();
    double last = [d doubleForKey:kBootTimeKey];
    NSInteger strikes = [d integerForKey:kStrikesKey];

    if (last > 0 && (now - last) < 60.0) strikes++;
    else strikes = 0;

    [d setDouble:now forKey:kBootTimeKey];
    [d setInteger:strikes forKey:kStrikesKey];

    if (strikes >= 2) {
        LLLLog(@"连续 %ld 次快速重启，判定崩溃循环，本次跳过", (long)strikes);
        return NO;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSUserDefaults *dd = NSUserDefaults.standardUserDefaults;
        if ([dd integerForKey:kStrikesKey] < 2) [dd setInteger:0 forKey:kStrikesKey];
    });
    return YES;
}

#pragma mark - 入口

__attribute__((constructor))
static void LLLInit(void) {
    @autoreleasepool {
        @try {
            if (LLLFileExists(@"LLL_OFF")) return;

            if (LLLIsDuplicateDylib()) {
                lllLog(@"检测到重复加载的 MaterialPackManager，本份退出");
                return;
            }

            LLLLog(@"===== LLL %@ 启动 =====", kPluginVersion);
            LLLLog(@"bundle=%@", [NSBundle mainBundle].bundleIdentifier);
            LLLLogLoadedDylibs();

            if (!LicenseValid()) {
                LLLLog(@"授权窗口已过，跳过");
                return;
            }
            if (!CrashLoopGuard()) return;

            lllLogDirectorySnapshot();


            // 实验开关：只有手动放了 LLL_PATCH_BUJI 才动手
            if (LLLFileExists(@"LLL_PATCH_BUJI")) {
                LLLLog(@"检测到 LLL_PATCH_BUJI，尝试禁用 bk_dl_req");
                LLLPatchBuji();
            }

            @try {
                [NSNotificationCenter.defaultCenter
                    addObserverForName:UIDeviceOrientationDidChangeNotification
                                object:nil
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification *note) {
                                @try { handleOrientationChange(); } @catch (__unused NSException *e) {}
                            }];
            } @catch (__unused NSException *e) {}

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try {
                    showFloatingBall();
                    LLLLog(@"悬浮球已挂");
                } @catch (NSException *e) {
                    LLLLog(@"showFloatingBall 异常: %@", e.reason);
                }

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    @try {
                        showWatermark();
                        LLLLog(@"水印已挂");
                    } @catch (NSException *e) {
                        LLLLog(@"showWatermark 异常: %@", e.reason);
                    }
                });
            });
        } @catch (NSException *e) {
            LLLLog(@"初始化异常: %@", e.reason);
        }
    }
}
