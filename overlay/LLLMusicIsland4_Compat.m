//
//  overlay/LLLMusicIsland4_Compat.m
//  4.0 兼容层：给主实现打补丁，保证 3.12 留下的代码在 4.0 下不炸。
//
//  为什么需要：
//    LLLMusicIsland.m 里有一句 [host installNowPlayingBridge]，
//    4.0 把命令桥搬到了 LLLIslandCoreBridge，MainViewController 的
//    LLLCloudLogin 分类里已无此方法声明 → 编译期 "no visible @interface"。
//    这里用 +load 在编译后不动源码的前提下无法修正编译期错误，
//    因此主实现文件本身已同步改成调桥接层（见 LLLMusicIsland.m 的 buildIfNeeded）。
//
//  本文件只保留运行时兜底：如果宿主还没有桥，就装一个。
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
        @try {
            [[LLLIslandCoreBridge shared] install];
        } @catch (NSException *e) {
            lllLog(@"4.0 桥接安装异常: %@", e);
        }
    });
}

@end
