
#import "MainViewController.h"

@interface MainViewController (SettingsBackground)

- (void)setupSettingsView;

- (void)refreshBgFiles;
- (void)updateBackground;
- (void)startBgTimerIfNeeded;
- (void)stopBgTimer;
- (void)stopVideoBackground;
- (void)saveBgState;

- (void)prevBackground;
- (void)nextBackground;
- (void)chooseBackgroundImage;

- (void)modeSegmentChanged:(UISegmentedControl *)sender;
- (void)intervalChanged:(UITextField *)sender;
- (void)updateBgInfoLabel;
- (void)toggleCustomBackground:(UISwitch *)sender;

@end
