
#import "MainViewController+SettingsBackground.h"
#import "MainViewController_Private.h"
#import "BaseComponents.h"
#import "FloatMonitor.h"
#import "CacheCleaner.h"
#import "PluginInfo.h"
#import <objc/runtime.h>
#import <PhotosUI/PhotosUI.h>

@interface MainViewController (SettingsBackgroundPrivate) <PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
- (UIView *)switchRow:(NSString *)title
             switchOn:(BOOL)on
               action:(SEL)action
            outSwitch:(UISwitch **)outSwitch;
- (UIView *)inputRow:(NSString *)title
           fieldText:(NSString *)text
              action:(SEL)action
            outField:(UITextField **)outField;
- (UIView *)cardRow;
- (void)themeChanged:(UISegmentedControl *)sender;
@end

@implementation MainViewController (SettingsBackground)

- (void)setupSettingsView {
    self.settingsView = [UIView new];
    self.settingsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsView.hidden = YES;
    [self.contentContainerView addSubview:self.settingsView];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsView addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.settingsView.topAnchor constraintEqualToAnchor:self.contentContainerView.topAnchor constant:20],
        [self.settingsView.leadingAnchor constraintEqualToAnchor:self.contentContainerView.leadingAnchor constant:20],
        [self.settingsView.trailingAnchor constraintEqualToAnchor:self.contentContainerView.trailingAnchor constant:-20],
        [self.settingsView.bottomAnchor constraintEqualToAnchor:self.contentContainerView.bottomAnchor constant:-20],
        [scroll.topAnchor constraintEqualToAnchor:self.settingsView.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.settingsView.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.settingsView.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.settingsView.bottomAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
    ]];

    UISwitch *perfSw = nil;
    UIView *perfRow = [self switchRow:@"性能监视" switchOn:isPerformanceMonitorEnabled()
                               action:@selector(togglePerfMonitor:) outSwitch:&perfSw];
    self.perfSwitch = perfSw;
    [stack addArrangedSubview:perfRow];

    UIView *watermarkRow = [self switchRow:@"显示水印" switchOn:isWatermarkEnabled()
                                    action:@selector(toggleWatermark:) outSwitch:NULL];
    [stack addArrangedSubview:watermarkRow];

    UISwitch *bgSw = nil;
    UIView *bgRow = [self switchRow:@"自定义背景"
                           switchOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"CustomBackgroundEnabled"]
                             action:@selector(toggleCustomBackground:) outSwitch:&bgSw];
    self.bgSwitch = bgSw;
    [stack addArrangedSubview:bgRow];

    UIView *cacheCleanerRow = [self switchRow:@"缓存自动清理"
                                      switchOn:isCacheCleanerEnabled()
                                        action:@selector(toggleCacheCleaner:) outSwitch:NULL];
    [stack addArrangedSubview:cacheCleanerRow];

    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[@"固定", @"定时"]];
    self.modeSegment.selectedSegmentIndex = self.bgMode;
    self.modeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSegment.selectedSegmentTintColor = LLLAccentColor();
    [self.modeSegment addTarget:self action:@selector(modeSegmentChanged:) forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:self.modeSegment];
    [self.modeSegment.heightAnchor constraintEqualToConstant:34].active = YES;

    UIView *navRow = [UIView new];
    self.prevBgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) { [self.prevBgBtn setImage:[UIImage systemImageNamed:@"chevron.left.circle.fill"] forState:UIControlStateNormal]; self.prevBgBtn.tintColor = UIColor.whiteColor; }
    [self.prevBgBtn addTarget:self action:@selector(prevBackground) forControlEvents:UIControlEventTouchUpInside];
    self.prevBgBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [navRow addSubview:self.prevBgBtn];

    self.bgInfoLabel = [UILabel new];
    self.bgInfoLabel.textColor = UIColor.whiteColor;
    self.bgInfoLabel.font = [UIFont systemFontOfSize:14];
    self.bgInfoLabel.textAlignment = NSTextAlignmentCenter;
    self.bgInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [navRow addSubview:self.bgInfoLabel];

    self.nextBgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) { [self.nextBgBtn setImage:[UIImage systemImageNamed:@"chevron.right.circle.fill"] forState:UIControlStateNormal]; self.nextBgBtn.tintColor = UIColor.whiteColor; }
    [self.nextBgBtn addTarget:self action:@selector(nextBackground) forControlEvents:UIControlEventTouchUpInside];
    self.nextBgBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [navRow addSubview:self.nextBgBtn];

    [NSLayoutConstraint activateConstraints:@[
        [self.prevBgBtn.leadingAnchor constraintEqualToAnchor:navRow.leadingAnchor],
        [self.prevBgBtn.centerYAnchor constraintEqualToAnchor:navRow.centerYAnchor],
        [self.bgInfoLabel.centerXAnchor constraintEqualToAnchor:navRow.centerXAnchor],
        [self.bgInfoLabel.centerYAnchor constraintEqualToAnchor:navRow.centerYAnchor],
        [self.bgInfoLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.prevBgBtn.trailingAnchor constant:8],
        [self.bgInfoLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.nextBgBtn.leadingAnchor constant:-8],
        [self.nextBgBtn.trailingAnchor constraintEqualToAnchor:navRow.trailingAnchor],
        [self.nextBgBtn.centerYAnchor constraintEqualToAnchor:navRow.centerYAnchor],
        [navRow.heightAnchor constraintEqualToConstant:44]
    ]];
    [stack addArrangedSubview:navRow];

    UITextField *intervalField = nil;
    UIView *intervalRow = [self inputRow:@"切换间隔(秒)"
                               fieldText:[NSString stringWithFormat:@"%ld", (long)([[NSUserDefaults standardUserDefaults] integerForKey:@"BGInterval"] ?: 60)]
                                  action:@selector(intervalChanged:)
                                outField:&intervalField];
    self.intervalField = intervalField;
    [stack addArrangedSubview:intervalRow];

    self.chooseBgBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.chooseBgBtn setTitle:@"添加背景 (图片/视频)" forState:UIControlStateNormal];
    self.chooseBgBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.chooseBgBtn.tintColor = UIColor.whiteColor;
    self.chooseBgBtn.backgroundColor = LLLAccentColor();
    self.chooseBgBtn.layer.cornerRadius = 12;
    self.chooseBgBtn.layer.cornerCurve = kCACornerCurveContinuous;
    LLLGlow(self.chooseBgBtn, LLLAccentColor(), 12, 0.35);
    [self.chooseBgBtn addTarget:self action:@selector(chooseBackgroundImage) forControlEvents:UIControlEventTouchUpInside];
    self.chooseBgBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chooseBgBtn.heightAnchor constraintEqualToConstant:44].active = YES;
    [stack addArrangedSubview:self.chooseBgBtn];

    // 路径诊断：把探测结果直接摊在设置里，版本对不对一眼看穿
    UIView *diagCard = [self cardRow];
    UILabel *diag = [[UILabel alloc] init];
    diag.numberOfLines = 0;
    diag.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    diag.textColor = [UIColor colorWithWhite:0.66 alpha:1.0];
    NSArray<NSString*> *mcpTargets = findAllMCPTargets();
    NSArray<NSString*> *legacyDirs = detectLegacyPatchDirs();
    NSArray<NSString*> *injTargets = injectionTargetDirs();
    BOOL registered = lllInjectPackRegistered();
    diag.text = [NSString stringWithFormat:
                 @"游戏根目录\n%@\n\n"
                 @"注入包\n%@\n%@\n\n"
                 @"注入目标 %lu 个\n%@\n\n"
                 @"旧式补丁目录 %lu 个\n%@\n\n"
                 @"MCP 目标 %lu 个\n%@",
                 neteaseGameBasePath(),
                 targetPathDisplayName(),
                 registered ? @"✔ 已注册 global_resource_packs" : @"✘ 未注册（下次注入时写入）",
                 (unsigned long)injTargets.count,
                 [[injTargets valueForKey:@"lastPathComponent"] componentsJoinedByString:@", "],
                 (unsigned long)legacyDirs.count,
                 legacyDirs.count ? [[legacyDirs valueForKey:@"lastPathComponent"] componentsJoinedByString:@"\n"] : @"（无）",
                 (unsigned long)mcpTargets.count,
                 mcpTargets.count ? [[mcpTargets valueForKey:@"lastPathComponent"] componentsJoinedByString:@"\n"] : @"（未发现）"];
    diag.translatesAutoresizingMaskIntoConstraints = NO;
    [diagCard addSubview:diag];
    [NSLayoutConstraint activateConstraints:@[
        [diag.topAnchor constraintEqualToAnchor:diagCard.topAnchor constant:12],
        [diag.leadingAnchor constraintEqualToAnchor:diagCard.leadingAnchor constant:14],
        [diag.trailingAnchor constraintEqualToAnchor:diagCard.trailingAnchor constant:-14],
        [diag.bottomAnchor constraintEqualToAnchor:diagCard.bottomAnchor constant:-12],
    ]];
    [stack addArrangedSubview:diagCard];

    UIView *aboutCard = [[UIView alloc] init];
    aboutCard.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    aboutCard.layer.cornerRadius = 12;
    aboutCard.layer.cornerCurve = kCACornerCurveContinuous;
    aboutCard.layer.borderWidth = kHairline;
    aboutCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    aboutCard.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = [NSString stringWithFormat:@"版本 %@", kPluginVersion];
    versionLabel.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0];
    versionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [aboutCard addSubview:versionLabel];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"功能列表";
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [aboutCard addSubview:titleLabel];

    NSArray *features = kPluginFeatures;
    NSMutableString *featuresText = [NSMutableString string];
    for (NSString *f in features) {
        [featuresText appendFormat:@"%@\n", f];
    }

    UILabel *featuresLabel = [[UILabel alloc] init];
    featuresLabel.text = featuresText;
    featuresLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    featuresLabel.font = [UIFont systemFontOfSize:13];
    featuresLabel.numberOfLines = 0;
    featuresLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [aboutCard addSubview:featuresLabel];

    [NSLayoutConstraint activateConstraints:@[
        [versionLabel.topAnchor constraintEqualToAnchor:aboutCard.topAnchor constant:16],
        [versionLabel.leadingAnchor constraintEqualToAnchor:aboutCard.leadingAnchor constant:16],
        [versionLabel.trailingAnchor constraintEqualToAnchor:aboutCard.trailingAnchor constant:-16],

        [titleLabel.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:aboutCard.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:aboutCard.trailingAnchor constant:-16],

        [featuresLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [featuresLabel.leadingAnchor constraintEqualToAnchor:aboutCard.leadingAnchor constant:16],
        [featuresLabel.trailingAnchor constraintEqualToAnchor:aboutCard.trailingAnchor constant:-16],
        [featuresLabel.bottomAnchor constraintEqualToAnchor:aboutCard.bottomAnchor constant:-16]
    ]];

    [stack addArrangedSubview:aboutCard];
}

- (void)toggleCacheCleaner:(UISwitch *)sender {
    setCacheCleanerEnabled(sender.isOn);
}

// 设置项统一容器：圆角浅底 + 细描边
- (UIView *)cardRow {
    UIView *row = [UIView new];
    row.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
    row.layer.cornerRadius = 12;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    row.layer.borderWidth = kHairline;
    row.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.08].CGColor;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    return row;
}

- (UIView *)switchRow:(NSString *)title
             switchOn:(BOOL)on
               action:(SEL)action
            outSwitch:(UISwitch **)outSwitch {
    UIView *row = [self cardRow];

    UILabel *label = [UILabel new];
    label.text = title;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = on;
    sw.onTintColor = kAccentGreen;
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-10],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:50]
    ]];

    if (outSwitch) *outSwitch = sw;
    return row;
}

- (UIView *)inputRow:(NSString *)title
           fieldText:(NSString *)text
              action:(SEL)action
            outField:(UITextField **)outField {
    UIView *row = [self cardRow];

    UILabel *label = [UILabel new];
    label.text = title;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    field.layer.cornerRadius = 8;
    field.layer.cornerCurve = kCACornerCurveContinuous;
    field.textColor = UIColor.whiteColor;
    field.tintColor = kAccentBlue;
    field.textAlignment = NSTextAlignmentCenter;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
    field.text = text;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field addTarget:self action:action forControlEvents:UIControlEventEditingDidEnd];
    [row addSubview:field];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:field.leadingAnchor constant:-10],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10],
        [field.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [field.widthAnchor constraintEqualToConstant:68],
        [field.heightAnchor constraintEqualToConstant:32],
        [row.heightAnchor constraintEqualToConstant:50]
    ]];

    if (outField) *outField = field;
    return row;
}

- (void)themeChanged:(UISegmentedControl *)sender {
    LLLSetThemeIndex(sender.selectedSegmentIndex);
    sender.selectedSegmentTintColor = LLLAccentColor();
    [self applyTheme];
    PlayHaptic(YES);
}


- (void)togglePerfMonitor:(UISwitch *)s { setPerformanceMonitorEnabled(s.isOn); }
- (void)toggleWatermark:(UISwitch *)s { setWatermarkEnabled(s.isOn); }

- (void)toggleCustomBackground:(UISwitch *)s {
    [[NSUserDefaults standardUserDefaults] setBool:s.isOn forKey:@"CustomBackgroundEnabled"];
    if (!s.isOn) [self stopBgTimer];
    [self updateBackground];
}

- (void)modeSegmentChanged:(UISegmentedControl *)sender {
    self.bgMode = (BGSwitchMode)sender.selectedSegmentIndex;
    [self stopBgTimer];
    [self updateBackground];
}

- (void)intervalChanged:(UITextField *)sender {
    NSInteger val = [sender.text integerValue];
    if (val <= 0) val = 60;
    [[NSUserDefaults standardUserDefaults] setInteger:val forKey:@"BGInterval"];
    [self stopBgTimer];
    if (self.bgMode == BGSwitchModeTimer && [[NSUserDefaults standardUserDefaults] boolForKey:@"CustomBackgroundEnabled"]) {
        [self startBgTimerIfNeeded];
    }
}

- (void)prevBackground {
    if (self.bgFiles.count == 0) return;
    self.bgCurrentIndex = (self.bgCurrentIndex - 1 + self.bgFiles.count) % self.bgFiles.count;
    self.bgMode = BGSwitchModeFixed;
    self.modeSegment.selectedSegmentIndex = 0;
    [self updateBackground];
}

- (void)nextBackground {
    if (self.bgFiles.count == 0) return;
    self.bgCurrentIndex = (self.bgCurrentIndex + 1) % self.bgFiles.count;
    self.bgMode = BGSwitchModeFixed;
    self.modeSegment.selectedSegmentIndex = 0;
    [self updateBackground];
}

- (void)chooseBackgroundImage {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = 0;
        config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.mediaTypes = @[@"public.image", @"public.movie"];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)refreshBgFiles { self.bgFiles = backgroundFiles(); [self updateBgInfoLabel]; }

- (void)updateBackground {
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CustomBackgroundEnabled"];
    self.bgFiles = backgroundFiles();
    if (!enabled || self.bgFiles.count == 0) {
        self.bgImageView.hidden = YES;
        self.cardView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        [self stopBgTimer]; [self stopVideoBackground];
        return;
    }
    NSInteger index = 0;
    if (self.bgMode == BGSwitchModeTimer) {
        index = self.bgCurrentIndex % self.bgFiles.count;
        [self startBgTimerIfNeeded];
    } else {
        index = self.bgCurrentIndex;
    }
    if (index < 0 || index >= self.bgFiles.count) { self.bgImageView.hidden = YES; return; }
    NSString *path = [backgroundsDir() stringByAppendingPathComponent:self.bgFiles[index]];
    NSString *ext = path.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
        [self playBackgroundVideo:path];
    } else {
        [self stopVideoBackground];
        UIImage *bg = [UIImage imageWithContentsOfFile:path];
        if (bg) {
            self.bgImageView.image = bg;
            self.bgImageView.hidden = NO;
            self.cardView.effect = nil;
        }
    }
    [self updateBgInfoLabel];
    [self saveBgState];
}

- (void)playBackgroundVideo:(NSString *)path {
    [self stopVideoBackground];
    NSURL *url = [NSURL fileURLWithPath:path];
    self.bgPlayer = [AVPlayer playerWithURL:url];
    NSTimeInterval saved = [[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"bgp_%@", path.lastPathComponent]];
    if (saved > 0) {
        [self.bgPlayer seekToTime:CMTimeMakeWithSeconds(saved, 1000) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
    self.bgPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.bgPlayer];
    self.bgPlayerLayer.frame = self.cardView.bounds;
    self.bgPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.bgImageView.layer addSublayer:self.bgPlayerLayer];
    self.bgImageView.hidden = NO;
    self.cardView.effect = nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.bgPlayer.currentItem];
    [self.bgPlayer play];
}

- (void)stopVideoBackground {
    if (self.bgPlayer) {
        if (self.bgPlayer.currentItem) {
            NSTimeInterval cur = CMTimeGetSeconds(self.bgPlayer.currentTime);
            NSString *path = ((AVURLAsset *)self.bgPlayer.currentItem.asset).URL.path;
            if (path && cur > 0 && !isnan(cur) && !isinf(cur)) {
                [[NSUserDefaults standardUserDefaults] setDouble:cur forKey:[NSString stringWithFormat:@"bgp_%@", path.lastPathComponent]];
            }
        }
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.bgPlayer.currentItem];
        [self.bgPlayer pause];
        [self.bgPlayerLayer removeFromSuperlayer];
        self.bgPlayer = nil;
        self.bgPlayerLayer = nil;
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.bgPlayer seekToTime:kCMTimeZero];
    [self.bgPlayer play];
}

- (void)startBgTimerIfNeeded {
    [self stopBgTimer];
    if (self.bgMode != BGSwitchModeTimer) return;
    NSInteger interval = [[NSUserDefaults standardUserDefaults] integerForKey:@"BGInterval"] ?: 60;
    __weak typeof(self) w = self;
    self.bgTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        __strong typeof(w) s = w;
        if (!s || s.bgFiles.count == 0) return;
        s.bgCurrentIndex = (s.bgCurrentIndex + 1) % s.bgFiles.count;
        [s updateBackground];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.bgTimer forMode:NSRunLoopCommonModes];
}

- (void)stopBgTimer { [self.bgTimer invalidate]; self.bgTimer = nil; }

- (void)saveBgState {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:self.bgMode forKey:@"BGSwitchMode"];
    [d setInteger:self.bgCurrentIndex forKey:@"BGCurrentIndex"];
}

- (void)updateBgInfoLabel {
    if (self.bgFiles.count == 0) self.bgInfoLabel.text = @"暂无图片或视频";
    else if (self.bgCurrentIndex >= 0 && self.bgCurrentIndex < self.bgFiles.count)
        self.bgInfoLabel.text = [NSString stringWithFormat:@"%ld/%lu  %@", (long)self.bgCurrentIndex+1, (unsigned long)self.bgFiles.count, self.bgFiles[self.bgCurrentIndex]];
    else self.bgInfoLabel.text = @"";
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;
    dispatch_group_t group = dispatch_group_create();
    for (PHPickerResult *res in results) {
        dispatch_group_enter(group);
        if ([res.itemProvider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            [res.itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (url && !error) {
                    NSString *dest = [backgroundsDir() stringByAppendingPathComponent:url.lastPathComponent];
                    [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:dest] error:nil];
                }
                dispatch_group_leave(group);
            }];
        } else {
            [res.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id obj, NSError *error) {
                if ([obj isKindOfClass:[UIImage class]]) {
                    UIImage *image = obj;
                    NSData *data = UIImagePNGRepresentation(image) ?: UIImageJPEGRepresentation(image, 0.9);
                    if (data) {
                        NSString *name = [NSString stringWithFormat:@"bg_%@.%@", @([[NSDate date] timeIntervalSince1970]), UIImagePNGRepresentation(image)?@"png":@"jpg"];
                        [data writeToFile:[backgroundsDir() stringByAppendingPathComponent:name] atomically:YES];
                    }
                }
                dispatch_group_leave(group);
            }];
        }
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        ShowToast(@"背景已添加", 1.5, YES, NO);
        [self refreshBgFiles];
        [self updateBackground];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSURL *videoURL = info[UIImagePickerControllerMediaURL];
    if (videoURL) {
        NSString *dest = [backgroundsDir() stringByAppendingPathComponent:videoURL.lastPathComponent];
        [[NSFileManager defaultManager] copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:dest] error:nil];
    } else {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        if (image) {
            NSData *data = UIImagePNGRepresentation(image) ?: UIImageJPEGRepresentation(image, 0.9);
            if (data) {
                NSString *name = [NSString stringWithFormat:@"bg_%@.%@", @([[NSDate date] timeIntervalSince1970]), UIImagePNGRepresentation(image)?@"png":@"jpg"];
                [data writeToFile:[backgroundsDir() stringByAppendingPathComponent:name] atomically:YES];
            }
        }
    }
    ShowToast(@"背景已添加", 1.5, YES, NO);
    [self refreshBgFiles];
    [self updateBackground];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }

@end