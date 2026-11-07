//
//  Entry.m
//  LLL / MaterialPackManager 入口
//
//  设计原则：启动阶段绝不抢跑。
//    · 任何异常都不许冒泡到宿主
//    · 连续崩溃自动熔断，不让插件把游戏拖成启动循环
//    · UI 延后到宿主窗口稳定之后再挂
//

#import "FloatMonitor.h"
#import "BaseComponents.h"

#pragma mark - 授权窗口

static NSString * const kLicStartKey = @"LLL.licenseStart";
static NSString * const kLicEndKey   = @"LLL.licenseEnd";

static NSString * const kLicStartDefault = @"2026-04-24";
static NSString * const kLicEndDefault   = @"2036-12-31";

#pragma mark - 熔断

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
    if (!d) return nil;
    return [cal startOfDayForDate:d];
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

// 60 秒内连续两次被重新拉起 → 判为启动崩溃循环，本次完全不加载。
// 冷静 10 分钟后再启动会自动恢复正常。
static BOOL CrashLoopGuard(void) {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;

    if ([d boolForKey:kDisabledKey]) {
        NSLog(@"[LLL] LLL.disabled = YES，跳过加载");
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
        NSLog(@"[LLL] 连续 %ld 次快速重启，判定崩溃循环，本次跳过", (long)strikes);
        return NO;
    }

    // 30 秒没崩就清零
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
            if (!LicenseValid()) {
                NSLog(@"[LLL] 授权窗口已过，跳过加载");
                return;
            }
            if (!CrashLoopGuard()) return;

            @try {
                [NSNotificationCenter.defaultCenter
                    addObserverForName:UIDeviceOrientationDidChangeNotification
                                object:nil
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification *note) {
                                @try { handleOrientationChange(); } @catch (__unused NSException *e) {}
                            }];
            } @catch (__unused NSException *e) {}

            // 1.5s 之后再挂悬浮球：等宿主场景、窗口、渲染链全部就绪
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try {
                    showFloatingBall();
                } @catch (NSException *e) {
                    NSLog(@"[LLL] showFloatingBall 异常: %@", e.reason);
                }

                // 水印再往后错 0.6s，别和悬浮球抢同一帧的布局
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    @try {
                        showWatermark();
                    } @catch (NSException *e) {
                        NSLog(@"[LLL] showWatermark 异常: %@", e.reason);
                    }
                });
            });
        } @catch (NSException *e) {
            NSLog(@"[LLL] 初始化异常: %@", e.reason);
        }
    }
}
