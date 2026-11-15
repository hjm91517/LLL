//
//  overlay/LLLMusicIsland.m — 4.0 命令桥片段
//
//  这里只放 4.0 需要改动的那一段（buildIfNeeded 里原来调
//  [host installNowPlayingBridge] 的地方），完整文件见仓库主文件。
//
//  注意：本文件不参与编译，仅作改动说明留档。
//
//  ---- 改动前（3.12）----
//  @try {
//      MainViewController *host = [MainViewController cloudHost];
//      if ([host respondsToSelector:@selector(installNowPlayingBridge)]) {
//          [host installNowPlayingBridge];
//      }
//  } @catch (__unused NSException *e) { }
//
//  ---- 改动后（4.0）----
//  @try {
//      [[LLLIslandCoreBridge shared] install];
//  } @catch (__unused NSException *e) { }
//
//  同步要加的 import：
//      #import "LLLIslandCoreBridge.h"
//      #import "LLLMusicIsland4.h"
//
//  以及主实现里三个事件方法改成转桥接层（见下方补丁函数）。
//

#import <UIKit/UIKit.h>
#import "LLLMusicIsland.h"
#import "LLLIslandCoreBridge.h"
#import "LLLMusicIsland4.h"

NS_ASSUME_NONNULL_BEGIN

/// 供主实现 buildIfNeeded 调用的 4.0 桥安装入口
void LLLMusicIslandInstallBridge4(void);

NS_ASSUME_NONNULL_END
