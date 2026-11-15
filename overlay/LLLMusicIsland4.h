//
//  overlay/LLLMusicIsland4.h
//  灵动岛 4.0 扩展（分类实现，不碰主实现）
//

#import "LLLMusicIsland.h"

NS_ASSUME_NONNULL_BEGIN

@interface LLLMusicIsland (Island4)

/// 由 LLLIslandCoreBridge install 时调用一次（幂等）
+ (void)lll4_install;

/// 网易云曲目缺封面时兜底拉一次
+ (void)lll4_ensureCloudArtwork;

/// 岛上「网易云」键的回调（登录面板入口）
+ (void)lll4_setCloudTapHandler:(nullable void (^)(void))handler;
+ (void)lll4_refreshCloudTitle;

@end

NS_ASSUME_NONNULL_END
