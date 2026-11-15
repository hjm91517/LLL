//
//  overlay/LLLMusicIsland4.h
//

#import "LLLMusicIsland.h"

NS_ASSUME_NONNULL_BEGIN

@interface LLLMusicIsland (Island4)

/// 由 LLLIslandCoreBridge install 时调用一次（幂等）
+ (void)lll4_install;

/// 网易云曲目缺封面时兜底拉一次
+ (void)lll4_ensureCloudArtwork;

+ (NSString *)lll4_modeLabel;

@end

NS_ASSUME_NONNULL_END
