//
//  Entry.m
//  LLL / MaterialPackManager 入口
//
//  注入后：
//    1. 校验授权窗口（可运行时用 NSUserDefaults 覆盖，不用重新编译）
//    2. 监听转屏，重排悬浮球
//    3. 延迟 0.5s 起悬浮球 + 水印（等宿主窗口就绪）
//

#import "FloatMonitor.h"
#import "BaseComponents.h"

#pragma mark - 授权窗口

static NSString * const kLicStartKey = @"LLL.licenseStart";
static NSString * const kLicEndKey   = @"LLL.licenseEnd";

// 默认窗口放到 2036：原来写死到 2026-08-31，今天已经过期，
// 结果是整个插件静默不加载（悬浮球、UI 全都不出来）。
static NSString * const kLicStartDefault = @"2026-04-24";
static NSString * const kLicEndDefault   = @"2036-12-31";

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

// 把 "yyyy-MM-dd" 解析成当天 00:00:00；失败返回 nil
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
    if (!start || !end) return YES;   // 配错了就别掐死，放行

    NSDate *today = [cal startOfDayForDate:[NSDate date]];
    return [today compare:start] != NSOrderedAscending &&
           [today compare:end]   != NSOrderedDescending;
}

#pragma mark - 入口

__attribute__((constructor))
static void LLLInit(void) {
    if (!LicenseValid()) {
        NSLog(@"[MaterialPackManager] 授权窗口已过（start=%@ end=%@），跳过加载",
              SettingOrDefault(kLicStartKey, kLicStartDefault),
              SettingOrDefault(kLicEndKey, kLicEndDefault));
        return;
    }

    [NSNotificationCenter.defaultCenter
        addObserverForName:UIDeviceOrientationDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) {
                    handleOrientationChange();
                }];

    // 宿主窗口 0.5s 内基本就绪，早了拿不到 UIWindowScene
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        showFloatingBall();
        showWatermark();
    });
}
