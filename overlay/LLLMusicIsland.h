//
//  LLLMusicIsland.h
//  灵动岛：收起是胶囊（封面 + 歌名 + 波形），点开是播放面板（进度 + 上一首/播放/下一首）
//  4.0：封面强制取网易云曲图；控制全部转给 LLLPlayerCore，不再各走一套。
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

/// 4.0：网易云登录入口（展开态第二行按钮），点击调 handler
+ (void)setCloudLoginHandler:(nullable void (^)(void))handler;
/// 登录态变化后刷新按钮文案
+ (void)refreshCloudButton;
/// 播放模式键文案刷新
+ (void)refreshModeButton;

@end

NS_ASSUME_NONNULL_END
