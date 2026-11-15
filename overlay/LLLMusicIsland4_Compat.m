//
//  overlay/LLLMusicIsland4_Compat.m
//  4.0 运行时兜底：确保命令桥被装上（幂等，晚了也没关系）。
//
//  不在 +load 里直接调 —— dylib 加载期类可能还没完全可用，
//  推迟到主队列第一次空闲时更稳。
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try {
                [[LLLIslandCoreBridge shared] install];
            } @catch (NSException *e) {
                lllLog(@"4.0 桥接安装异常: %@", e);
            }
        });
    });
}

@end
