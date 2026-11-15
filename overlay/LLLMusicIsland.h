//
//  LLLMusicIsland.h
//  灵动岛：收起是胶囊（封面 + 歌名 + 波形），点开是播放面板（进度 + 上一首/播放/下一首）
//
//  4.0 注意事项：
//    · 主实现（LLLMusicIsland.m）里**不新增**方法，新增能力全在分类
//      LLLMusicIsland4 里实现，并通过 LLLIslandCoreBridge 调用。
//      原因：工程开了 -Werror -Wincomplete-implementation，
//      在 .h 里声明了却在主 @implementation 里没定义会直接编译失败。
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLMusicIsland : NSObject

/// 兼容旧调用：直接给歌名。歌曲信息齐全时请用 LLLNowPlaying / LLLPlayerCore 上报。
+ (void)updateTitle:(nullable NSString *)title playing:(BOOL)playing;

/// 立即收起并隐藏
+ (void)hide;

/// 点胶囊时回调（保留，默认行为是展开）
+ (void)setTapHandler:(nullable void (^)(void))handler;

/// 展开 / 收起
+ (void)toggleExpanded;
+ (void)setExpanded:(BOOL)expanded;

/// 缓存清理状态合并显示
+ (void)showCacheStatus:(nullable NSString *)text count:(NSUInteger)count isError:(BOOL)isError;

/// 本地 mp4/mov：把播放器画面投到胶囊/展开态的封面位；传 nil 清掉
+ (void)attachVideo:(nullable AVPlayer *)player;

/// 重新读一次状态并刷新
+ (void)refresh;

@end

NS_ASSUME_NONNULL_END
