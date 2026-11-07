
#import "FloatMonitor.h"
#import "BaseComponents.h"

__attribute__((constructor)) static void init() {
    NSArray *ranges = @[@{@"start":@"2026-04-24",@"end":@"2026-08-31"}];
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"yyyy-MM-dd";
    fmt.timeZone = NSTimeZone.systemTimeZone;
    BOOL ok = NO;
    for (NSDictionary *d in ranges) {
        NSDate *s = [fmt dateFromString:d[@"start"]];
        NSDate *e = [fmt dateFromString:d[@"end"]];
        if (!s || !e) continue;
        NSDateComponents *ec = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:e];
        ec.hour = 23; ec.minute = 59; ec.second = 59;
        NSDate *eod = [cal dateFromComponents:ec];
        NSDateComponents *tc = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
        tc.hour = 0; tc.minute = 0; tc.second = 0;
        NSDate *td = [cal dateFromComponents:tc];
        if ([td compare:s] != NSOrderedAscending && [td compare:eod] != NSOrderedDescending) {
            ok = YES;
            break;
        }
    }
    // 原来这里是 exit(0)：过了授权日期会直接把宿主 App 杀掉（今天 2026-11 已经过期）。
    // 改成软关闭：只是不挂 UI，宿主照常运行。
    if (!ok) {
        NSLog(@"[MaterialPackManager] 授权日期已过，跳过加载");
        return;
    }

    [NSNotificationCenter.defaultCenter addObserverForName:UIDeviceOrientationDidChangeNotification
                                                    object:nil
                                                     queue:NSOperationQueue.mainQueue
                                                usingBlock:^(NSNotification *_) {
        handleOrientationChange();
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        showFloatingBall();
        showWatermark();
    });
}