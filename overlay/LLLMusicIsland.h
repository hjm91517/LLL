//
//  LLLMusicIsland.h
//  灵动岛：收起是胶囊（封面 + 歌名 + 波形），点开是播放面板（进度 + 上一首/播放/下一首）
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLMusicIsland : NSObject

/// 兼容旧调用：直接给歌名。歌曲信息齐全时请用 LLLNowPlaying 上报。
+ (void)updateTitle:(nullable NSString *)title playing:(BOOL)playing;

/// 立即收起并隐藏
+ (void)hide;

/// 点胶囊时回调（保留，默认行为是展开）
+ (void)setTapHandler:(nullable void (^)(void))handler;

/// 展开 / 收起
+ (void)toggleExpanded;
+ (void)setExpanded:(BOOL)expanded;

/// v2.2 缓存清理状态合并显示（CacheCleaner 调用，不再自建第二个胶囊）
+ (void)showCacheStatus:(nullable NSString *)text count:(NSUInteger)count isError:(BOOL)isError;

/// 本地 mp4/mov：把播放器画面投到胶囊/展开态的封面位；传 nil 清掉
+ (void)attachVideo:(nullable AVPlayer *)player;

/// 重新读一次 LLLNowPlaying 并刷新
+ (void)refresh;

@end

NS_ASSUME_NONNULL_END
