//
//  overlay/LLLMusicIsland4_Compat.m
//  运行时兜底：确保命令桥被装上。加载期类可能未就绪，稍延迟更稳。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LLLMusicIsland.h"
#import "LLLIslandCoreBridge.h"
#import "BaseComponents.h"

@implementation LLLMusicIsland (Compat4)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try {
                [[LLLIslandCoreBridge shared] install];
            } @catch (NSException *e) {
                lllLog(@"4.0 桥接安装异常: %@", e);
            }
        });

        /* 回到前台再兜一次：命令回调若被别处覆盖，这里补回来 */
        [NSNotificationCenter.defaultCenter
         addObserverForName:UIApplicationDidBecomeActiveNotification
                     object:nil
                      queue:NSOperationQueue.mainQueue
                 usingBlock:^(NSNotification *note) {
            @try { [[LLLIslandCoreBridge shared] install]; }
            @catch (NSException *e) { }
        }];
    });
}

@end
