#import "MainViewController.h"
#import "BaseComponents.h"

typedef NS_ENUM(NSInteger, BGSwitchMode) {
    BGSwitchModeFixed = 0,
    BGSwitchModeTimer
};

@interface MainViewController () <
    UITableViewDataSource,
    UITableViewDelegate,
    UIGestureRecognizerDelegate,
    AVAudioPlayerDelegate
>

@property (nonatomic, strong) NSMutableArray<NSString *> *sn;
@property (nonatomic, strong) NSMutableArray<NSString *> *sp;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *shi;
@property (nonatomic, strong) NSMutableArray<NSString *> *qn;
@property (nonatomic, strong) NSMutableArray<NSString *> *qp;
@property (nonatomic, strong) NSMutableArray<NSString *> *pln;
@property (nonatomic, strong) NSMutableArray<NSString *> *plp;
@property (nonatomic, strong) NSMutableArray<NSString *> *plqn;
@property (nonatomic, strong) NSMutableArray<NSString *> *plqp;

@property (nonatomic, strong) UIButton *tab1, *tab2, *tab3, *tab4, *tab6, *tab7;
@property (nonatomic, strong) UIView *contentContainerView;

- (void)showAlert:(NSString *)t msg:(NSString *)m;
- (void)confirm:(NSString *)t msg:(NSString *)m dest:(BOOL)d cb:(void(^)(void))cb;
- (void)upEmpty:(UITableView *)tv;
- (void)setTab:(UIButton *)tab active:(BOOL)active;
- (void)setHeader:(NSString *)title sub:(NSString *)sub;
- (void)closePanel;
- (void)applyTheme;
- (void)tintSwitchesIn:(UIView *)view color:(UIColor *)color;
- (void)applyVolume;
- (void)volumeChanged:(UISlider *)sender;
- (void)progressSeek:(UISlider *)sender;
- (void)startProgressTimer;
- (void)stopProgressTimer;
- (void)updateProgressUI;
- (void)setupPlayerCard;
- (void)loadLyricsForPath:(NSString *)path;
- (UIButton *)playerButton:(NSString *)icon size:(CGFloat)size side:(CGFloat)side action:(SEL)action;
- (void)saveQ;
- (void)loadQ;
- (void)reloadSrcData;
- (void)reloadPluginData;
- (void)reloadMusicData;
- (void)stopTimer;
- (void)startTimer;
- (void)lllApplySafeAreaPadding;

@end
