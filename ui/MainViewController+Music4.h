//
//  MainViewController+Music4.h
//  4.0 音乐页接线
//

#import "MainViewController.h"
#import "LLLIslandCoreBridge.h"
#import "LLLMusicController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (Music4)

/// viewDidLoad 末尾调一次（幂等）
- (void)lll4_installMusicPage;
- (void)lll4_stopLegacyPlayers;

- (void)lll4_showMusicTab;
- (void)lll4_musicSourceChanged:(UISegmentedControl *)seg;
- (void)lll4_reloadMusicTab;
- (void)lll4_musicCellPlay:(UIButton *)sender;
- (void)lll4_didSelectMusicRow:(NSInteger)row;

- (void)lll4_togglePlayPause;
- (void)lll4_next;
- (void)lll4_prev;
- (void)lll4_toggleMode;
- (void)lll4_toggleSpeed;
- (void)lll4_seekRatio:(float)ratio;

- (void)lll4_refreshCard;
- (void)lll4_dataChanged;
- (void)lll4_coreChanged;

@end

NS_ASSUME_NONNULL_END
