#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

/// 播放模式：顺序（播完停）/ 列表循环 / 单曲循环 / 随机
/// 4.0 起这是唯一真源，loopModeSingle / shuffleMode 只是给旧调用方留的镜像字段
 typedef NS_ENUM(NSInteger, LLLPlayMode) {
    LLLPlayModeOrder     = 0,
    LLLPlayModeRepeatAll = 1,
    LLLPlayModeRepeatOne = 2,
    LLLPlayModeShuffle   = 3
};

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
@property (nonatomic, strong) NSArray<NSDictionary *> *cloudSongs;
@property (nonatomic, strong) UISegmentedControl *musicSrcSeg;
@property (nonatomic, assign) NSInteger currentMusicIndex;

/// 4.0：播放模式唯一真源（顺序 / 列表循环 / 单曲循环 / 随机）
@property (nonatomic, assign) LLLPlayMode playMode;

/// 兼容旧字段：由 playMode 同步过来，别直接写它们
@property (nonatomic, assign) BOOL loopModeSingle, shuffleMode, doubleSpeed, isPlaying;
@property (nonatomic, strong) UIButton *playPauseBtn, *speedBtn, *modeBtn;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) AVPlayer *videoMusicPlayer;
@property (nonatomic, strong) AVPlayer *cloudPlayer;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *nowPlayingLabel;
@property (nonatomic, strong) NSTimer *progressTimer;

@property (nonatomic, strong) UIView *playerCard;
@property (nonatomic, strong) NSLayoutConstraint *playerHeight;
@property (nonatomic, strong) UILabel *playerTitle;
@property (nonatomic, strong) UILabel *playerArtist;
@property (nonatomic, strong) UILabel *playerTimeLabel;
@property (nonatomic, strong) UIImageView *playerCover;
@property (nonatomic, strong) UIButton *playerPlayBtn;
@property (nonatomic, strong) UIButton *playerModeBtn;
@property (nonatomic, strong) UIButton *playerCloudBtn;
@property (nonatomic, strong) UISlider *playerProgress;
@property (nonatomic, strong) UISlider *playerVolume;

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
