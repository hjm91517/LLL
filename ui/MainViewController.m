#import "MainViewController.h"
#import "MainViewController_Private.h"
#import "BaseComponents.h"
#import "ResourceManager.h"
#import "FloatMonitor.h"
#import "PluginInfo.h"
#import "LLLAnim.h"
#import "LLLUiKit.h"
#import "LLLCloudMusic.h"
#import "LLLMusicIsland.h"
#import "LLLNowPlaying.h"
#import <objc/runtime.h>

#import "MainViewController+SettingsBackground.h"
#import "MainViewController+Features.h"

extern void setPerformanceMonitorEnabled(BOOL enabled);
extern BOOL isPerformanceMonitorEnabled(void);

static const int64_t kInterval = (int64_t)(0.2 * NSEC_PER_SEC);


// 屏幕外直接刷（无动画成本）；可见时关掉隐式动画，避免 reload 的淡入卡顿
static void lllReload(UITableView *tv) {
    if (!tv) return;
    if (!tv.window) { [tv reloadData]; return; }
    [UIView performWithoutAnimation:^{
        [tv reloadData];
        [tv layoutIfNeeded];
    }];
}


#pragma mark - 声压条

@interface LLLBarsView : UIView
@property (nonatomic, strong) NSMutableArray<NSNumber *> *levels;
@property (nonatomic, strong) UIColor *barColor;
- (void)setLevel:(CGFloat)v index:(NSInteger)i;
- (void)setLevels:(const CGFloat *)vals count:(NSInteger)n;
@end

@implementation LLLBarsView
- (instancetype)initWithFrame:(CGRect)f {
    if (self = [super initWithFrame:f]) {
        _levels = [NSMutableArray array];
        for (int i = 0; i < 16; i++) [_levels addObject:@0.05];
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        _barColor = LLLAccentColor();
    }
    return self;
}
- (void)setLevel:(CGFloat)v index:(NSInteger)i {
    if (i < 0 || i >= (NSInteger)_levels.count) return;
    _levels[(NSUInteger)i] = @(v);
}

// 16 条一起设完只重绘一次，别每条都 setNeedsDisplay
- (void)setLevels:(const CGFloat *)vals count:(NSInteger)n {
    NSInteger max = MIN(n, (NSInteger)_levels.count);
    for (NSInteger i = 0; i < max; i++) _levels[(NSUInteger)i] = @(vals[i]);
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    NSUInteger n = _levels.count;
    if (!n) return;
    CGFloat w = rect.size.width / n;
    UIColor *c = _barColor ?: LLLAccentColor();
    for (NSUInteger i = 0; i < n; i++) {
        CGFloat h = MAX(2.0, [_levels[i] doubleValue] * rect.size.height);
        CGRect r = CGRectMake(i * w + w * 0.22, rect.size.height - h, w * 0.56, h);
        UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:w * 0.28];
        [c setFill];
        [p fill];
    }
}
@end

#pragma mark - LRC 解析

static NSArray<NSDictionary *> *LLLParseLRC(NSString *path) {
    NSString *txt = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!txt.length) txt = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    if (!txt.length) return nil;

    NSMutableArray *out = [NSMutableArray array];
    NSRegularExpression *re =
        [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d+):(\\d+)(?:[.:](\\d+))?\\](.*)"
                                                  options:0 error:nil];
    for (NSString *line in [txt componentsSeparatedByCharactersInSet:
                            [NSCharacterSet newlineCharacterSet]]) {
        NSTextCheckingResult *m = [re firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!m) continue;
        NSInteger mm = [[line substringWithRange:[m rangeAtIndex:1]] integerValue];
        NSInteger ss = [[line substringWithRange:[m rangeAtIndex:2]] integerValue];
        NSString *body = [[line substringWithRange:[m rangeAtIndex:4]]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!body.length) continue;
        [out addObject:@{ @"t": @(mm * 60 + ss), @"s": body }];
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"t"] compare:b[@"t"]];
    }];
    return out;
}

@implementation MainViewController {
    dispatch_source_t _timer;
    NSUInteger _delCount;
    BOOL _dis;
    UIView *_indicator;      // 侧栏滑块
    UILabel *_headerTitle;   // 顶部主标题
    UILabel *_headerSub;     // 顶部副标题（显示探测到的注入目标）
    LLLBarsView *_bars;
    UILabel *_lyrics;
    NSArray *_lrcLines;
    NSInteger _lrcIndex;
    NSInteger _lastMusicIndex;
}

- (instancetype)init {
    if (self = [super init]) {
        _sn   = [NSMutableArray new]; _sp   = [NSMutableArray new]; _shi  = [NSMutableArray new];
        _qn   = [NSMutableArray new]; _qp   = [NSMutableArray new];
        _pln  = [NSMutableArray new]; _plp  = [NSMutableArray new];
        _plqn = [NSMutableArray new]; _plqp = [NSMutableArray new];
        _musicNames = @[];
        _musicPaths = @[];
        _currentMusicIndex = -1;
        _loopModeSingle = NO;
        _shuffleMode = NO;
        _doubleSpeed = NO;
        _isPlaying = NO;
        _bgVideoWasPlaying = NO;

        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _bgMode = [def integerForKey:@"BGSwitchMode"];
        _bgCurrentIndex = [def integerForKey:@"BGCurrentIndex"];
    }
    return self;
}

- (void)dealloc {
    _dis = YES;
    if (_timer) dispatch_source_cancel(_timer);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopMusic];
    [self.bgTimer invalidate];
    [self stopVideoBackground];
    [MaterialHUD dismiss];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bgTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    _cardView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    _cardView.layer.cornerRadius = 26;
    _cardView.layer.cornerCurve = kCACornerCurveContinuous;
    _cardView.layer.borderWidth = kHairline;
    _cardView.layer.borderColor = kCardBorderColor.CGColor;
    _cardView.clipsToBounds = YES;
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_cardView];

    CGFloat margin = 20;
    /* 【占全屏 / 刘海遮挡修复】卡片上下留出安全区：以前顶部只留 20pt，
       全面屏上标题和 tab 直接压在状态栏/灵动岛下面，看着像"被占满屏"还点不到 */
    NSLayoutConstraint *ct = [_cardView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:margin];
    NSLayoutConstraint *cb = [_cardView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-margin];
    [NSLayoutConstraint activateConstraints:@[
        [_cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        ct,
        cb
    ]];
    objc_setAssociatedObject(self, "lllCardTop", ct, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, "lllCardBottom", cb, OBJC_ASSOCIATION_RETAIN);
    [self lllApplySafeAreaPadding];

    _bgImageView = [[UIImageView alloc] init];
    _bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    _bgImageView.clipsToBounds = YES;
    _bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _bgImageView.hidden = YES;
    [_cardView.contentView insertSubview:_bgImageView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [_bgImageView.topAnchor constraintEqualToAnchor:_cardView.contentView.topAnchor],
        [_bgImageView.bottomAnchor constraintEqualToAnchor:_cardView.contentView.bottomAnchor],
        [_bgImageView.leadingAnchor constraintEqualToAnchor:_cardView.contentView.leadingAnchor],
        [_bgImageView.trailingAnchor constraintEqualToAnchor:_cardView.contentView.trailingAnchor]
    ]];

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView.contentView addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:_cardView.contentView.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:_cardView.contentView.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:_cardView.contentView.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:_cardView.contentView.bottomAnchor]
    ]];

    UILabel *tit = [UILabel new];
    tit.text = @"资源管理";
    tit.textColor = UIColor.whiteColor;
    tit.font = [UIFont systemFontOfSize:kTitleFontSize weight:UIFontWeightBold];
    tit.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:tit];
    _headerTitle = tit;

    // 副标题直接显示探测到的注入目录，版本对不对一眼能看出来
    UILabel *subt = [UILabel new];
    subt.text = [NSString stringWithFormat:@"目标 · %@", targetPathDisplayName()];
    subt.textColor = kSecondaryTextColor;
    subt.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    subt.lineBreakMode = NSLineBreakByTruncatingMiddle;
    subt.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:subt];
    _headerSub = subt;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:cfg] forState:UIControlStateNormal];
    } else {
        [closeBtn setTitle:@"×" forState:UIControlStateNormal];
    }
    closeBtn.tintColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    closeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    closeBtn.layer.cornerRadius = 15;
    closeBtn.layer.cornerCurve = kCACornerCurveContinuous;
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:closeBtn];

    UIView *div = [UIView new];
    div.backgroundColor = kDividerColor;
    div.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:div];

    UIView *sidebar = [UIView new];
    sidebar.backgroundColor = kSidebarBackgroundColor;
    sidebar.layer.cornerRadius = kSidebarCornerRadius;
    sidebar.layer.cornerCurve = kCACornerCurveContinuous;
    sidebar.layer.borderWidth = kHairline;
    sidebar.layer.borderColor = kCardBorderColor.CGColor;
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:sidebar];

    // 选中滑块：在 stack 之前加进去，保证压在按钮下面
    _indicator = [UIView new];
    _indicator.backgroundColor = kTabActivePillColor;
    _indicator.layer.cornerRadius = kPillCornerRadius;
    _indicator.layer.cornerCurve = kCACornerCurveContinuous;
    _indicator.layer.borderWidth = kHairline;
    _indicator.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    _indicator.hidden = YES;
    _indicator.userInteractionEnabled = NO;
    [sidebar addSubview:_indicator];

    UIStackView *sv = [[UIStackView alloc] init];
    sv.axis = UILayoutConstraintAxisVertical;
    sv.spacing = 6;
    sv.alignment = UIStackViewAlignmentCenter;
    sv.distribution = UIStackViewDistributionFillEqually;
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    [sidebar addSubview:sv];

    _tab1 = [self tBtn:@"材质包" ico:@"cube.fill" act:@selector(showSrcTab)];
    _tab2 = [self tBtn:@"注入队列" ico:@"tray.and.arrow.down.fill" act:@selector(showQueueTab)];
    _tab3 = [self tBtn:@"mcp插件" ico:@"puzzlepiece.fill" act:@selector(showPluginTab)];
    _tab4 = [self tBtn:@"mcp注入" ico:@"arrow.right.doc.on.clipboard" act:@selector(showPluginQueueTab)];
    _tab6 = [self tBtn:@"音乐播放器" ico:@"music.note.list" act:@selector(showMusicTab)];
    _tab7 = [self tBtn:@"设置" ico:@"gearshape.fill" act:@selector(showSettingsTab)];

    for (UIButton *b in @[_tab1, _tab2, _tab3, _tab4, _tab6, _tab7]) {
        [sv addArrangedSubview:b];
    }

    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:12],
        [sv.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor constant:-12],
        [sv.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:8],
        [sv.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-8]
    ]];

    UIView *cv = [UIView new];
    cv.backgroundColor = kContentBackgroundColor;
    cv.layer.cornerRadius = kContentCornerRadius;
    cv.layer.cornerCurve = kCACornerCurveContinuous;
    cv.layer.borderWidth = kHairline;
    cv.layer.borderColor = kCardBorderColor.CGColor;
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:cv];
    self.contentContainerView = cv;

    _st  = [self tv:@"s"];   _st.hidden = NO;
    _qt  = [self tv:@"q"];   _qt.hidden = YES; _qt.editing = YES;
    _pt  = [self tv:@"p"];   _pt.hidden = YES;
    _pqt = [self tv:@"pq"];  _pqt.hidden = YES; _pqt.editing = YES;
    _musict = [self tv:@"music"]; _musict.hidden = YES;

    for (UITableView *t in @[_st, _qt, _pt, _pqt]) {
        [cv addSubview:t];
        [NSLayoutConstraint activateConstraints:@[
            [t.topAnchor constraintEqualToAnchor:cv.topAnchor constant:6],
            [t.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor],
            [t.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor]
        ]];
    }

    [self setupPlayerCard];
    [cv addSubview:_musict];
    [NSLayoutConstraint activateConstraints:@[
        [_musict.topAnchor constraintEqualToAnchor:_playerCard.bottomAnchor constant:6],
        [_musict.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor],
        [_musict.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor]
    ]];

    [self setupSettingsView];

    _ab = [UIView new]; _ab.translatesAutoresizingMaskIntoConstraints = NO; _ab.hidden = YES; [cv addSubview:_ab];
    UIButton *clr   = [self aBtn:@"清空" ico:@"trash" col:kDestructiveButtonColor act:@selector(clrQ)];
    UIButton *clean = [self aBtn:@"清理目标" ico:@"folder.badge.minus" col:kDestructiveButtonColor act:@selector(doClean)];
    UIButton *kill  = [self aBtn:@"清理缓存" ico:@"xmark.bin" col:kDestructiveButtonColor act:@selector(doKill)];
    UIButton *inj   = [self aBtn:@"开始注入" ico:@"play.fill" col:kAccentBlue act:@selector(doInject)];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    lp.minimumPressDuration = 0.5;
    [kill addGestureRecognizer:lp];
    [_ab addSubview:clr]; [_ab addSubview:clean]; [_ab addSubview:kill]; [_ab addSubview:inj];

    _pab = [UIView new]; _pab.translatesAutoresizingMaskIntoConstraints = NO; _pab.hidden = YES; [cv addSubview:_pab];
    UIButton *pclr = [self aBtn:@"清空" ico:@"trash" col:kDestructiveButtonColor act:@selector(clrPQ)];
    UIButton *ec   = [self aBtn:@"注入 EC" ico:@"play.fill" col:kAccentBlue act:@selector(injEC)];
    UIButton *bj   = [self aBtn:@"注入布吉岛" ico:@"play.fill" col:kAccentOrange act:@selector(injBJ)];
    UIButton *ms   = [self aBtn:@"注入 Misaki" ico:@"play.fill" col:kAccentGreen act:@selector(injMisaki)];
    UIButton *psv  = [self aBtn:@"个人存档" ico:@"person.crop.circle.badge.plus"
                            col:[UIColor colorWithRed:0.62 green:0.40 blue:1.00 alpha:1.0]
                           act:@selector(injectPersonalSave)];
    [_pab addSubview:pclr]; [_pab addSubview:ec]; [_pab addSubview:bj];
    [_pab addSubview:ms];   [_pab addSubview:psv];

    _musicControlBar = [UIView new]; _musicControlBar.translatesAutoresizingMaskIntoConstraints = NO; _musicControlBar.hidden = YES;
    _musicControlBar.backgroundColor = kBarBackgroundColor;
    _musicControlBar.layer.cornerRadius = kMusicControlBarRadius;
    _musicControlBar.layer.cornerCurve = kCACornerCurveContinuous;
    _musicControlBar.layer.borderWidth = kHairline;
    _musicControlBar.layer.borderColor = kCardBorderColor.CGColor;
    [cv addSubview:_musicControlBar];

    UIButton *prevBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    prevBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) [prevBtn setImage:[UIImage systemImageNamed:@"backward.fill"] forState:UIControlStateNormal];
    prevBtn.tintColor = UIColor.whiteColor;
    prevBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    prevBtn.layer.cornerRadius = 20; prevBtn.clipsToBounds = YES;
    [prevBtn addTarget:self action:@selector(prevMusic) forControlEvents:UIControlEventTouchUpInside];
    [_musicControlBar addSubview:prevBtn];

    _playPauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _playPauseBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) [_playPauseBtn setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    _playPauseBtn.tintColor = UIColor.whiteColor; _playPauseBtn.backgroundColor = kAccentBlue;
    _playPauseBtn.layer.cornerRadius = 24; _playPauseBtn.clipsToBounds = NO;
    LLLGlow(_playPauseBtn, kAccentBlue, 14, 0.55);
    [_playPauseBtn addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    [_musicControlBar addSubview:_playPauseBtn];

    UIButton *nextBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    nextBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) [nextBtn setImage:[UIImage systemImageNamed:@"forward.fill"] forState:UIControlStateNormal];
    nextBtn.tintColor = UIColor.whiteColor; nextBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    nextBtn.layer.cornerRadius = 20; nextBtn.clipsToBounds = YES;
    [nextBtn addTarget:self action:@selector(nextMusic) forControlEvents:UIControlEventTouchUpInside];
    [_musicControlBar addSubview:nextBtn];

    _speedBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _speedBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) [_speedBtn setImage:[UIImage systemImageNamed:@"speedometer"] forState:UIControlStateNormal];
    [_speedBtn setTitle:@"1x" forState:UIControlStateNormal];
    _speedBtn.tintColor = UIColor.whiteColor; _speedBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    _speedBtn.layer.cornerRadius = 20; _speedBtn.clipsToBounds = YES;
    _speedBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [_speedBtn addTarget:self action:@selector(toggleSpeed) forControlEvents:UIControlEventTouchUpInside];
    [_musicControlBar addSubview:_speedBtn];

    _modeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _modeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) [_modeBtn setImage:[UIImage systemImageNamed:@"repeat"] forState:UIControlStateNormal];
    [_modeBtn setTitle:@"顺序" forState:UIControlStateNormal];
    _modeBtn.tintColor = UIColor.whiteColor; _modeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    _modeBtn.layer.cornerRadius = 20; _modeBtn.clipsToBounds = YES;
    _modeBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [_modeBtn addTarget:self action:@selector(switchLoopMode) forControlEvents:UIControlEventTouchUpInside];
    [_musicControlBar addSubview:_modeBtn];

    // 正在播放
    _nowPlayingLabel = [[UILabel alloc] init];
    _nowPlayingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nowPlayingLabel.text = @"未在播放";
    _nowPlayingLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _nowPlayingLabel.textColor = UIColor.whiteColor;
    _nowPlayingLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_musicControlBar addSubview:_nowPlayingLabel];

    // 进度条
    _progressSlider = [[UISlider alloc] init];
    _progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _progressSlider.minimumValue = 0.0f;
    _progressSlider.maximumValue = 1.0f;
    _progressSlider.value = 0;
    _progressSlider.minimumTrackTintColor = LLLAccentColor();
    _progressSlider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.18];
    _progressSlider.thumbTintColor = UIColor.whiteColor;
    [_progressSlider addTarget:self action:@selector(progressSeek:) forControlEvents:UIControlEventTouchUpInside];
    [_progressSlider addTarget:self action:@selector(progressSeek:) forControlEvents:UIControlEventTouchUpOutside];
    [_musicControlBar addSubview:_progressSlider];

    // 音量条
    _volumeSlider = [[UISlider alloc] init];
    _volumeSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _volumeSlider.minimumValue = 0.0f;
    _volumeSlider.maximumValue = 1.0f;
    float savedVol = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];
    _volumeSlider.value = (savedVol > 0.001f) ? savedVol : 0.8f;
    _volumeSlider.minimumTrackTintColor = LLLAccentColor();
    _volumeSlider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.18];
    _volumeSlider.thumbTintColor = UIColor.whiteColor;
    [_volumeSlider addTarget:self action:@selector(volumeChanged:) forControlEvents:UIControlEventValueChanged];
    [_musicControlBar addSubview:_volumeSlider];

    UIButton *cloudBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cloudBtn.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
        [cloudBtn setImage:[UIImage systemImageNamed:@"cloud.fill" withConfiguration:cfg]
                  forState:UIControlStateNormal];
    }
    [cloudBtn setTitle:@"云" forState:UIControlStateNormal];
    cloudBtn.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    cloudBtn.tintColor = UIColor.whiteColor;
    cloudBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    cloudBtn.layer.cornerRadius = 16;
    [cloudBtn addTarget:self action:@selector(openCloudMusic) forControlEvents:UIControlEventTouchUpInside];
    [_musicControlBar addSubview:cloudBtn];

    [NSLayoutConstraint activateConstraints:@[
        [_nowPlayingLabel.leadingAnchor constraintEqualToAnchor:_musicControlBar.leadingAnchor constant:20],
        [_nowPlayingLabel.topAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:10],
        [_nowPlayingLabel.trailingAnchor constraintEqualToAnchor:_musicControlBar.trailingAnchor constant:-20],
        [_nowPlayingLabel.heightAnchor constraintEqualToConstant:18],

        [_progressSlider.leadingAnchor constraintEqualToAnchor:_musicControlBar.leadingAnchor constant:18],
        [_progressSlider.trailingAnchor constraintEqualToAnchor:_musicControlBar.trailingAnchor constant:-18],
        [_progressSlider.topAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:34],
        [_progressSlider.heightAnchor constraintEqualToConstant:18],

        [_volumeSlider.leadingAnchor constraintEqualToAnchor:_musicControlBar.leadingAnchor constant:20],
        [_volumeSlider.bottomAnchor constraintEqualToAnchor:_musicControlBar.bottomAnchor constant:-14],
        [_volumeSlider.heightAnchor constraintEqualToConstant:26],
        [_volumeSlider.trailingAnchor constraintEqualToAnchor:cloudBtn.leadingAnchor constant:-12],

        [cloudBtn.trailingAnchor constraintEqualToAnchor:_musicControlBar.trailingAnchor constant:-16],
        [cloudBtn.bottomAnchor constraintEqualToAnchor:_musicControlBar.bottomAnchor constant:-10],
        [cloudBtn.widthAnchor constraintEqualToConstant:44],
        [cloudBtn.heightAnchor constraintEqualToConstant:34],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [_ab.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:10],
        [_ab.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-10],
        [_ab.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-12],
        [_ab.heightAnchor constraintEqualToConstant:50],

        [_pab.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:10],
        [_pab.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-10],
        [_pab.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-12],
        [_pab.heightAnchor constraintEqualToConstant:50],

        [_musicControlBar.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:10],
        [_musicControlBar.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-10],
        [_musicControlBar.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-12],
        [_musicControlBar.heightAnchor constraintEqualToConstant:150],

        [clr.leadingAnchor constraintEqualToAnchor:_ab.leadingAnchor],
        [clr.centerYAnchor constraintEqualToAnchor:_ab.centerYAnchor],
        [clr.heightAnchor constraintEqualToConstant:40],
        [clean.leadingAnchor constraintEqualToAnchor:clr.trailingAnchor constant:8],
        [clean.centerYAnchor constraintEqualToAnchor:_ab.centerYAnchor],
        [clean.heightAnchor constraintEqualToConstant:40],
        [clean.widthAnchor constraintEqualToAnchor:clr.widthAnchor],
        [kill.leadingAnchor constraintEqualToAnchor:clean.trailingAnchor constant:8],
        [kill.centerYAnchor constraintEqualToAnchor:_ab.centerYAnchor],
        [kill.heightAnchor constraintEqualToConstant:40],
        [kill.widthAnchor constraintEqualToAnchor:clr.widthAnchor],
        [inj.leadingAnchor constraintEqualToAnchor:kill.trailingAnchor constant:8],
        [inj.trailingAnchor constraintEqualToAnchor:_ab.trailingAnchor],
        [inj.centerYAnchor constraintEqualToAnchor:_ab.centerYAnchor],
        [inj.heightAnchor constraintEqualToConstant:40],

        [pclr.leadingAnchor constraintEqualToAnchor:_pab.leadingAnchor],
        [pclr.centerYAnchor constraintEqualToAnchor:_pab.centerYAnchor],
        [pclr.heightAnchor constraintEqualToConstant:40],
        [ec.leadingAnchor constraintEqualToAnchor:pclr.trailingAnchor constant:8],
        [ec.centerYAnchor constraintEqualToAnchor:_pab.centerYAnchor],
        [ec.heightAnchor constraintEqualToConstant:40],
        [ec.widthAnchor constraintEqualToAnchor:pclr.widthAnchor],
        [bj.leadingAnchor constraintEqualToAnchor:ec.trailingAnchor constant:8],
        [bj.centerYAnchor constraintEqualToAnchor:_pab.centerYAnchor],
        [bj.heightAnchor constraintEqualToConstant:40],
        [bj.widthAnchor constraintEqualToAnchor:pclr.widthAnchor],
        [ms.leadingAnchor constraintEqualToAnchor:bj.trailingAnchor constant:8],
        [ms.centerYAnchor constraintEqualToAnchor:_pab.centerYAnchor],
        [ms.heightAnchor constraintEqualToConstant:40],
        [ms.widthAnchor constraintEqualToAnchor:pclr.widthAnchor],

        [psv.leadingAnchor constraintEqualToAnchor:ms.trailingAnchor constant:8],
        [psv.trailingAnchor constraintEqualToAnchor:_pab.trailingAnchor],
        [psv.centerYAnchor constraintEqualToAnchor:_pab.centerYAnchor],
        [psv.heightAnchor constraintEqualToConstant:40],
        [psv.widthAnchor constraintEqualToAnchor:pclr.widthAnchor],

        [prevBtn.leadingAnchor constraintEqualToAnchor:_musicControlBar.leadingAnchor constant:20],
        [prevBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:82],
        [prevBtn.widthAnchor constraintEqualToConstant:40],
        [prevBtn.heightAnchor constraintEqualToConstant:40],

        [_speedBtn.leadingAnchor constraintEqualToAnchor:prevBtn.trailingAnchor constant:12],
        [_speedBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:82],
        [_speedBtn.widthAnchor constraintEqualToConstant:52],
        [_speedBtn.heightAnchor constraintEqualToConstant:40],

        [_playPauseBtn.centerXAnchor constraintEqualToAnchor:_musicControlBar.centerXAnchor],
        [_playPauseBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:82],
        [_playPauseBtn.widthAnchor constraintEqualToConstant:48],
        [_playPauseBtn.heightAnchor constraintEqualToConstant:48],

        [_modeBtn.trailingAnchor constraintEqualToAnchor:nextBtn.leadingAnchor constant:-12],
        [_modeBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:82],
        [_modeBtn.widthAnchor constraintEqualToConstant:52],
        [_modeBtn.heightAnchor constraintEqualToConstant:40],

        [nextBtn.trailingAnchor constraintEqualToAnchor:_musicControlBar.trailingAnchor constant:-20],
        [nextBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.topAnchor constant:82],
        [nextBtn.widthAnchor constraintEqualToConstant:40],
        [nextBtn.heightAnchor constraintEqualToConstant:40]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [tit.topAnchor constraintEqualToAnchor:content.topAnchor constant:18],
        [tit.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:22],

        [subt.topAnchor constraintEqualToAnchor:tit.bottomAnchor constant:2],
        [subt.leadingAnchor constraintEqualToAnchor:tit.leadingAnchor],
        [subt.trailingAnchor constraintLessThanOrEqualToAnchor:closeBtn.leadingAnchor constant:-10],

        [closeBtn.centerYAnchor constraintEqualToAnchor:tit.centerYAnchor],
        [closeBtn.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
        [closeBtn.widthAnchor constraintEqualToConstant:30],
        [closeBtn.heightAnchor constraintEqualToConstant:30],

        [div.topAnchor constraintEqualToAnchor:subt.bottomAnchor constant:12],
        [div.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [div.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [div.heightAnchor constraintEqualToConstant:0.5],
        [sidebar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [sidebar.topAnchor constraintEqualToAnchor:div.bottomAnchor constant:16],
        [sidebar.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],
        [sidebar.widthAnchor constraintEqualToConstant:120],
        [cv.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:12],
        [cv.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [cv.topAnchor constraintEqualToAnchor:sidebar.topAnchor],
        [cv.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor]
    ]];

    NSLayoutConstraint *bot = [_st.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-6];
    [NSLayoutConstraint activateConstraints:@[bot]];
    objc_setAssociatedObject(self, "bot", bot, OBJC_ASSOCIATION_RETAIN);

    [self loadQ];
    [self updateEmpty];
    [self reloadSrcData];
    [self reloadPluginData];
    [self reloadMusicData];
    [self refreshBgFiles];
    [self updateBackground];

    // 灵动岛自己处理展开/收起，这里不再抢点击
    [LLLMusicIsland setTapHandler:nil];

    // 首次布局后把侧栏滑块摆到「材质包」上
    __weak typeof(self) w = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(w) s = w;
        if (!s) return;
        [s setTab:s.tab1 active:YES];
        [s applyTheme];
        [s applyVolume];
    });
}

- (void)loadLyricsForPath:(NSString *)path {
    _lrcLines = nil;
    _lrcIndex = -1;
    if (_lyrics) _lyrics.text = @"";
    if (!path.length) return;
    NSString *lrc = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"lrc"];
    _lrcLines = LLLParseLRC(lrc);
    if (_lrcLines.count) _lyrics.text = _lrcLines.firstObject[@"s"];
}

- (void)setupPlayerCard {
    _playerCard = [UIView new];
    _playerCard.translatesAutoresizingMaskIntoConstraints = NO;
    _playerCard.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    _playerCard.layer.cornerRadius = 18;
    _playerCard.layer.cornerCurve = kCACornerCurveContinuous;
    _playerCard.layer.borderWidth = kHairline;
    _playerCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
    _playerCard.clipsToBounds = YES;
    _playerCard.hidden = YES;
    UIVisualEffectView *pe = [[UIVisualEffectView alloc] initWithEffect:
                              [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    pe.translatesAutoresizingMaskIntoConstraints = NO;
    pe.userInteractionEnabled = NO;
    [_playerCard addSubview:pe];

    CAGradientLayer *gl = [CAGradientLayer layer];
    gl.colors = @[ (id)[LLLAccentColor() colorWithAlphaComponent:0.28].CGColor,
                   (id)[UIColor clearColor].CGColor ];
    gl.startPoint = CGPointMake(0, 0);
    gl.endPoint = CGPointMake(1, 1);
    gl.frame = CGRectMake(0, 0, 400, 400);
    [_playerCard.layer insertSublayer:gl atIndex:0];

    [self.contentContainerView addSubview:_playerCard];

    _playerHeight = [_playerCard.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [_playerCard.topAnchor constraintEqualToAnchor:self.contentContainerView.topAnchor constant:6],
        [_playerCard.leadingAnchor constraintEqualToAnchor:self.contentContainerView.leadingAnchor constant:6],
        [_playerCard.trailingAnchor constraintEqualToAnchor:self.contentContainerView.trailingAnchor constant:-6],
        _playerHeight
    ]];

    // 封面
    _playerCover = [[UIImageView alloc] init];
    _playerCover.translatesAutoresizingMaskIntoConstraints = NO;
    _playerCover.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    _playerCover.layer.cornerRadius = 42;      // 84/2 → 圆形唱盘
    _playerCover.layer.cornerCurve = kCACornerCurveContinuous;
    _playerCover.clipsToBounds = YES;
    _playerCover.contentMode = UIViewContentModeCenter;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:34 weight:UIImageSymbolWeightMedium];
        _playerCover.image = [UIImage systemImageNamed:@"music.note" withConfiguration:cfg];
        _playerCover.tintColor = [UIColor colorWithWhite:0.85 alpha:1];
    }
    _playerCover.layer.borderWidth = 1;
    _playerCover.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    [_playerCard addSubview:_playerCover];

    _playerTitle = [UILabel new];
    _playerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _playerTitle.text = @"未在播放";
    _playerTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _playerTitle.textColor = UIColor.whiteColor;
    _playerTitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [_playerCard addSubview:_playerTitle];

    _playerArtist = [UILabel new];
    _playerArtist.translatesAutoresizingMaskIntoConstraints = NO;
    _playerArtist.text = @"本地音乐";
    _playerArtist.font = [UIFont systemFontOfSize:12];
    _playerArtist.textColor = kSecondaryTextColor;
    [_playerCard addSubview:_playerArtist];

    _playerProgress = [[UISlider alloc] init];
    _playerProgress.translatesAutoresizingMaskIntoConstraints = NO;
    _playerProgress.minimumValue = 0; _playerProgress.maximumValue = 1; _playerProgress.value = 0;
    _playerProgress.minimumTrackTintColor = LLLAccentColor();
    _playerProgress.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.18];
    _playerProgress.thumbTintColor = UIColor.whiteColor;
    [_playerProgress addTarget:self action:@selector(progressSeek:) forControlEvents:UIControlEventTouchUpInside];
    [_playerProgress addTarget:self action:@selector(progressSeek:) forControlEvents:UIControlEventTouchUpOutside];
    [_playerCard addSubview:_playerProgress];

    _playerTimeLabel = [UILabel new];
    _playerTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _playerTimeLabel.text = @"0:00 / 0:00";
    _playerTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
    _playerTimeLabel.textColor = kSecondaryTextColor;
    _playerTimeLabel.textAlignment = NSTextAlignmentRight;
    [_playerCard addSubview:_playerTimeLabel];

    // 传输控制
    UIButton *prev = [self playerButton:@"backward.fill" size:20 side:44 action:@selector(prevMusic)];
    _playerPlayBtn = [self playerButton:@"play.fill" size:24 side:58 action:@selector(togglePlayPause)];
    _playerPlayBtn.backgroundColor = LLLAccentColor();
    LLLGlow(_playerPlayBtn, LLLAccentColor(), 14, 0.5);
    UIButton *next = [self playerButton:@"forward.fill" size:20 side:44 action:@selector(nextMusic)];
    _playerModeBtn = [self playerButton:@"repeat" size:18 side:44 action:@selector(switchLoopMode)];

    // 网易云入口（登录 / 我喜欢的 / 搜索）
    _playerCloudBtn = [self playerButton:@"cloud.fill" size:15 side:34 action:@selector(openCloudMusic)];
    _playerCloudBtn.backgroundColor = [LLLAccentColor() colorWithAlphaComponent:0.28];
    /* v2.2 用户反馈找不到入口：改为带文字的「网易云」按钮 */
    [_playerCloudBtn setTitle:@"网易云" forState:UIControlStateNormal];
    _playerCloudBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [_playerCloudBtn setImage:nil forState:UIControlStateNormal];
    _playerCloudBtn.layer.cornerRadius = 17;
    for (NSLayoutConstraint *c in _playerCloudBtn.constraints) {
        if (c.firstAttribute == NSLayoutAttributeWidth) c.constant = 78;
    }
    [_playerCard addSubview:_playerCloudBtn];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[prev, _playerPlayBtn, next, _playerModeBtn]];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionEqualSpacing;
    row.spacing = 20;
    [_playerCard addSubview:row];

    _playerVolume = [[UISlider alloc] init];
    _playerVolume.translatesAutoresizingMaskIntoConstraints = NO;
    _playerVolume.minimumValue = 0; _playerVolume.maximumValue = 1;
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];
    _playerVolume.value = (v > 0.001f) ? v : 0.8f;
    _playerVolume.minimumTrackTintColor = LLLAccentColor();
    _playerVolume.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.18];
    _playerVolume.thumbTintColor = UIColor.whiteColor;
    [_playerVolume addTarget:self action:@selector(volumeChanged:) forControlEvents:UIControlEventValueChanged];
    [_playerCard addSubview:_playerVolume];

    _bars = [[LLLBarsView alloc] initWithFrame:CGRectZero];
    _bars.translatesAutoresizingMaskIntoConstraints = NO;
    [_playerCard addSubview:_bars];

    _lyrics = [UILabel new];
    _lyrics.translatesAutoresizingMaskIntoConstraints = NO;
    _lyrics.text = @"";
    _lyrics.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _lyrics.textColor = [UIColor colorWithWhite:0.85 alpha:1];
    _lyrics.textAlignment = NSTextAlignmentCenter;
    _lyrics.numberOfLines = 1;
    _lyrics.lineBreakMode = NSLineBreakByTruncatingTail;
    [_playerCard addSubview:_lyrics];

    UIImageView *volIcon = [[UIImageView alloc] init];
    volIcon.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
        volIcon.image = [UIImage systemImageNamed:@"speaker.wave.2.fill" withConfiguration:cfg];
        volIcon.tintColor = kSecondaryTextColor;
    }
    [_playerCard addSubview:volIcon];

    [NSLayoutConstraint activateConstraints:@[
        [_playerCover.leadingAnchor constraintEqualToAnchor:_playerCard.leadingAnchor constant:18],
        [_playerCover.topAnchor constraintEqualToAnchor:_playerCard.topAnchor constant:18],
        [_playerCover.widthAnchor constraintEqualToConstant:84],
        [_playerCover.heightAnchor constraintEqualToConstant:84],

        [_playerTitle.leadingAnchor constraintEqualToAnchor:_playerCover.trailingAnchor constant:14],
        [_playerTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_playerCloudBtn.leadingAnchor constant:-10],

        [_playerCloudBtn.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-16],
        [_playerCloudBtn.topAnchor constraintEqualToAnchor:_playerCard.topAnchor constant:18],
        [_playerTitle.topAnchor constraintEqualToAnchor:_playerCover.topAnchor constant:8],

        [_playerArtist.leadingAnchor constraintEqualToAnchor:_playerTitle.leadingAnchor],
        [_playerArtist.trailingAnchor constraintEqualToAnchor:_playerTitle.trailingAnchor],
        [_playerArtist.topAnchor constraintEqualToAnchor:_playerTitle.bottomAnchor constant:4],

        [_playerProgress.leadingAnchor constraintEqualToAnchor:_playerCard.leadingAnchor constant:18],
        [_playerProgress.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-18],
        [_playerProgress.topAnchor constraintEqualToAnchor:_playerCover.bottomAnchor constant:14],
        [_playerProgress.heightAnchor constraintEqualToConstant:22],

        [_playerTimeLabel.trailingAnchor constraintEqualToAnchor:_playerProgress.trailingAnchor],
        [_playerTimeLabel.topAnchor constraintEqualToAnchor:_playerProgress.bottomAnchor constant:2],
        [_playerTimeLabel.widthAnchor constraintEqualToConstant:120],

        [row.centerXAnchor constraintEqualToAnchor:_playerCard.centerXAnchor],
        [row.topAnchor constraintEqualToAnchor:_playerTimeLabel.bottomAnchor constant:10],
        [row.heightAnchor constraintEqualToConstant:58],

        [volIcon.leadingAnchor constraintEqualToAnchor:_playerCard.leadingAnchor constant:20],
        [volIcon.centerYAnchor constraintEqualToAnchor:_playerVolume.centerYAnchor],
        [volIcon.widthAnchor constraintEqualToConstant:18],
        [volIcon.heightAnchor constraintEqualToConstant:18],

        [_playerVolume.leadingAnchor constraintEqualToAnchor:volIcon.trailingAnchor constant:8],
        [_playerVolume.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-18],
        [_playerVolume.topAnchor constraintEqualToAnchor:row.bottomAnchor constant:10],
        [_playerVolume.heightAnchor constraintEqualToConstant:24],

        [_bars.leadingAnchor constraintEqualToAnchor:_playerCard.leadingAnchor constant:20],
        [_bars.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-20],
        [_bars.topAnchor constraintEqualToAnchor:_playerVolume.bottomAnchor constant:8],
        [_bars.heightAnchor constraintEqualToConstant:36],

        [_lyrics.leadingAnchor constraintEqualToAnchor:_playerCard.leadingAnchor constant:20],
        [_lyrics.trailingAnchor constraintEqualToAnchor:_playerCard.trailingAnchor constant:-20],
        [_lyrics.topAnchor constraintEqualToAnchor:_bars.bottomAnchor constant:6],
        [_lyrics.heightAnchor constraintEqualToConstant:18],
    ]];
}

- (UIButton *)playerButton:(NSString *)icon size:(CGFloat)size side:(CGFloat)side action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold];
        [b setImage:[UIImage systemImageNamed:icon withConfiguration:cfg] forState:UIControlStateNormal];
    }
    b.tintColor = UIColor.whiteColor;
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    b.layer.cornerRadius = side / 2;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [b.widthAnchor constraintEqualToConstant:side].active = YES;
    [b.heightAnchor constraintEqualToConstant:side].active = YES;
    return b;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CustomBackgroundEnabled"]) {
        [self updateBackground];
        if (self.bgMode == BGSwitchModeTimer) {
            [self startBgTimerIfNeeded];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopBgTimer];
    [self stopVideoBackground];
}

#pragma mark - 安全区

/* 卡片上下边距跟着安全区走：window.safeAreaInsets 在"挂到游戏根视图"时可能为 0，
   那就退到自己 view 的 safeAreaInsets；两个都是 0 时按全面屏兜底 34/18。 */
- (void)lllApplySafeAreaPadding {
    NSLayoutConstraint *ct = objc_getAssociatedObject(self, "lllCardTop");
    NSLayoutConstraint *cb = objc_getAssociatedObject(self, "lllCardBottom");
    if (!ct || !cb) return;

    UIEdgeInsets si = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        si = self.view.window.safeAreaInsets;
        if (si.top <= 0.5 && si.bottom <= 0.5) si = self.view.safeAreaInsets;
    }
    CGFloat top = 20 + MAX(si.top, (CGFloat)34);
    CGFloat bottom = 20 + MAX(si.bottom, (CGFloat)18);
    if (fabs(ct.constant - top) > 0.5) ct.constant = top;
    if (fabs(cb.constant + bottom) > 0.5) cb.constant = -bottom;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self lllApplySafeAreaPadding];
}

#pragma mark - 按钮工厂

- (void)bgTapped:(UITapGestureRecognizer *)gr {
    // 只有点卡片外面才关窗，点卡片内部不该关
    CGPoint p = [gr locationInView:self.view];
    if (!CGRectContainsPoint(_cardView.frame, p)) toggleMainWindow();
}

- (void)setTab:(UIButton *)tab active:(BOOL)active {
    if (!tab) return;
    tab.tintColor = active ? kTabActiveColor : kTabNormalColor;
    [tab setTitleColor:(active ? kTabActiveColor : kTabNormalColor) forState:UIControlStateNormal];

    if (!active || !_indicator || !_indicator.superview) return;

    CGRect f = [tab convertRect:tab.bounds toView:_indicator.superview];
    f = CGRectInset(f, 3, 3);

    BOOL first = _indicator.hidden;
    _indicator.hidden = NO;

    if (first) {
        _indicator.frame = f;
        _indicator.alpha = 0;
        LLLSpring(kLLLNormal, 0.9, ^{ _indicator.alpha = 1; });
    } else {
        LLLSpring(0.34, 0.82, ^{ _indicator.frame = f; });
    }
}

- (void)setHeader:(NSString *)title sub:(NSString *)sub {
    if (!_headerTitle) return;
    _headerTitle.text = title ?: _headerTitle.text;
    if (sub) _headerSub.text = sub;
    _headerTitle.alpha = 0.35;
    LLLSpring(kLLLNormal, 0.9, ^{ _headerTitle.alpha = 1; });
}

- (void)closePanel {
    toggleMainWindow();
}

- (void)applyTheme {
    UIColor *accent = LLLAccentColor();

    if (_playPauseBtn) {
        _playPauseBtn.backgroundColor = accent;
        LLLGlow(_playPauseBtn, accent, 14, 0.55);
    }
    if (self.chooseBgBtn) {
        self.chooseBgBtn.backgroundColor = accent;
        LLLGlow(self.chooseBgBtn, accent, 12, 0.35);
    }
    if (self.modeSegment) {
        self.modeSegment.selectedSegmentTintColor = accent;
    }
    if (_indicator) {
        _indicator.layer.borderColor = [accent colorWithAlphaComponent:0.55].CGColor;
    }
    if (_volumeSlider) _volumeSlider.minimumTrackTintColor = accent;
    if (_progressSlider) _progressSlider.minimumTrackTintColor = accent;
    if (_playerProgress) _playerProgress.minimumTrackTintColor = accent;
    if (_playerVolume) _playerVolume.minimumTrackTintColor = accent;
    if (_bars) {
        _bars.barColor = accent;
        [_bars setNeedsDisplay];
    }
    if (_playerCloudBtn) {
        _playerCloudBtn.backgroundColor = [accent colorWithAlphaComponent:0.28];
    }
    if (_playerPlayBtn) {
        _playerPlayBtn.backgroundColor = accent;
        LLLGlow(_playerPlayBtn, accent, 14, 0.5);
    }
    if (_headerSub) {
        _headerSub.textColor = [accent colorWithAlphaComponent:0.85];
    }

    // 递归把设置页所有开关的 onTintColor 换掉
    [self tintSwitchesIn:self.settingsView color:accent];
}

- (void)tintSwitchesIn:(UIView *)view color:(UIColor *)color {
    if (!view) return;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UISwitch class]]) {
            ((UISwitch *)sub).onTintColor = color;
        } else {
            [self tintSwitchesIn:sub color:color];
        }
    }
}

- (UIButton *)tBtn:(NSString *)t ico:(NSString *)i act:(SEL)a {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.tintColor = kTabNormalColor;
    b.titleLabel.font = [UIFont systemFontOfSize:kTabFontSize weight:UIFontWeightSemibold];
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

    UIImage *icon = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightMedium];
        icon = [UIImage systemImageNamed:i withConfiguration:cfg];
    }
    [b setImage:icon forState:UIControlStateNormal];

    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:kTabNormalColor forState:UIControlStateNormal];
    [b setTitleColor:kTabActiveColor forState:UIControlStateHighlighted];

    // 竖排：图标在上、文字在下。iOS15 的 UIButtonConfiguration 这边不用，
    // 保持 14.0 一致表现，insets 的弃用警告已在 Makefile 里关掉。
    b.imageEdgeInsets = UIEdgeInsetsMake(-11, 0, 0, -b.titleLabel.intrinsicContentSize.width);
    b.titleEdgeInsets = UIEdgeInsetsMake(19, -icon.size.width, 0, 0);

    b.layer.cornerRadius = kPillCornerRadius;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    b.backgroundColor = UIColor.clearColor;
    b.clipsToBounds = NO;

    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (UIButton *)aBtn:(NSString *)t ico:(NSString *)i col:(UIColor *)c act:(SEL)a {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.7;
    b.backgroundColor = c;
    b.layer.cornerRadius = kButtonCornerRadius;
    if (@available(iOS 13.0, *))
        [b setImage:[UIImage systemImageNamed:i] forState:UIControlStateNormal];
    b.tintColor = UIColor.whiteColor;
    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    [b addTarget:self action:@selector(down:) forControlEvents:UIControlEventTouchDown];
    [b addTarget:self action:@selector(up:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (void)down:(UIButton *)b {
    LLLPressDown(b);
}

- (void)up:(UIButton *)b {
    LLLPressUp(b);
}

- (UITableView *)tv:(NSString *)rid {
    UITableView *t = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    t.dataSource = self; t.delegate = self;
    t.separatorStyle = UITableViewCellSeparatorStyleNone;
    t.backgroundColor = UIColor.clearColor;
    [t registerClass:PackCell.class   forCellReuseIdentifier:@"s"];
    [t registerClass:QueueCell.class  forCellReuseIdentifier:@"q"];
    [t registerClass:PluginCell.class forCellReuseIdentifier:@"p"];
    [t registerClass:QueueCell.class  forCellReuseIdentifier:@"pq"];
    [t registerClass:PackCell.class   forCellReuseIdentifier:@"music"];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.showsVerticalScrollIndicator = NO;
    t.contentInset = UIEdgeInsetsMake(6, 0, 6, 0);
    return t;
}

#pragma mark - 标签切换

- (void)switchTo:(UITableView *)to hide:(NSArray *)others bar:(UIView *)bar {
    // 已经停在这一页了 —— 直接返回，别再播一次过渡动画
    if (!to.hidden && to.alpha > 0.9) return;

    UITableView *from = nil;
    for (UITableView *v in others) {
        if (!v.hidden) { from = v; break; }
    }

    to.hidden = NO;
    for (UITableView *v in others) v.hidden = YES;
    self.settingsView.hidden = YES;

    [self setTab:self.tab1 active:(to == self.st)];
    [self setTab:self.tab2 active:(to == self.qt)];
    [self setTab:self.tab3 active:(to == self.pt)];
    [self setTab:self.tab4 active:(to == self.pqt)];
    [self setTab:self.tab6 active:(to == self.musict)];
    [self setTab:self.tab7 active:NO];

    // 内容切换：旧页面快速淡出，新页面从下方 10pt 弹进来
    if (from && from != to) {
        NSTimeInterval d = kLLLFast;
        [UIView animateWithDuration:d animations:^{ from.alpha = 0; }];
    }
    to.alpha = 0;
    to.transform = CGAffineTransformMakeTranslation(0, 10);
    LLLSpring(kLLLNormal, 0.88, ^{
        to.alpha = 1;
        to.transform = CGAffineTransformIdentity;
    });

    // 底部操作条：淡入淡出，别硬切
    NSArray *bars = @[self.ab, self.pab, self.musicControlBar];
    for (UIView *b in bars) {
        BOOL shouldShow = (b == bar);
        if (shouldShow) {
            b.hidden = NO;
            b.alpha = 0;
            LLLSpring(kLLLNormal, 0.9, ^{ b.alpha = 1; });
        } else if (!b.hidden) {
            [UIView animateWithDuration:kLLLFast animations:^{ b.alpha = 0; }
                             completion:^(BOOL f) { b.hidden = YES; }];
        }
    }

    NSLayoutConstraint *old = objc_getAssociatedObject(self, "bot");
    if (old) [old setActive:NO];
    NSLayoutConstraint *nb = bar ? [to.bottomAnchor constraintEqualToAnchor:bar.topAnchor constant:-10]
                                 : [to.bottomAnchor constraintEqualToAnchor:to.superview.bottomAnchor constant:-8];
    [nb setActive:YES];
    objc_setAssociatedObject(self, "bot", nb, OBJC_ASSOCIATION_RETAIN);
}

- (void)showSrcTab {
    self.playerCard.hidden = YES;
    if (self.playerHeight) self.playerHeight.constant = 0;

    [self setHeader:@"材质包" sub:[NSString stringWithFormat:@"目标 · %@", targetPathDisplayName()]];
    [self reloadSrcData];
    [self switchTo:self.st hide:@[self.qt, self.pt, self.pqt, self.musict] bar:nil];
}

- (void)showQueueTab {
    self.playerCard.hidden = YES;
    if (self.playerHeight) self.playerHeight.constant = 0;

    [self setHeader:@"注入队列" sub:[NSString stringWithFormat:@"%lu 项待注入", (unsigned long)self.qn.count]];
    [self switchTo:self.qt hide:@[self.st, self.pt, self.pqt, self.musict] bar:self.ab];
}

- (void)showPluginTab {
    self.playerCard.hidden = YES;
    if (self.playerHeight) self.playerHeight.constant = 0;

    [self setHeader:@"MCP 插件" sub:[NSString stringWithFormat:@"%lu 项可用", (unsigned long)self.pln.count]];
    [self reloadPluginData];
    [self switchTo:self.pt hide:@[self.st, self.qt, self.pqt, self.musict] bar:nil];
}

- (void)showPluginQueueTab {
    self.playerCard.hidden = YES;
    if (self.playerHeight) self.playerHeight.constant = 0;

    [self setHeader:@"插件注入" sub:[NSString stringWithFormat:@"%lu 项待注入", (unsigned long)self.plqn.count]];
    [self switchTo:self.pqt hide:@[self.st, self.qt, self.pt, self.musict] bar:self.pab];
}

- (void)showMusicTab {
    lllLog(@"进入音乐页 card=%@ btn=%@", _playerCard, _playerCloudBtn);
    [self setHeader:@"音乐播放器" sub:[NSString stringWithFormat:@"%lu 首", (unsigned long)self.musicNames.count]];
    [self reloadMusicData];
    [self startProgressTimer];

    /* 【修复】进入音乐页必须展开播放器卡片并显示控制栏。
       此前从未恢复：卡片 hidden=YES 且 playerHeight 恒为 0 → 音乐页全空 */
    self.playerCard.hidden = NO;
    if (self.playerHeight) self.playerHeight.constant = 310;
    // 2.4: 只留 playerCard 一套播放 UI
    self.musicControlBar.hidden = YES;
    self.musicControlBar.alpha = 0;

    [self switchTo:self.musict hide:@[self.st, self.qt, self.pt, self.pqt] bar:nil];

    // 切换之后再记一次，这次是真实布局状态
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        lllLog(@"音乐页布局 card=%@ hidden=%d h=%.0f | table=%@ hidden=%d h=%.0f | 曲目=%lu",
               NSStringFromCGRect(self.playerCard.frame), self.playerCard.hidden,
               self.playerHeight ? self.playerHeight.constant : -1,
               NSStringFromCGRect(self.musict.frame), self.musict.hidden,
               self.musict.bounds.size.height,
               (unsigned long)self.musicNames.count);
    });
}

- (void)showSettingsTab {
    /* v3.1: 清掉任何残留的全屏遮罩，并把自己的面板提到最前，否则设置页看着在、其实点不到 */
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        for (UIView *v in [w.rootViewController.view.subviews copy]) {
            if (v.tag == 99131 || v.tag == 99141) [v removeFromSuperview];
        }
    }
    [self.view bringSubviewToFront:self.settingsView];
    self.settingsView.userInteractionEnabled = YES;
    // 已经在设置页了，点多少次都别重播动画
    if (!self.settingsView.hidden && self.settingsView.alpha > 0.9) return;

    for (UITableView *v in @[self.st, self.qt, self.pt, self.pqt, self.musict]) v.hidden = YES;

    self.settingsView.hidden = NO;
    self.settingsView.alpha = 0;
    self.settingsView.transform = CGAffineTransformMakeTranslation(0, 10);
    LLLSpring(kLLLNormal, 0.88, ^{
        self.settingsView.alpha = 1;
        self.settingsView.transform = CGAffineTransformIdentity;
    });

    [self setTab:self.tab1 active:NO];
    [self setTab:self.tab2 active:NO];
    [self setTab:self.tab3 active:NO];
    [self setTab:self.tab4 active:NO];
    [self setTab:self.tab6 active:NO];
    [self setTab:self.tab7 active:YES];

    self.playerCard.hidden = YES;
    if (self.playerHeight) self.playerHeight.constant = 0;

    [self setHeader:@"设置" sub:[NSString stringWithFormat:@"LLL %@", kPluginVersion]];

    for (UIView *b in @[self.ab, self.pab, self.musicControlBar]) {
        if (!b.hidden) {
            [UIView animateWithDuration:kLLLFast animations:^{ b.alpha = 0; }
                             completion:^(BOOL f) { b.hidden = YES; }];
        }
    }

    NSLayoutConstraint *old = objc_getAssociatedObject(self, "bot");
    if (old) { [old setActive:NO]; objc_setAssociatedObject(self, "bot", nil, OBJC_ASSOCIATION_RETAIN); }
}

#pragma mark - 数据加载

- (void)reloadSrcData {
    __weak typeof(self) w = self;
    dispatch_async(g_fileQueue(), ^{
        NSMutableArray *n=[NSMutableArray new], *p=[NSMutableArray new], *hi=[NSMutableArray new];
        scanPacks(^(NSString *a, NSString *b, BOOL c){ [n addObject:a]; [p addObject:b]; [hi addObject:@(c)]; });
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w; if (!s || s->_dis) return;
            s.sn = n; s.sp = p; s.shi = hi; lllReload(s.st); [s upEmpty:s.st];
        });
    });
}

- (void)reloadPluginData {
    __weak typeof(self) w = self;
    dispatch_async(g_fileQueue(), ^{
        NSMutableArray *n=[NSMutableArray new], *p=[NSMutableArray new];
        scanPlugins(^(NSString *a, NSString *b){ [n addObject:a]; [p addObject:b]; });
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w; if (!s || s->_dis) return;
            s.pln = n; s.plp = p; lllReload(s.pt); [s upEmpty:s.pt];
        });
    });
}

- (void)reloadMusicData {
    __weak typeof(self) w = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSMutableArray *n=[NSMutableArray new], *p=[NSMutableArray new];
        scanMusicFiles(^(NSString *name, NSString *path){ [n addObject:name]; [p addObject:path]; });
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w; if (!s || s->_dis) return;
            s.musicNames = n; s.musicPaths = p;
            lllReload(s.musict);
            if ([s respondsToSelector:@selector(upEmptyMusic)]) {
                [s performSelector:@selector(upEmptyMusic)];
            }
        });
    });
}

#pragma mark - 队列管理

- (void)loadQ {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSArray *n=[d objectForKey:kQueueNamesKey], *p=[d objectForKey:kQueuePathsKey];
    if (n&&p&&n.count==p.count) { [self.qn addObjectsFromArray:n]; [self.qp addObjectsFromArray:p]; }
    n=[d objectForKey:kPluginQueueNamesKey]; p=[d objectForKey:kPluginQueuePathsKey];
    if (n&&p&&n.count==p.count) { [self.plqn addObjectsFromArray:n]; [self.plqp addObjectsFromArray:p]; }
}

- (void)saveQ {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:self.qn forKey:kQueueNamesKey]; [d setObject:self.qp forKey:kQueuePathsKey];
    [d setObject:self.plqn forKey:kPluginQueueNamesKey]; [d setObject:self.plqp forKey:kPluginQueuePathsKey];
}

#pragma mark - 空白状态

- (void)updateEmpty {
    [self upEmpty:self.st]; [self upEmpty:self.qt]; [self upEmpty:self.pt];
    [self upEmpty:self.pqt];
    if ([self respondsToSelector:@selector(upEmptyMusic)]) {
        [self performSelector:@selector(upEmptyMusic)];
    }
}

- (void)upEmpty:(UITableView *)tv {
    NSInteger cnt=0; NSString *tx=@"";
    if (tv == self.st) { cnt=self.sn.count; tx=@"暂无材质包\n将文件夹放入 Caizhi 目录"; }
    else if (tv == self.qt) { cnt=self.qn.count; tx=@"队列为空\n点击 + 号添加"; }
    else if (tv == self.pt) { cnt=self.pln.count; tx=@"暂无插件\n将文件夹放入 mcp_plugins 目录"; }
    else if (tv == self.pqt) { cnt=self.plqn.count; tx=@"队列为空\n在 mcp插件 页面添加"; }
    if (!cnt) {
        UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.bounds.size.width, 220)];

        UIView *ring = [UIView new];
        ring.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        ring.layer.cornerRadius = 34;
        ring.layer.borderWidth = kHairline;
        ring.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
        ring.translatesAutoresizingMaskIntoConstraints = NO;
        [c addSubview:ring];

        UIImageView *iv = [[UIImageView alloc] init];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) {
            NSString *im = @"cube.box";
            if (tv == self.qt)  im = @"tray";
            else if (tv == self.pt)  im = @"puzzlepiece";
            else if (tv == self.pqt) im = @"arrow.right.doc.on.clipboard";
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightRegular];
            iv.image = [UIImage systemImageNamed:im withConfiguration:cfg];
            iv.tintColor = kEmptyIconColor;
        }
        [ring addSubview:iv];

        UILabel *l = [[UILabel alloc] init];
        l.text = tx;
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = kEmptyTextColor;
        l.numberOfLines = 0;
        l.font = [UIFont systemFontOfSize:kEmptyStateFontSize weight:UIFontWeightRegular];
        l.translatesAutoresizingMaskIntoConstraints = NO;
        [c addSubview:l];

        [NSLayoutConstraint activateConstraints:@[
            [ring.centerXAnchor constraintEqualToAnchor:c.centerXAnchor],
            [ring.topAnchor constraintEqualToAnchor:c.topAnchor constant:46],
            [ring.widthAnchor constraintEqualToConstant:68],
            [ring.heightAnchor constraintEqualToConstant:68],
            [iv.centerXAnchor constraintEqualToAnchor:ring.centerXAnchor],
            [iv.centerYAnchor constraintEqualToAnchor:ring.centerYAnchor],
            [iv.widthAnchor constraintEqualToConstant:32],
            [iv.heightAnchor constraintEqualToConstant:32],
            [l.topAnchor constraintEqualToAnchor:ring.bottomAnchor constant:16],
            [l.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:24],
            [l.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-24]
        ]];
        tv.backgroundView = c;
    } else tv.backgroundView = nil;
}

- (void)confirm:(NSString *)t msg:(NSString *)m dest:(BOOL)d cb:(void(^)(void))cb {
    NSArray *btns = d ? @[@"取消", @"确定"] : @[@"好"];
    LLLShowSheet(t, m, btns, d, ^(NSInteger idx) {
        if (d) { if (idx == 1 && cb) cb(); }
        else   { if (cb) cb(); }
    });
}

- (void)showAlert:(NSString *)t msg:(NSString *)m {
    if (_dis) return;
    LLLShowSheet(t, m, @[@"好"], NO, nil);
}

#pragma mark - 音量

- (void)applyVolume {
    float v = [[NSUserDefaults standardUserDefaults] floatForKey:@"LLL.volume"];
    if (v <= 0.001f) v = 0.8f;

    self.audioPlayer.volume = v;
    self.videoMusicPlayer.volume = v;
    self.cloudPlayer.volume = v;
    self.bgPlayer.volume = v * 0.55f;

    if (_volumeSlider && fabsf(_volumeSlider.value - v) > 0.001f) _volumeSlider.value = v;
    if (_playerVolume && fabsf(_playerVolume.value - v) > 0.001f) _playerVolume.value = v;
}

- (void)volumeChanged:(UISlider *)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:sender.value forKey:@"LLL.volume"];
    [self applyVolume];
}

#pragma mark - 播放进度

- (void)startProgressTimer {
    [self stopProgressTimer];
    __weak typeof(self) w = self;
    self.progressTimer = [NSTimer timerWithTimeInterval:0.4 repeats:YES block:^(NSTimer *t) {
        __strong typeof(w) s = w;
        if (s) [s updateProgressUI];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.progressTimer forMode:NSRunLoopCommonModes];
}

- (void)stopProgressTimer {
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)updateProgressUI {
    AVAudioPlayer *ap = self.audioPlayer;
    double cur = 0, total = 0;
    if (ap && ap.duration > 0.01) {
        cur = ap.currentTime; total = ap.duration;
    } else if (self.videoMusicPlayer.currentItem) {
        total = CMTimeGetSeconds(self.videoMusicPlayer.currentItem.duration);
        cur = CMTimeGetSeconds(self.videoMusicPlayer.currentTime);
    } else if (self.cloudPlayer.currentItem) {
        total = CMTimeGetSeconds(self.cloudPlayer.currentItem.duration);
        cur = CMTimeGetSeconds(self.cloudPlayer.currentTime);
    }
    if (total > 0.01 && !isnan(total)) {
        [[LLLNowPlaying shared] updateElapsed:cur duration:total];
        if (_progressSlider && !_progressSlider.isTracking)
            _progressSlider.value = (float)(cur / total);
        if (_playerProgress && !_playerProgress.isTracking)
            _playerProgress.value = (float)(cur / total);
        if (_playerTimeLabel)
            _playerTimeLabel.text = [NSString stringWithFormat:@"%d:%02d / %d:%02d",
                                     (int)(cur / 60), (int)fmod(cur, 60),
                                     (int)(total / 60), (int)fmod(total, 60)];
    }
    // 声压条
    if (_bars) {
        AVAudioPlayer *ap2 = self.audioPlayer;
        float base = 0;
        if (ap2 && ap2.isMeteringEnabled && ap2.isPlaying) {
            [ap2 updateMeters];
            float db = [ap2 averagePowerForChannel:0];
            base = powf(10.0f, db / 40.0f);
            if (base < 0.02f) base = 0.02f;
            if (base > 1.0f) base = 1.0f;
        }
        CGFloat vals[16];
        for (int i = 0; i < 16; i++) {
            CGFloat k = 0.5 + 0.5 * (((i * 7) % 13) / 12.0);
            vals[i] = base * k;
        }
        [_bars setLevels:vals count:16];
    }

    // 歌词
    if (_lyrics && _lrcLines.count) {
        NSInteger idx = -1;
        for (NSUInteger i = 0; i < _lrcLines.count; i++) {
            double lt = [_lrcLines[i][@"t"] doubleValue];
            if (lt <= cur) idx = (NSInteger)i; else break;
        }
        if (idx >= 0 && idx != _lrcIndex) {
            _lrcIndex = idx;
            _lyrics.text = _lrcLines[(NSUInteger)idx][@"s"];
        }
    }

    if (_progressSlider || _playerProgress) return;
    AVPlayer *vp = self.videoMusicPlayer;
    if (vp && vp.currentItem) {
        double total = CMTimeGetSeconds(vp.currentItem.duration);
        double cur = CMTimeGetSeconds(vp.currentTime);
        if (total > 0.01 && !isnan(total)) _progressSlider.value = (float)(cur / total);
    }
}

- (void)progressSeek:(UISlider *)sender {
    AVAudioPlayer *ap = self.audioPlayer;
    if (ap && ap.duration > 0.01) {
        ap.currentTime = sender.value * ap.duration;
        return;
    }
    AVPlayer *vp = self.videoMusicPlayer;
    if (vp && vp.currentItem) {
        double total = CMTimeGetSeconds(vp.currentItem.duration);
        if (total > 0.01 && !isnan(total)) {
            [vp seekToTime:CMTimeMakeWithSeconds(sender.value * total, 600)
           toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
    }
}

#pragma mark - 长按清理

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) { PlayHapticWarning(); _delCount=0; [self stopTimer]; [self startTimer]; [MaterialHUD show:@"连续清理中..." inView:self.view]; }
    else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled || g.state == UIGestureRecognizerStateFailed) {
        [self stopTimer]; [MaterialHUD dismiss]; NSString *m = [NSString stringWithFormat:@"共清理 %lu 个", (unsigned long)_delCount]; ShowToast(m,2,YES,NO); if (_delCount) PlayHaptic(YES);
    }
}

- (void)startTimer {
    if (_timer) return;
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_fileQueue());
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW,0), kInterval, 0.01*NSEC_PER_SEC);
    __weak typeof(self) w = self;
    dispatch_source_set_event_handler(_timer, ^{
        [ResourceManager killCacheOnce:^(NSUInteger del, NSUInteger fail) {
            __strong typeof(w) s = w;
            if (s) s->_delCount += del;
        }];
    });
    dispatch_resume(_timer);
}

- (void)stopTimer { if(_timer){ dispatch_source_cancel(_timer); _timer=nil; } }

#pragma mark - TableView DataSource / Delegate

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec {
    if (tv == self.st) return self.sn.count;
    if (tv == self.qt) return self.qn.count;
    if (tv == self.pt) return self.pln.count;
    if (tv == self.pqt) return self.plqn.count;
    if (tv == self.musict) return self.musicNames.count;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (tv == self.st) {
        PackCell *c = [tv dequeueReusableCellWithIdentifier:@"s" forIndexPath:ip];
        c.title.text = self.sn[ip.row]; c.icon.image = cachedIcon(self.sp[ip.row], self.shi[ip.row].boolValue);
        objc_setAssociatedObject(c.btn, "p", self.sp[ip.row], OBJC_ASSOCIATION_RETAIN); objc_setAssociatedObject(c.btn, "n", self.sn[ip.row], OBJC_ASSOCIATION_RETAIN);

        // 长按整行 → 选择是否附带平砍粒子
        objc_setAssociatedObject(c, "src", self.sp[ip.row], OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(c, "nm", self.sn[ip.row], OBJC_ASSOCIATION_RETAIN);
        for (UIGestureRecognizer *g in [c.gestureRecognizers copy]) {
            if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) [c removeGestureRecognizer:g];
        }
        UILongPressGestureRecognizer *lp =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(packLongPress:)];
        lp.minimumPressDuration = 0.5;
        [c addGestureRecognizer:lp];
        [c.btn removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside]; [c.btn addTarget:self action:@selector(addToQueue:) forControlEvents:UIControlEventTouchUpInside];
        return c;
    }
    if (tv == self.qt) {
        QueueCell *c = [tv dequeueReusableCellWithIdentifier:@"q" forIndexPath:ip];
        c.title.text = self.qn[ip.row]; c.idx.text = [NSString stringWithFormat:@"%ld", (long)ip.row+1];
        return c;
    }
    if (tv == self.pt) {
        PluginCell *c = [tv dequeueReusableCellWithIdentifier:@"p" forIndexPath:ip];
        c.title.text = self.pln[ip.row];
        objc_setAssociatedObject(c.btn, "p", self.plp[ip.row], OBJC_ASSOCIATION_RETAIN); objc_setAssociatedObject(c.btn, "n", self.pln[ip.row], OBJC_ASSOCIATION_RETAIN);
        [c.btn removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside]; [c.btn addTarget:self action:@selector(addPluginToQueue:) forControlEvents:UIControlEventTouchUpInside];
        return c;
    }
    if (tv == self.pqt) {
        QueueCell *c = [tv dequeueReusableCellWithIdentifier:@"pq" forIndexPath:ip];
        c.title.text = self.plqn[ip.row]; c.idx.text = [NSString stringWithFormat:@"%ld", (long)ip.row+1];
        return c;
    }
    if (tv == self.musict) {
        PackCell *c = [tv dequeueReusableCellWithIdentifier:@"music" forIndexPath:ip];
        c.title.text = self.musicNames[ip.row];
        c.title.adjustsFontSizeToFitWidth = YES; c.title.minimumScaleFactor = 0.6;
        c.sub.text = @"音频文件";
        if (@available(iOS 13.0, *)) { c.icon.image = [UIImage systemImageNamed:@"music.note"]; c.icon.tintColor = kAccentGreen; c.icon.contentMode = UIViewContentModeCenter; }
        [c.btn removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
        [c.btn setImage:[UIImage systemImageNamed:@"play.circle.fill"] forState:UIControlStateNormal];
        [c.btn addTarget:self action:@selector(musicCellPlay:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(c.btn, "idx", @(ip.row), OBJC_ASSOCIATION_RETAIN);
        return c;
    }
    return [UITableViewCell new];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    if (tv == self.musict) { [self playMusicAtIndex:ip.row]; [tv deselectRowAtIndexPath:ip animated:YES]; }
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    if (tv == self.st || tv == self.musict) return 80;
    return 70;
}

- (BOOL)tableView:(UITableView *)tv canMoveRowAtIndexPath:(NSIndexPath *)ip { return (tv == self.qt || tv == self.pqt); }

- (void)tableView:(UITableView *)tv moveRowAtIndexPath:(NSIndexPath *)src toIndexPath:(NSIndexPath *)dst {
    if (tv == self.qt) {
        id n=self.qn[src.row], p=self.qp[src.row]; [self.qn removeObjectAtIndex:src.row]; [self.qp removeObjectAtIndex:src.row];
        NSUInteger idx = MIN(dst.row, self.qn.count);
        [self.qn insertObject:n atIndex:idx]; [self.qp insertObject:p atIndex:idx];
    } else {
        id n=self.plqn[src.row], p=self.plqp[src.row]; [self.plqn removeObjectAtIndex:src.row]; [self.plqp removeObjectAtIndex:src.row];
        NSUInteger idx = MIN(dst.row, self.plqn.count);
        [self.plqn insertObject:n atIndex:idx]; [self.plqp insertObject:p atIndex:idx];
    }
    [self saveQ]; [tv reloadData];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tv editingStyleForRowAtIndexPath:(NSIndexPath *)ip {
    return (tv == self.qt || tv == self.pqt) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)s forRowAtIndexPath:(NSIndexPath *)ip {
    if (s == UITableViewCellEditingStyleDelete && tv == self.qt) {
        NSString *r=self.qn[ip.row]; [self.qn removeObjectAtIndex:ip.row]; [self.qp removeObjectAtIndex:ip.row];
        [tv deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
        ShowToast([NSString stringWithFormat:@"已移除: %@", r],1.5,YES,NO);
    } else if (s == UITableViewCellEditingStyleDelete && tv == self.pqt) {
        NSString *r=self.plqn[ip.row]; [self.plqn removeObjectAtIndex:ip.row]; [self.plqp removeObjectAtIndex:ip.row];
        [tv deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationAutomatic];
        ShowToast([NSString stringWithFormat:@"已移除: %@", r],1.5,YES,NO);
    }
    [self upEmpty:tv]; [self saveQ]; PlayHapticWarning();
}

- (NSString *)tableView:(UITableView *)tv titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)ip { return @"移除"; }

@end
