//
//  overlay/LLLMusicIslandBridge4.m
//  编译期替身：MainViewController 上补一个 installNowPlayingBridge，
//  让 3.12 主实现里那句 [host installNowPlayingBridge] 能编过。
//
//  这比整文件重写更安全：主实现一行不动，行为转给 4.0 桥接层。
//

#import <UIKit/UIKit.h>
#import "MainViewController.h"
#import "LLLIslandCoreBridge.h"
#import "BaseComponents.h"

@implementation MainViewController (NowPlayingBridgeCompat)

/// 3.12 的老入口。4.0 里命令桥归 LLLIslandCoreBridge 管，这里只做转发。
- (void)installNowPlayingBridge {
    [[LLLIslandCoreBridge shared] install];
}

@end
