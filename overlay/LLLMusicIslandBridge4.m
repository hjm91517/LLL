//
//  overlay/LLLMusicIslandBridge4.m
//  3.12 的 installNowPlayingBridge 在 4.0 里转给 LLLIslandCoreBridge。
//  声明在 ui/LLLCloudLogin.h（岛主实现 import 的就是它）。
//

#import <UIKit/UIKit.h>
#import "MainViewController.h"
#import "LLLCloudLogin.h"
#import "LLLIslandCoreBridge.h"
#import "BaseComponents.h"

@implementation MainViewController (NowPlayingBridgeCompat)

- (void)installNowPlayingBridge {
    [[LLLIslandCoreBridge shared] install];
}

@end
