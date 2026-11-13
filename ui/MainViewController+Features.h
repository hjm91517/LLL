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
