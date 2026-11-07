#import "MainViewController+Features.h"
#import "MainViewController_Private.h"
#import "ResourceManager.h"
#import "BaseComponents.h"
#import "LLLAnim.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

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
        self.audioPlayer.rate = self.doubleSpeed ? 2.0 : 1.0;
        [self.audioPlayer prepareToPlay];
        [self.audioPlayer play];
        self.isPlaying = YES;
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

#pragma mark - 材质注入

- (void)doInject {
    if (!self.qp.count) { ShowToast(@"队列为空", 1.5, YES, YES); PlayHaptic(NO); return; }
    [MaterialHUD show:@"注入中..." inView:self.view];
    __weak typeof(self) w = self;
    [ResourceManager injectMats:self.qp names:self.qn cb:^(NSArray *ok, NSArray *fail) {
        [MaterialHUD dismiss];
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
        [ResourceManager cleanTarget:^(BOOL ok) {
            [MaterialHUD dismiss];
            __strong typeof(w) s = w;
            NSString *m = ok ? @"已清理" : @"失败";
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
