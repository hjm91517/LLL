#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MainViewController : UIViewController

@property (nonatomic, strong) UITableView *st, *qt, *pt, *pqt, *musict;
@property (nonatomic, strong) UIView *ab, *pab, *musicControlBar;
@property (nonatomic, strong) UIView *settingsView;
@property (nonatomic, strong) UISwitch *perfSwitch, *bgSwitch;
@property (nonatomic, strong) UIVisualEffectView *cardView;
@property (nonatomic, strong) UIImageView *bgImageView;
@property (nonatomic, strong) AVPlayer *bgPlayer;
@property (nonatomic, strong) AVPlayerLayer *bgPlayerLayer;
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UIButton *prevBgBtn, *nextBgBtn, *chooseBgBtn;
@property (nonatomic, strong) UILabel *bgInfoLabel;
@property (nonatomic, strong) UITextField *intervalField;
@property (nonatomic, strong) NSArray<NSString *> *bgFiles;
@property (nonatomic, assign) NSInteger bgCurrentIndex, bgMode;
@property (nonatomic, strong) NSTimer *bgTimer;

@property (nonatomic, strong) NSArray<NSString *> *musicNames, *musicPaths;
@property (nonatomic, assign) NSInteger currentMusicIndex;
@property (nonatomic, assign) BOOL loopModeSingle, shuffleMode, doubleSpeed, isPlaying;
@property (nonatomic, strong) UIButton *playPauseBtn, *speedBtn, *modeBtn;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) AVPlayer *videoMusicPlayer;
@property (nonatomic, strong) AVPlayer *cloudPlayer;
@property (nonatomic, strong) UISlider *volumeSlider;

@property (nonatomic, assign) BOOL bgVideoWasPlaying;

- (void)reloadSrcData;
- (void)reloadPluginData;
- (void)reloadMusicData;
- (void)updateEmpty;
- (void)saveQ;
- (void)loadQ;
- (UIButton *)tBtn:(NSString *)t ico:(NSString *)i act:(SEL)a;
- (UIButton *)aBtn:(NSString *)t ico:(NSString *)i col:(UIColor *)c act:(SEL)a;
- (UITableView *)tv:(NSString *)rid;

@end
