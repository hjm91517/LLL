#import "MainViewController.h"
#import "MainViewController_Private.h"
#import "BaseComponents.h"
#import "ResourceManager.h"
#import "FloatMonitor.h"
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

@implementation MainViewController {
    dispatch_source_t _timer;
    NSUInteger _delCount;
    BOOL _dis;
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
    _cardView.layer.cornerRadius = 24;
    _cardView.clipsToBounds = YES;
    _cardView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_cardView];

    CGFloat margin = 20;
    [NSLayoutConstraint activateConstraints:@[
        [_cardView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [_cardView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:margin],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-margin]
    ]];

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

    UIView *div = [UIView new];
    div.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.5];
    div.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:div];

    UIView *sidebar = [UIView new];
    sidebar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.6];
    sidebar.layer.cornerRadius = 16;
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:sidebar];

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
    _tab6 = [self tBtn:@"音乐盒" ico:@"music.note.list" act:@selector(showMusicTab)];
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
    cv.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.4];
    cv.layer.cornerRadius = 16;
    cv.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:cv];
    self.contentContainerView = cv;

    _st  = [self tv:@"s"];   _st.hidden = NO;
    _qt  = [self tv:@"q"];   _qt.hidden = YES; _qt.editing = YES;
    _pt  = [self tv:@"p"];   _pt.hidden = YES;
    _pqt = [self tv:@"pq"];  _pqt.hidden = YES; _pqt.editing = YES;
    _musict = [self tv:@"music"]; _musict.hidden = YES;

    for (UITableView *t in @[_st, _qt, _pt, _pqt, _musict]) {
        [cv addSubview:t];
        [NSLayoutConstraint activateConstraints:@[
            [t.topAnchor constraintEqualToAnchor:cv.topAnchor constant:6],
            [t.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor],
            [t.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor]
        ]];
    }

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
    [_pab addSubview:pclr]; [_pab addSubview:ec]; [_pab addSubview:bj]; [_pab addSubview:ms];

    _musicControlBar = [UIView new]; _musicControlBar.translatesAutoresizingMaskIntoConstraints = NO; _musicControlBar.hidden = YES;
    _musicControlBar.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    _musicControlBar.layer.cornerRadius = kMusicControlBarRadius;
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
    _playPauseBtn.layer.cornerRadius = 24; _playPauseBtn.clipsToBounds = YES;
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
        [_musicControlBar.heightAnchor constraintEqualToConstant:60],

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
        [ms.trailingAnchor constraintEqualToAnchor:_pab.trailingAnchor],
        [ms.centerYAnchor constraintEqualToAnchor:_pab.centerYAnchor],
        [ms.heightAnchor constraintEqualToConstant:40],
        [ms.widthAnchor constraintEqualToAnchor:pclr.widthAnchor],

        [prevBtn.leadingAnchor constraintEqualToAnchor:_musicControlBar.leadingAnchor constant:20],
        [prevBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.centerYAnchor],
        [prevBtn.widthAnchor constraintEqualToConstant:40],
        [prevBtn.heightAnchor constraintEqualToConstant:40],

        [_speedBtn.leadingAnchor constraintEqualToAnchor:prevBtn.trailingAnchor constant:12],
        [_speedBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.centerYAnchor],
        [_speedBtn.widthAnchor constraintEqualToConstant:52],
        [_speedBtn.heightAnchor constraintEqualToConstant:40],

        [_playPauseBtn.centerXAnchor constraintEqualToAnchor:_musicControlBar.centerXAnchor],
        [_playPauseBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.centerYAnchor],
        [_playPauseBtn.widthAnchor constraintEqualToConstant:48],
        [_playPauseBtn.heightAnchor constraintEqualToConstant:48],

        [_modeBtn.trailingAnchor constraintEqualToAnchor:nextBtn.leadingAnchor constant:-12],
        [_modeBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.centerYAnchor],
        [_modeBtn.widthAnchor constraintEqualToConstant:52],
        [_modeBtn.heightAnchor constraintEqualToConstant:40],

        [nextBtn.trailingAnchor constraintEqualToAnchor:_musicControlBar.trailingAnchor constant:-20],
        [nextBtn.centerYAnchor constraintEqualToAnchor:_musicControlBar.centerYAnchor],
        [nextBtn.widthAnchor constraintEqualToConstant:40],
        [nextBtn.heightAnchor constraintEqualToConstant:40]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [tit.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [tit.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:22],
        [div.topAnchor constraintEqualToAnchor:tit.bottomAnchor constant:14],
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

#pragma mark - 按钮工厂

- (void)bgTapped:(UITapGestureRecognizer *)gr {
    if (!CGRectContainsPoint(self.view.subviews.firstObject.frame, [gr locationInView:self.view]))
        toggleMainWindow();
}

- (UIButton *)tBtn:(NSString *)t ico:(NSString *)i act:(SEL)a {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    b.titleLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        [b setImage:[UIImage systemImageNamed:i] forState:UIControlStateNormal];
    }
    [b setTitle:t forState:UIControlStateNormal];
    b.tintColor = UIColor.whiteColor;
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    b.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
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
    [UIView animateWithDuration:0.1 animations:^{ b.transform = CGAffineTransformMakeScale(0.95, 0.95); }];
}

- (void)up:(UIButton *)b {
    [UIView animateWithDuration:0.1 animations:^{ b.transform = CGAffineTransformIdentity; }];
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
    [UIView transitionWithView:self.view duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        to.hidden = NO;
        for (UITableView *v in others) v.hidden = YES;
        self.settingsView.hidden = YES;
        self.tab1.tintColor = (to == self.st)  ? UIColor.whiteColor : [UIColor colorWithWhite:0.5 alpha:1];
        self.tab2.tintColor = (to == self.qt)  ? UIColor.whiteColor : [UIColor colorWithWhite:0.5 alpha:1];
        self.tab3.tintColor = (to == self.pt)  ? UIColor.whiteColor : [UIColor colorWithWhite:0.5 alpha:1];
        self.tab4.tintColor = (to == self.pqt) ? UIColor.whiteColor : [UIColor colorWithWhite:0.5 alpha:1];
        self.tab6.tintColor = (to == self.musict) ? UIColor.whiteColor : [UIColor colorWithWhite:0.5 alpha:1];
        self.tab7.tintColor = [UIColor colorWithWhite:0.5 alpha:1];
    } completion:nil];

    self.ab.hidden = (bar != self.ab);
    self.pab.hidden = (bar != self.pab);
    self.musicControlBar.hidden = (bar != self.musicControlBar);

    NSLayoutConstraint *old = objc_getAssociatedObject(self, "bot");
    if (old) [old setActive:NO];
    NSLayoutConstraint *nb = bar ? [to.bottomAnchor constraintEqualToAnchor:bar.topAnchor constant:-8]
                                 : [to.bottomAnchor constraintEqualToAnchor:to.superview.bottomAnchor constant:-6];
    [nb setActive:YES];
    objc_setAssociatedObject(self, "bot", nb, OBJC_ASSOCIATION_RETAIN);
}

- (void)showSrcTab    { [self reloadSrcData]; [self switchTo:self.st hide:@[self.qt, self.pt, self.pqt, self.musict] bar:nil]; }
- (void)showQueueTab  { [self switchTo:self.qt hide:@[self.st, self.pt, self.pqt, self.musict] bar:self.ab]; }
- (void)showPluginTab { [self reloadPluginData]; [self switchTo:self.pt hide:@[self.st, self.qt, self.pqt, self.musict] bar:nil]; }
- (void)showPluginQueueTab { [self switchTo:self.pqt hide:@[self.st, self.qt, self.pt, self.musict] bar:self.pab]; }
- (void)showMusicTab  { [self reloadMusicData]; [self switchTo:self.musict hide:@[self.st, self.qt, self.pt, self.pqt] bar:self.musicControlBar]; }

- (void)showSettingsTab {
    [UIView transitionWithView:self.view duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        for (UITableView *v in @[self.st, self.qt, self.pt, self.pqt, self.musict]) v.hidden = YES;
        self.settingsView.hidden = NO;
        self.tab1.tintColor = [UIColor colorWithWhite:0.5 alpha:1];
        self.tab2.tintColor = [UIColor colorWithWhite:0.5 alpha:1];
        self.tab3.tintColor = [UIColor colorWithWhite:0.5 alpha:1];
        self.tab4.tintColor = [UIColor colorWithWhite:0.5 alpha:1];
        self.tab6.tintColor = [UIColor colorWithWhite:0.5 alpha:1];
        self.tab7.tintColor = UIColor.whiteColor;
    } completion:nil];
    self.ab.hidden = self.pab.hidden = self.musicControlBar.hidden = YES;
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
        UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0,0,tv.bounds.size.width,180)];
        UIImageView *iv = [[UIImageView alloc] init]; iv.translatesAutoresizingMaskIntoConstraints=NO; iv.contentMode=UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) { NSString *im = @"cube.box"; if (tv==self.qt) im=@"tray"; else if (tv==self.pt) im=@"puzzlepiece"; else if (tv==self.pqt) im=@"arrow.right.doc.on.clipboard"; iv.image=[UIImage systemImageNamed:im]; iv.tintColor=[UIColor colorWithWhite:0.3 alpha:1]; }
        [c addSubview:iv];
        UILabel *l = [[UILabel alloc] init]; l.text=tx; l.textAlignment=NSTextAlignmentCenter; l.textColor=[UIColor colorWithWhite:0.4 alpha:1]; l.numberOfLines=0; l.font=[UIFont systemFontOfSize:14]; l.translatesAutoresizingMaskIntoConstraints=NO; [c addSubview:l];
        [NSLayoutConstraint activateConstraints:@[
            [iv.centerXAnchor constraintEqualToAnchor:c.centerXAnchor], [iv.topAnchor constraintEqualToAnchor:c.topAnchor constant:40], [iv.widthAnchor constraintEqualToConstant:50], [iv.heightAnchor constraintEqualToConstant:50],
            [l.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:16], [l.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:20], [l.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-20]
        ]];
        tv.backgroundView = c;
    } else tv.backgroundView = nil;
}

- (void)confirm:(NSString *)t msg:(NSString *)m dest:(BOOL)d cb:(void(^)(void))cb {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:t message:m preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:d?@"确定":@"好" style:d?UIAlertActionStyleDestructive:UIAlertActionStyleDefault handler:^(UIAlertAction *_){ if(cb)cb(); }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showAlert:(NSString *)t msg:(NSString *)m { if (_dis) return; [self confirm:t msg:m dest:NO cb:nil]; }

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
