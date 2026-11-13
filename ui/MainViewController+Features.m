#import "MainViewController+Features.h"
#import "MainViewController_Private.h"
#import "ResourceManager.h"
#import "BaseComponents.h"
#import "LLLAnim.h"
#import "LLLUiKit.h"
#import "LLLCloudMusic.h"
#import "EffectInjector.h"
#import "LLLMusicIsland.h"
#import <objc/runtime.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

static void (^gLLLCloseCloudCard)(void) = nil;

@implementation MainViewController (Features)

#pragma mark - 音乐

- (void)playMusicAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= self.musicPaths.count) return;
    self.currentMusicIndex = idx;
    NSString *path = self.musicPaths[idx];
    NSString *ext = path.pathExtension.lowercaseString;
    [self stopMusic];
    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
        self.videoMusicPlayer = [AVPlayer playerWithURL:[NSURL fileURLWithPath:path]];
        self.videoMusicPlayer.rate = self.doubleSpeed ? 2.0 : 1.0;
        [self.videoMusicPlayer play];
        self.isPlaying = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoMusicDidFinish:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.videoMusicPlayer.currentItem];
    } else {
        NSError *err;
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&err];
        self.audioPlayer.delegate = self;
        self.audioPlayer.enableRate = YES;
        self.audioPlayer.meteringEnabled = YES;
        self.audioPlayer.rate = self.doubleSpeed ? 2.0 : 1.0;
        [self.audioPlayer prepareToPlay];
        [self.audioPlayer play];
        self.isPlaying = YES;
    }
    [self loadLyricsForPath:path];

    if (self.playerCover) {
        CABasicAnimation *flip = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
        flip.fromValue = @1.0;
        flip.toValue = @0.02;
        flip.duration = 0.16;
        flip.autoreverses = YES;
        [self.playerCover.layer addAnimation:flip forKey:@"flip"];
    }

    [self updateMusicUI];
    ShowToast([NSString stringWithFormat:@"正在播放: %@", self.musicNames[idx]], 2, YES, NO);
}

- (void)stopMusic {
    [self.audioPlayer stop];
    self.audioPlayer = nil;
    if (self.videoMusicPlayer) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.videoMusicPlayer.currentItem];
        [self.videoMusicPlayer pause];
        self.videoMusicPlayer = nil;
    }
    self.isPlaying = NO;
    [self updateMusicUI];
}

- (void)nextMusic {
    if (self.musicPaths.count == 0) return;
    if (self.shuffleMode) {
        NSInteger next = arc4random_uniform((uint32_t)self.musicPaths.count);
        while (next == self.currentMusicIndex && self.musicPaths.count > 1) next = arc4random_uniform((uint32_t)self.musicPaths.count);
        [self playMusicAtIndex:next];
    } else {
        NSInteger next = self.currentMusicIndex + 1;
        if (next >= self.musicPaths.count) {
            if (self.loopModeSingle) [self playMusicAtIndex:self.currentMusicIndex];
            else next = 0;
        }
        [self playMusicAtIndex:next];
    }
}

- (void)prevMusic {
    if (self.musicPaths.count == 0) return;
    NSInteger prev = self.currentMusicIndex - 1;
    if (prev < 0) prev = self.musicPaths.count - 1;
    [self playMusicAtIndex:prev];
}

- (void)togglePlayPause {
    BOOL hasPlayer = (self.audioPlayer || self.videoMusicPlayer);
    if (!hasPlayer) {
        if (self.musicPaths.count > 0) [self playMusicAtIndex:self.currentMusicIndex < 0 ? 0 : self.currentMusicIndex];
    } else {
        if (self.isPlaying) {
            if (self.audioPlayer) [self.audioPlayer pause];
            if (self.videoMusicPlayer) [self.videoMusicPlayer pause];
            self.isPlaying = NO;
        } else {
            if (self.audioPlayer) [self.audioPlayer play];
            if (self.videoMusicPlayer) [self.videoMusicPlayer play];
            self.isPlaying = YES;
        }
        [self updateMusicUI];
    }
}

- (void)toggleSpeed {
    self.doubleSpeed = !self.doubleSpeed;
    if (self.audioPlayer) self.audioPlayer.rate = self.doubleSpeed ? 2.0 : 1.0;
    if (self.videoMusicPlayer) self.videoMusicPlayer.rate = self.doubleSpeed ? 2.0 : 1.0;
    [self updateMusicUI];
}

- (void)switchLoopMode {
    if (!self.loopModeSingle && !self.shuffleMode) {
        self.loopModeSingle = YES; self.shuffleMode = NO;
    } else if (self.loopModeSingle) {
        self.loopModeSingle = NO; self.shuffleMode = YES;
    } else {
        self.loopModeSingle = NO; self.shuffleMode = NO;
    }
    [self updateMusicUI];
}

- (void)updateMusicUI {
    [self applyVolume];

    if (self.nowPlayingLabel) {
        if (self.currentMusicIndex >= 0 &&
            self.currentMusicIndex < (NSInteger)self.musicNames.count) {
            self.nowPlayingLabel.text = self.musicNames[(NSUInteger)self.currentMusicIndex];
        } else {
            self.nowPlayingLabel.text = self.isPlaying ? @"播放中" : @"未在播放";
        }
    }
    if (self.playerTitle) {
        if (self.currentMusicIndex >= 0 &&
            self.currentMusicIndex < (NSInteger)self.musicNames.count) {
            self.playerTitle.text = self.musicNames[(NSUInteger)self.currentMusicIndex];
        } else {
            self.playerTitle.text = self.isPlaying ? @"播放中" : @"未在播放";
        }
    }
    if (self.playerPlayBtn) {
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightSemibold];
            [self.playerPlayBtn setImage:[UIImage systemImageNamed:(self.isPlaying ? @"pause.fill" : @"play.fill")
                                                     withConfiguration:cfg]
                                forState:UIControlStateNormal];
        }
    }
    if (self.playerModeBtn) {
        if (@available(iOS 13.0, *)) {
            NSString *ic = self.loopModeSingle ? @"repeat.1" : (self.shuffleMode ? @"shuffle" : @"repeat");
            UIImageSymbolConfiguration *cfg =
                [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
            [self.playerModeBtn setImage:[UIImage systemImageNamed:ic withConfiguration:cfg]
                                forState:UIControlStateNormal];
        }
    }

    if (self.playerCover) {
        if (self.isPlaying) {
            if (![self.playerCover.layer animationForKey:@"lll.spin"]) {
                CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
                spin.fromValue = @0;
                spin.toValue = @(M_PI * 2);
                spin.duration = 12.0;
                spin.repeatCount = HUGE_VALF;
                spin.removedOnCompletion = NO;
                [self.playerCover.layer addAnimation:spin forKey:@"lll.spin"];
            }
        } else {
            [self.playerCover.layer removeAnimationForKey:@"lll.spin"];
        }
    }

    // 顶部灵动岛胶囊
    if (self.isPlaying) {
        NSString *t = (self.currentMusicIndex >= 0 &&
                       self.currentMusicIndex < (NSInteger)self.musicNames.count)
                      ? self.musicNames[(NSUInteger)self.currentMusicIndex]
                      : (self.playerTitle.text ?: @"播放中");
        [LLLMusicIsland updateTitle:t playing:YES];
    } else {
        [LLLMusicIsland updateTitle:nil playing:NO];
    }

    if (self.isPlaying) {
        [self startProgressTimer];
    } else {
        [self stopProgressTimer];
        if (self.progressSlider) self.progressSlider.value = 0;
    }
    if (@available(iOS 13.0, *)) {
        [self.playPauseBtn setImage:[UIImage systemImageNamed:self.isPlaying ? @"pause.fill" : @"play.fill"] forState:UIControlStateNormal];
    }
    [self.speedBtn setTitle:self.doubleSpeed ? @"2x" : @"1x" forState:UIControlStateNormal];
    [self.modeBtn setTitle:self.loopModeSingle ? @"单曲" : (self.shuffleMode ? @"随机" : @"顺序") forState:UIControlStateNormal];
}

- (void)musicCellPlay:(UIButton *)sender {
    NSNumber *idx = objc_getAssociatedObject(sender, "idx");
    if (idx) [self playMusicAtIndex:idx.integerValue];
}

- (void)upEmptyMusic {
    if (self.musicNames.count == 0) {
        UIView *c = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.musict.bounds.size.width,180)];
        UIImageView *iv = [[UIImageView alloc] init];
        iv.translatesAutoresizingMaskIntoConstraints = NO;
        iv.contentMode = UIViewContentModeScaleAspectFit;
        if (@available(iOS 13.0, *)) { iv.image = [UIImage systemImageNamed:@"music.note"]; iv.tintColor = [UIColor colorWithWhite:0.3 alpha:1]; }
        [c addSubview:iv];
        UILabel *l = [[UILabel alloc] init];
        l.text = @"暂无音乐\n将音频文件放入 Documents/music";
        l.textAlignment = NSTextAlignmentCenter;
        l.textColor = [UIColor colorWithWhite:0.4 alpha:1];
        l.numberOfLines = 0;
        l.font = [UIFont systemFontOfSize:14];
        l.translatesAutoresizingMaskIntoConstraints = NO;
        [c addSubview:l];
        [NSLayoutConstraint activateConstraints:@[
            [iv.centerXAnchor constraintEqualToAnchor:c.centerXAnchor], [iv.topAnchor constraintEqualToAnchor:c.topAnchor constant:40], [iv.widthAnchor constraintEqualToConstant:50], [iv.heightAnchor constraintEqualToConstant:50],
            [l.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:16], [l.leadingAnchor constraintEqualToAnchor:c.leadingAnchor constant:20], [l.trailingAnchor constraintEqualToAnchor:c.trailingAnchor constant:-20]
        ]];
        self.musict.backgroundView = c;
    } else self.musict.backgroundView = nil;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (!flag) return;
    if (self.loopModeSingle) {
        [self playMusicAtIndex:self.currentMusicIndex];
    } else {
        if (self.shuffleMode) [self nextMusic];
        else if (self.currentMusicIndex + 1 < self.musicPaths.count) [self playMusicAtIndex:self.currentMusicIndex + 1];
        else [self stopMusic];
    }
}

- (void)videoMusicDidFinish:(NSNotification *)n {
    if (self.loopModeSingle) {
        [self.videoMusicPlayer seekToTime:kCMTimeZero];
        [self.videoMusicPlayer play];
    } else {
        [self nextMusic];
    }
}

#pragma mark - 网易云

- (void)dismissCloudCard {
    if (gLLLCloseCloudCard) { gLLLCloseCloudCard(); gLLLCloseCloudCard = nil; }
}

- (void)openCloudMusic {
    LLLCloudMusic *cm = [LLLCloudMusic shared];
    if (cm.loggedIn) {
        LLLShowSheet(@"网易云音乐", cm.nickname.length ? cm.nickname : @"已登录",
                     @[@"我喜欢的音乐", @"搜索音乐", @"退出登录"], YES,
                     ^(NSInteger idx) {
            if (idx == 0) [self showLikedSongs];
            else if (idx == 1) [self searchCloudMusic];
            else {
                [[LLLCloudMusic shared] logout];
                ShowToast(@"已退出登录", 1.5, YES, NO);
            }
        });
        return;
    }

    __block UIImageView *qrView = nil;
    __block UILabel *hint = nil;

    LLLShowCustomCard(320, 520, ^(UIView *card, void (^close)(void)) {
        gLLLCloseCloudCard = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 392);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 18, w - 32, 24)];
        t.text = @"网易云音乐 · 扫码登录";
        t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        qrView = [[UIImageView alloc] initWithFrame:CGRectMake((w - 200) / 2, 56, 200, 200)];
        qrView.backgroundColor = UIColor.whiteColor;
        qrView.layer.cornerRadius = 10;
        qrView.clipsToBounds = YES;
        qrView.contentMode = UIViewContentModeScaleAspectFit;
        [card addSubview:qrView];

        hint = [[UILabel alloc] initWithFrame:CGRectMake(16, 268, w - 32, 18)];
        hint.text = @"正在获取二维码…";
        hint.font = [UIFont systemFontOfSize:12];
        hint.textColor = [UIColor colorWithWhite:0.7 alpha:1];
        hint.textAlignment = NSTextAlignmentCenter;
        [card addSubview:hint];

        UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        cancel.frame = CGRectMake(14, 300, w - 28, 44);
        cancel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        cancel.layer.cornerRadius = 12;
        [cancel setTitle:@"取消" forState:UIControlStateNormal];
        [cancel setTitleColor:[UIColor colorWithWhite:0.78 alpha:1] forState:UIControlStateNormal];
        cancel.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [cancel addTarget:self action:@selector(dismissCloudCard) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:cancel];
    });

    [cm startLoginWithQR:^(UIImage *qr, NSString *status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (qr) qrView.image = qr;
            if (status.length) hint.text = status;
        });
    } completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissCloudCard];
            ShowToast(msg.length ? msg : (ok ? @"登录成功" : @"登录失败"), 2.2, YES, !ok);
            PlayHaptic(ok);
            if (ok) [self showLikedSongs];
        });
    }];
}

static UITextField *gSearchField = nil;
static void (^gSearchClose)(void) = nil;

- (void)searchCloudMusic {
    if (![LLLCloudMusic shared].loggedIn) {
        ShowToast(@"先登录网易云", 1.5, YES, YES);
        [self openCloudMusic];
        return;
    }

    LLLShowCustomCard(320, 200, ^(UIView *card, void (^close)(void)) {
        gSearchClose = [close copy];
        CGFloat w = card.bounds.size.width > 1 ? card.bounds.size.width : 320;
        card.frame = CGRectMake(0, 0, w, 156);

        UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, w - 32, 22)];
        t.text = @"搜索网易云音乐";
        t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        t.textColor = UIColor.whiteColor;
        t.textAlignment = NSTextAlignmentCenter;
        [card addSubview:t];

        UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(16, 50, w - 32, 38)];
        f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
        f.layer.cornerRadius = 10;
        f.textColor = UIColor.whiteColor;
        f.tintColor = LLLAccentColor();
        f.placeholder = @"歌名 / 歌手";
        f.font = [UIFont systemFontOfSize:14];
        f.autocorrectionType = UITextAutocorrectionTypeNo;
        f.autocapitalizationType = UITextAutocapitalizationTypeNone;
        f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 38)];
        f.leftViewMode = UITextFieldViewModeAlways;
        [card addSubview:f];
        gSearchField = f;

        UIButton *go = [UIButton buttonWithType:UIButtonTypeSystem];
        go.frame = CGRectMake(16, 98, w - 32, 42);
        go.backgroundColor = LLLAccentColor();
        go.layer.cornerRadius = 12;
        [go setTitle:@"搜索" forState:UIControlStateNormal];
        [go setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        go.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [go addTarget:self action:@selector(doCloudSearch) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:go];
    });
}

- (void)doCloudSearch {
    NSString *kw = [gSearchField.text stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!kw.length) { ShowToast(@"先输入关键词", 1.5, YES, YES); return; }

    if (gSearchClose) { gSearchClose(); gSearchClose = nil; }
    gSearchField = nil;

    ShowToast(@"搜索中…", 1.2, YES, NO);
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] searchSongs:kw done:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!songs.count) { ShowToast(err.length ? err : @"没搜到", 2, YES, YES); return; }

            NSMutableArray *titles = [NSMutableArray array];
            for (NSDictionary *sg in songs) {
                [titles addObject:[NSString stringWithFormat:@"%@ - %@", sg[@"name"], sg[@"artist"]]];
            }
            LLLShowList([NSString stringWithFormat:@"“%@” 的结果", kw],
                        [NSString stringWithFormat:@"共 %lu 首", (unsigned long)songs.count],
                        titles, ^(NSInteger idx) {
                if (idx >= 0 && idx < (NSInteger)songs.count) [s playCloudSong:songs[(NSUInteger)idx]];
            });
        });
    }];
}

- (void)packLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;

    NSString *path = objc_getAssociatedObject(g.view, "src");
    NSString *name = objc_getAssociatedObject(g.view, "nm");
    if (!path || !name) return;

    __weak typeof(self) w = self;
    LLLShowSheet(name, @"要不要连平砍粒子一起带上？",
                 @[@"只注材质", @"材质 + 平砍粒子"], NO, ^(NSInteger idx) {
        __strong typeof(w) s = w;
        if (!s) return;

        if (idx == 1) {
            [EffectInjector applyConfig:[EffectInjector defaultConfig]
                             completion:^(BOOL ok, NSString *err) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ShowToast(ok ? @"平砍粒子已就绪" : @"粒子生成失败", 1.8, YES, !ok);
                });
            }];
        }

        if (![s.qp containsObject:path]) {
            [s.qn addObject:name];
            [s.qp addObject:path];
            [s.qt reloadData];
            [s upEmpty:s.qt];
            [s saveQ];
        }
        ShowToast([NSString stringWithFormat:@"已加入队列: %@", name], 1.5, YES, NO);
        PlayHaptic(YES);
    });
}

- (void)showLikedSongs {
    ShowToast(@"正在拉取「我喜欢的音乐」…", 1.2, YES, NO);
    [[LLLCloudMusic shared] loadLikedSongs:^(NSArray<NSDictionary *> *songs, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!songs.count) {
                ShowToast(err.length ? err : @"列表为空", 2.2, YES, YES);
                PlayHaptic(NO);
                return;
            }
            // 列表一次最多渲染 300 条，否则上千个 UIButton 会把主线程干死
            NSUInteger limit = MIN(songs.count, (NSUInteger)5000);
            NSMutableArray *titles = [NSMutableArray arrayWithCapacity:limit];
            for (NSUInteger i = 0; i < limit; i++) {
                NSDictionary *sg = songs[i];
                [titles addObject:[NSString stringWithFormat:@"%@ - %@", sg[@"name"], sg[@"artist"]]];
            }
            NSString *msg = (songs.count > limit)
                ? [NSString stringWithFormat:@"共 %lu 首，先显示前 %lu 首", (unsigned long)songs.count, (unsigned long)limit]
                : [NSString stringWithFormat:@"共 %lu 首", (unsigned long)songs.count];

            LLLShowList(@"我喜欢的音乐", msg, titles, ^(NSInteger idx) {
                if (idx >= 0 && idx < (NSInteger)limit) [self playCloudSong:songs[(NSUInteger)idx]];
            });
        });
    }];
}

- (void)playCloudSong:(NSDictionary *)song {
    NSNumber *sid = song[@"id"];
    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] resolvePlayURL:sid done:^(NSURL *url, NSString *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            if (!url) { ShowToast(err.length ? err : @"拿不到播放地址", 2.2, YES, YES); return; }
            [s.cloudPlayer pause];
            s.cloudPlayer = [AVPlayer playerWithURL:url];
            [s applyVolume];
            [s.cloudPlayer play];
            [LLLMusicIsland updateTitle:(song[@"name"] ?: @"网易云") playing:YES];
            if (s.playerTitle)  s.playerTitle.text  = song[@"name"] ?: @"网易云";
            if (s.playerArtist) s.playerArtist.text = song[@"artist"] ?: @"网易云音乐";
            [s startProgressTimer];
            ShowToast([NSString stringWithFormat:@"播放: %@", song[@"name"]], 2, YES, NO);
        });
    }];
}

#pragma mark - 材质注入

- (void)doInject {
    if (!self.qp.count) { ShowToast(@"队列为空", 1.5, YES, YES); PlayHaptic(NO); return; }
    __weak typeof(self) w = self;
    [ResourceManager injectMats:self.qp names:self.qn cb:^(NSArray *ok, NSArray *fail) {
        __strong typeof(w) s = w;
        if (!s) return;
        NSString *m = [s summaryText:@"注入" ok:ok fail:fail];
        [s showAlert:@"完成" msg:m];
        ShowToast(m,2,YES,fail.count>0);
        PlayHaptic(!fail.count);
    }];
}

// 统一的结果文案，顺带挡住 ok[0] 空数组崩溃
- (NSString *)summaryText:(NSString *)verb ok:(NSArray *)ok fail:(NSArray *)fail {
    NSUInteger okN = ok.count, failN = fail.count;
    if (okN == 0 && failN == 0) return @"没有可处理的项目";
    if (failN == 0) {
        if (okN == 1) return [NSString stringWithFormat:@"成功%@ %@", verb, ok.firstObject];
        return [NSString stringWithFormat:@"成功%@ %lu 项", verb, (unsigned long)okN];
    }
    if (okN == 0) return [NSString stringWithFormat:@"%@失败 %lu 项", verb, (unsigned long)failN];
    return [NSString stringWithFormat:@"部分成功 (%lu/%lu)", (unsigned long)okN, (unsigned long)(okN + failN)];
}

- (void)doClean {
    __weak typeof(self) w = self;
    [self confirm:@"确认清理" msg:@"清空目标目录，保留 pack_manifest.json" dest:YES cb:^{
        [MaterialHUD show:@"清理中..." inView:self.view];
        [ResourceManager cleanTarget:^(BOOL ok, NSUInteger restored, NSUInteger removed, NSUInteger skipped) {
            [MaterialHUD dismiss];
            __strong typeof(w) s = w;
            NSString *m = [NSString stringWithFormat:@"还原 %lu，删除 %lu，跳过 %lu",
                           (unsigned long)restored, (unsigned long)removed, (unsigned long)skipped];
            [s showAlert:@"完成" msg:m];
            ShowToast(m,1.5,YES,!ok);
            if (ok) PlayHaptic(YES);
        }];
    }];
}

- (void)doKill {
    __weak typeof(self) w = self;
    [self confirm:@"清理缓存" msg:@"删除匹配规则的文件" dest:YES cb:^{
        [MaterialHUD show:@"清理中..." inView:self.view];
        [ResourceManager killCacheOnce:^(NSUInteger d, NSUInteger f) {
            [MaterialHUD dismiss];
            __strong typeof(w) s = w;
            NSString *m = f ? [NSString stringWithFormat:@"删除%lu,失败%lu", (unsigned long)d, (unsigned long)f] : [NSString stringWithFormat:@"删除 %lu 个", (unsigned long)d];
            [s showAlert:@"完成" msg:m];
            ShowToast(m,2,YES,f>0);
            if (!f) PlayHaptic(YES);
        }];
    }];
}

- (void)addToQueue:(UIButton *)b {
    NSString *p = objc_getAssociatedObject(b, "p"), *n = objc_getAssociatedObject(b, "n");
    if ([self.qp containsObject:p]) { ShowToast(@"已在队列",1.5,YES,YES); return; }
    [self.qn addObject:n]; [self.qp addObject:p]; [self.qt reloadData]; [self upEmpty:self.qt]; [self saveQ];
    ShowToast([NSString stringWithFormat:@"已添加: %@", n],1.5,YES,NO); PlayHaptic(YES);
    LLLPop(b);
}

- (void)clrQ {
    if (!self.qn.count) { ShowToast(@"已是空的",1,YES,NO); return; }
    [self confirm:@"清空队列" msg:@"移除所有材质包?" dest:YES cb:^{
        [self.qn removeAllObjects]; [self.qp removeAllObjects]; [self.qt reloadData]; [self upEmpty:self.qt]; [self saveQ];
        ShowToast(@"已清空",1.5,YES,NO); PlayHapticWarning();
    }];
}

#pragma mark - 插件注入

- (void)addPluginToQueue:(UIButton *)b {
    NSString *p = objc_getAssociatedObject(b, "p"), *n = objc_getAssociatedObject(b, "n");
    if ([self.plqp containsObject:p]) { ShowToast(@"已在队列",1.5,YES,YES); return; }
    [self.plqn addObject:n]; [self.plqp addObject:p]; [self.pqt reloadData]; [self upEmpty:self.pqt]; [self saveQ];
    ShowToast([NSString stringWithFormat:@"已添加: %@", n],1.5,YES,NO); PlayHaptic(YES);
    LLLPop(b);
}

- (void)clrPQ {
    if (!self.plqn.count) { ShowToast(@"已是空的",1,YES,NO); return; }
    [self confirm:@"清空队列" msg:@"移除所有插件?" dest:YES cb:^{
        [self.plqn removeAllObjects]; [self.plqp removeAllObjects]; [self.pqt reloadData]; [self upEmpty:self.pqt]; [self saveQ];
        ShowToast(@"已清空",1.5,YES,NO); PlayHapticWarning();
    }];
}

- (void)injEC { [self injectPluginsWithType:1]; }
- (void)injBJ { [self injectPluginsWithType:0]; }
- (void)injMisaki { [self injectPluginsWithType:2]; }

#pragma mark - 个人存档（behavior_packs 自选目录）

- (void)injectPersonalSave {
    if (!self.plqp.count) { ShowToast(@"队列为空", 1.5, YES, YES); PlayHaptic(NO); return; }

    NSArray<NSString*> *dirs = behaviorPacksDirs();
    if (dirs.count == 0) {
        ShowToast(@"没找到 behavior_packs 文件夹", 2, YES, YES);
        PlayHaptic(NO);
        return;
    }

    LLLShowList(@"选择模组缓存文件夹", @"插件会合并进你选中的那个目录",
                [dirs valueForKey:@"lastPathComponent"],
                ^(NSInteger idx) {
        if (idx >= 0 && idx < (NSInteger)dirs.count) {
            [self doInjectPluginsToDir:dirs[(NSUInteger)idx]];
        }
    });
}

- (void)doInjectPluginsToDir:(NSString *)dir {
    NSArray *paths = [self.plqp copy];
    NSArray *names = [self.plqn copy];
    if (!paths.count || !dir.length) return;

    [MaterialHUD show:@"注入中..." inView:self.view];
    __weak typeof(self) w = self;
    dispatch_async(g_fileQueue(), ^{
        NSMutableArray *ok = [NSMutableArray new], *fail = [NSMutableArray new];
        for (NSUInteger i = 0; i < paths.count; i++) {
            NSString *name = (i < names.count) ? names[i] : [(NSString *)paths[i] lastPathComponent];
            if ([ResourceManager copyDir:paths[i] to:dir]) [ok addObject:name];
            else                                          [fail addObject:name];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            [MaterialHUD dismiss];
            NSString *m = [s summaryText:@"注入" ok:ok fail:fail];
            [s showAlert:@"完成" msg:m];
            ShowToast(m, 2, YES, fail.count > 0);
            PlayHaptic(!fail.count);
        });
    });
}

- (void)injectPluginsWithType:(NSInteger)type {
    if (!self.plqp.count) { ShowToast(@"队列为空", 1.5, YES, YES); PlayHaptic(NO); return; }
    NSString *msg = type == 0 ? @"注入布吉岛中..." : (type == 2 ? @"注入 Misaki 中..." : @"注入 EC 中...");
    [MaterialHUD show:msg inView:self.view];
    __weak typeof(self) w = self;
    [ResourceManager injectPlugins:self.plqp names:self.plqn type:type cb:^(BOOL found, NSArray *ok, NSArray *fail) {
        [MaterialHUD dismiss];
        __strong typeof(w) s = w;
        if (!s) return;
        if (!found) {
            [s showAlert:@"错误" msg:type==0?@"未找到任何目标目录":(type==2?@"未找到任何目标目录":@"EC目录不存在")];
            ShowToast(@"目标不存在",2,YES,YES);
            return;
        }
        NSString *m = [s summaryText:@"注入" ok:ok fail:fail];
        [s showAlert:@"完成" msg:m];
        ShowToast(m,2,YES,fail.count>0);
        PlayHaptic(!fail.count);
    }];
}

@end
