#import "MainViewController.h"

@interface MainViewController (Features)

- (void)playMusicAtIndex:(NSInteger)idx;
- (void)stopMusic;
- (void)nextMusic;
- (void)prevMusic;
- (void)togglePlayPause;
- (void)toggleSpeed;
- (void)switchLoopMode;
- (void)updateMusicUI;
- (void)musicCellPlay:(UIButton *)sender;
- (void)upEmptyMusic;

#pragma mark - 4.0 播放模式

/// 当前是不是网易云在播（cloudPlayer 活着就算）
- (BOOL)lllCloudActive;

/// 当前是否真的在出声：云端看 isPlaying（playCloudSong 会同步），本地看 isPlaying
- (BOOL)lllIsPlaying;

/// 切换播放模式（四态：顺序 / 列表 / 单曲 / 随机），会写偏好并刷新 UI
- (void)lllSetPlayMode:(LLLPlayMode)mode;

/// 统一的索引推进：返回 -1 表示「播到头了，停」
/// @param delta  +1 下一首 / -1 上一首
/// @param isAuto YES = 一首放完自动切（顺序模式会停），NO = 用户手点（顺序模式回到第一首）
- (NSInteger)lllAdvanceIndex:(NSInteger)delta
                        from:(NSInteger)cur
                       count:(NSInteger)count
                        auto:(BOOL)isAuto;

- (void)doInject;
- (void)doClean;
- (void)doKill;
- (void)addToQueue:(UIButton *)b;
- (void)clrQ;

- (void)addPluginToQueue:(UIButton *)b;
- (void)clrPQ;
- (void)injEC;
- (void)injBJ;
- (void)injMisaki;
- (void)injectPluginsWithType:(NSInteger)type;
- (void)injectPersonalSave;
- (void)doInjectPluginsToDir:(NSString *)dir;
- (void)dismissCloudCard;
- (void)searchCloudMusic;
- (void)doCloudSearch;
- (void)packLongPress:(UILongPressGestureRecognizer *)g;
- (void)showLikedSongs;
- (NSString *)summaryText:(NSString *)verb ok:(NSArray *)ok fail:(NSArray *)fail;

@end
