//
//  LLLPlayerCore.m
//

#import "LLLPlayerCore.h"
#import "LLLNowPlaying.h"
#import "LLLCloudMusic.h"
#import "LLLCloudVIP.h"
#import "LLLMusicIsland.h"
#import "BaseComponents.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

NSString * const LLLPlayerCoreDidChange = @"LLLPlayerCoreDidChange";

static NSString * const kVolKey    = @"LLL.volume";
static NSString * const kModeKey   = @"LLL.playMode";
static NSString * const kSpeedKey  = @"LLL.doubleSpeed";

@interface LLLPlayerCore ()
@property (nonatomic, assign, readwrite) LLLPlaySource source;
@property (nonatomic, assign, readwrite) LLLPlayMode mode;
@property (nonatomic, assign, readwrite) BOOL playing;
@property (nonatomic, assign, readwrite) BOOL hasTrack;
@property (nonatomic, assign, readwrite) BOOL doubleSpeed;
@property (nonatomic, copy, readwrite, nullable) NSString *title;
@property (nonatomic, copy, readwrite, nullable) NSString *artist;
@property (nonatomic, strong, readwrite, nullable) UIImage *artwork;
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
@property (nonatomic, assign, readwrite) NSTimeInterval elapsed;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@property (nonatomic, assign, readwrite) NSUInteger queueCount;
@property (nonatomic, strong, readwrite, nullable) NSDictionary *currentSong;
@property (nonatomic, strong, readwrite, nullable) AVPlayer *videoPlayer;

@property (nonatomic, strong) NSMutableArray<NSString *> *localNames;
@property (nonatomic, strong) NSMutableArray<NSString *> *localPaths;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *cloudSongs;

@property (nonatomic, strong) AVAudioPlayer *audio;
@property (nonatomic, strong) AVPlayer *cloud;
@property (nonatomic, strong) AVPlayer *video;
@property (nonatomic, strong) id endObserver;
@property (nonatomic, strong) id failObserver;

/// 请求序号：连续切歌时丢弃过期的取流回调，防止 A 的地址盖掉 B
@property (nonatomic, assign) NSUInteger seekToken;
@property (nonatomic, strong) NSTimer *holdTimer;
@end

@implementation LLLPlayerCore

+ (instancetype)shared {
    static LLLPlayerCore *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [LLLPlayerCore new]; });
    return c;
}

- (instancetype)init {
    if (self = [super init]) {
        _localNames  = [NSMutableArray array];
        _localPaths  = [NSMutableArray array];
        _cloudSongs  = [NSMutableArray array];
        _currentIndex = -1;
        _source = LLLPlaySourceNone;

        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        NSInteger m = [d integerForKey:kModeKey];
        if (m < 0 || m > 2) m = 0;
        _mode = (LLLPlayMode)m;
        _doubleSpeed = [d boolForKey:kSpeedKey];

        [self setupAudioSession];
    }
    return self;
}

#pragma mark - 会话

- (void)setupAudioSession {
    @try {
        AVAudioSession *s = AVAudioSession.sharedInstance;
        [s setCategory:AVAudioSessionCategoryPlayback
                  mode:AVAudioSessionModeDefault
               options:AVAudioSessionCategoryOptionMixWithOthers |
                       AVAudioSessionCategoryOptionDuckOthers
                 error:nil];
        [s setActive:YES error:nil];
    } @catch (__unused NSException *e) { }
}

- (float)volume {
    float v = [NSUserDefaults.standardUserDefaults floatForKey:kVolKey];
    if (v <= 0.001f) v = 0.8f;
    return v;
}

#pragma mark - 通知

- (void)broadcast {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:LLLPlayerCoreDidChange object:nil];
    });
    [self pushToNowPlaying];
}

/// 内核 → LLLNowPlaying（灵动岛只读那边，所以必须同步）
- (void)pushToNowPlaying {
    LLLNowPlaying *np = [LLLNowPlaying shared];
    if (!self.hasTrack) {
        [np stop];
        return;
    }
    if (![np.title isEqualToString:self.title ?: @""]) {
        [np beginTrack:self.title
                artist:self.artist
               artwork:self.artwork
              duration:self.duration
               elapsed:self.elapsed];
        [np setPlaying:self.playing];
    } else {
        [np updateElapsed:self.elapsed duration:self.duration];
        [np setPlaying:self.playing];
        if (self.artwork && np.artwork != self.artwork) [np updateArtwork:self.artwork];
    }
}

#pragma mark - 拆旧播放器

- (void)teardownPlaybackKeepQueue:(BOOL)keep {
    [self.holdTimer invalidate];
    self.holdTimer = nil;

    if (_endObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:_endObserver];
        _endObserver = nil;
    }
    if (_failObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:_failObserver];
        _failObserver = nil;
    }

    @try {
        [_audio stop];
    } @catch (__unused NSException *e) { }
    _audio = nil;

    [_cloud pause];
    _cloud = nil;

    [_video pause];
    _video = nil;
    _videoPlayer = nil;

    [LLLMusicIsland attachVideo:nil];

    _playing = NO;
    if (!keep) {
        _title = nil;
        _artist = nil;
        _artwork = nil;
        _duration = 0;
        _elapsed = 0;
        _hasTrack = NO;
        _currentSong = nil;
        _currentIndex = -1;
    }
}

- (void)observeItemEnd:(AVPlayerItem *)item {
    if (_endObserver) {
        [NSNotificationCenter.defaultCenter removeObserver:_endObserver];
        _endObserver = nil;
    }
    if (!item) return;

    __weak typeof(self) w = self;
    _endObserver = [NSNotificationCenter.defaultCenter
                    addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                object:item
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification *note) {
        __strong typeof(w) s = w;
        if (!s) return;
        [s advanceAutomatically];
    }];

    _failObserver = [NSNotificationCenter.defaultCenter
                     addObserverForName:AVPlayerItemFailedToPlayToEndTimeNotification
                                 object:item
                                  queue:NSOperationQueue.mainQueue
                             usingBlock:^(NSNotification *note) {
        __strong typeof(w) s = w;
        if (!s) return;
        lllLog(@"播放失败: %@", note.userInfo);
        [s advanceAutomatically];
    }];
}

#pragma mark - 队列

- (void)setLocalQueueNames:(NSArray<NSString *> *)names
                     paths:(NSArray<NSString *> *)paths
                   startAt:(NSInteger)index {
    [self.localNames removeAllObjects];
    [self.localPaths removeAllObjects];

    NSUInteger n = MIN(names.count, paths.count);
    for (NSUInteger i = 0; i < n; i++) {
        [self.localNames addObject:names[i] ?: @""];
        [self.localPaths addObject:paths[i] ?: @""];
    }
    self.queueCount = n;
    if (index < 0 || index >= (NSInteger)n) {
        self.currentIndex = (n > 0) ? 0 : -1;
        self.broadcast;
        return;
    }
    [self playLocalAtIndex:index];
}

- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs startAt:(NSInteger)index {
    [self.cloudSongs removeAllObjects];
    for (NSDictionary *s in songs) {
        if ([s isKindOfClass:NSDictionary.class]) [self.cloudSongs addObject:s];
    }
    self.queueCount = self.cloudSongs.count;

    if (index < 0 || index >= (NSInteger)self.cloudSongs.count) {
        self.currentIndex = self.cloudSongs.count ? 0 : -1;
        [self broadcast];
        return;
    }
    [self playCloudAtIndex:index];
}

- (void)setCloudQueueSilently:(NSArray<NSDictionary *> *)songs {
    [self.cloudSongs removeAllObjects];
    for (NSDictionary *s in songs) {
        if ([s isKindOfClass:NSDictionary.class]) [self.cloudSongs addObject:s];
    }
    self.queueCount = self.cloudSongs.count;
    if (self.source != LLLPlaySourceCloud) self.currentIndex = -1;
    [self broadcast];
}

#pragma mark - 本地播放

- (void)playLocalAtIndex:(NSInteger)index {
    if (self.localPaths.count == 0) return;
    if (index < 0 || index >= (NSInteger)self.localPaths.count) index = 0;

    [self teardownPlaybackKeepQueue:YES];

    self.source = LLLPlaySourceNone;
    self.currentIndex = index;
    NSString *path = self.localPaths[(NSUInteger)index];
    NSString *name = (index < (NSInteger)self.localNames.count) ? self.localNames[(NSUInteger)index]
                                                                : path.lastPathComponent;
    NSString *ext = path.pathExtension.lowercaseString;
    BOOL isVideo = ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]);

    self.title = name;
    self.artist = isVideo ? @"本地视频" : @"本地音乐";
    self.artwork = nil;
    self.elapsed = 0;
    self.hasTrack = YES;

    if (isVideo) {
        NSURL *u = [NSURL fileURLWithPath:path];
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:u];
        self.video = [AVPlayer playerWithPlayerItem:item];
        self.videoPlayer = self.video;
        self.video.volume = [self volume];
        self.video.rate = self.doubleSpeed ? 2.0f : 1.0f;
        [self observeItemEnd:item];
        [self.video play];
        self.source = LLLPlaySourceLocalVideo;
        self.playing = YES;
        self.duration = 0;
        [LLLMusicIsland attachVideo:self.video];
        [self startHoldTimer];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            double d = CMTimeGetSeconds(item.duration);
            if (isfinite(d) && d > 0.1) {
                self.duration = d;
                [self broadcast];
            }
        });
    } else {
        NSError *err = nil;
        AVAudioPlayer *ap = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                                   error:&err];
        if (!ap) {
            lllLog(@"本地音频打开失败 %@: %@", name, err);
            ShowToast([NSString stringWithFormat:@"打不开: %@", name], 2, YES, YES);
            self.hasTrack = NO;
            self.title = nil;
            [self broadcast];
            return;
        }
        ap.delegate = (id<AVAudioPlayerDelegate>)self;
        ap.enableRate = YES;
        ap.meteringEnabled = YES;
        ap.volume = [self volume];
        ap.rate = self.doubleSpeed ? 2.0f : 1.0f;
        [ap prepareToPlay];
        [ap play];
        self.audio = ap;
        self.source = LLLPlaySourceLocalAudio;
        self.playing = YES;
        self.duration = ap.duration;
        [self startHoldTimer];
    }

    [self broadcast];
}

/// 本地播放器的进度靠系统时钟插值，这里给 NowPlaying 打锚点
- (void)startHoldTimer {
    [self.holdTimer invalidate];
    __weak typeof(self) w = self;
    self.holdTimer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        __strong typeof(w) s = w;
        if (!s) { [t invalidate]; return; }
        [s refreshElapsedAnchor];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.holdTimer forMode:NSRunLoopCommonModes];
}

#pragma mark - 网易云播放

- (void)playCloudAtIndex:(NSInteger)index {
    if (self.cloudSongs.count == 0) return;
    if (index < 0 || index >= (NSInteger)self.cloudSongs.count) index = 0;

    [self teardownPlaybackKeepQueue:YES];

    self.source = LLLPlaySourceCloud;
    self.currentIndex = index;
    NSDictionary *song = self.cloudSongs[(NSUInteger)index];
    self.currentSong = song;

    self.title  = song[@"name"] ?: @"网易云";
    self.artist = song[@"artist"] ?: @"网易云音乐";
    self.artwork = nil;
    self.elapsed = 0;
    self.duration = [song[@"dur"] doubleValue];
    self.hasTrack = YES;
    self.playing = NO;      /* 地址到手才算真正开播 */

    /* 封面：先抢缓存，再异步拉原图，拉到了立刻刷灵动岛圆盘 */
    NSString *pic = song[@"pic"];
    UIImage *cached = pic.length ? [[LLLCloudVIP shared] cachedArtwork:pic] : nil;
    if (cached) {
        self.artwork = cached;
        [LLLMusicIsland attachVideo:nil];
    }

    [self broadcast];

    self.seekToken++;
    NSUInteger token = self.seekToken;
    NSNumber *sid = song[@"id"];

    __weak typeof(self) w = self;

    if (pic.length && !cached) {
        [[LLLCloudVIP shared] artworkFor:pic done:^(UIImage *img) {
            __strong typeof(w) s = w;
            if (!s || !img) return;
            if (s.seekToken != token) return;       /* 已经切歌了，别乱贴图 */
            s.artwork = img;
            [s broadcast];
        }];
    }

    [[LLLCloudVIP shared] resolveStreamURL:sid
                                  duration:[song[@"dur"] doubleValue]
                                      done:^(NSURL *url, NSString *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        /* 关键：丢了 token 的旧回调直接扔，否则手快切歌会串音 */
        if (s.seekToken != token) return;

        if (!url) {
            s.playing = NO;
            s.hasTrack = YES;
            [s broadcast];
            ShowToast(err.length ? err : @"这首拿不到音源", 2.2, YES, YES);
            [s scheduleAutoSkipAfter:2.0];
            return;
        }

        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        s.cloud = [AVPlayer playerWithPlayerItem:item];
        s.cloud.volume = [s volume];
        [s observeItemEnd:item];
        [s.cloud play];
        s.playing = YES;
        [s startHoldTimer];
        [s broadcast];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(w) s2 = w;
            if (!s2 || s2.seekToken != token) return;
            double d = CMTimeGetSeconds(item.duration);
            if (isfinite(d) && d > 0.5 && fabs(d - s2.duration) > 1.0) {
                s2.duration = d;
                [s2 broadcast];
            }
        });
    }];
}

/// 拿不到音源时别卡在那儿，过几秒自动下一首
- (void)scheduleAutoSkipAfter:(NSTimeInterval)delay {
    __weak typeof(self) w = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(w) s = w;
        if (!s || s.playing) return;
        [s next];
    });
}

#pragma mark - 进度

- (NSTimeInterval)elapsed {
    if (_audio && _audio.duration > 0.01) return _audio.currentTime;
    if (_cloud && _cloud.currentItem) {
        double t = CMTimeGetSeconds(_cloud.currentTime);
        if (isfinite(t)) return MAX(0, t);
    }
    if (_video && _video.currentItem) {
        double t = CMTimeGetSeconds(_video.currentTime);
        if (isfinite(t)) return MAX(0, t);
    }
    return _elapsed;
}

- (void)refreshElapsedAnchor {
    NSTimeInterval e = self.elapsed;
    _elapsed = e;
    NSTimeInterval d = self.duration;
    if (d <= 0.01 && _audio) d = _audio.duration;
    if (d <= 0.01 && _cloud.currentItem) {
        double dd = CMTimeGetSeconds(_cloud.currentItem.duration);
        if (isfinite(dd) && dd > 0.1) d = dd;
    }
    if (d > 0.01 && fabs(d - _duration) > 0.5) {
        _duration = d;
        [self broadcast];
        return;
    }
    [[LLLNowPlaying shared] updateElapsed:e duration:_duration];
}

#pragma mark - 控制

- (void)play {
    if (!self.hasTrack) {
        if (self.queueCount) [self next];
        return;
    }
    if (_audio) [_audio play];
    if (_cloud) [_cloud play];
    if (_video) {
        _video.rate = self.doubleSpeed ? 2.0f : 1.0f;
        [_video play];
    }
    _playing = YES;
    [self startHoldTimer];
    [self broadcast];
}

- (void)pause {
    if (_audio) [_audio pause];
    if (_cloud) [_cloud pause];
    if (_video) [_video pause];
    _playing = NO;
    [self refreshElapsedAnchor];
    [self broadcast];
}

- (void)togglePlayPause {
    if (!self.hasTrack || self.queueCount == 0) {
        /* 没播过东西：按当前数据源起播，绝不空手返回 —— 这就是卡片按钮"不管用"的根因 */
        [self playFirstFromCurrentSource];
        return;
    }
    if (self.playing) [self pause];
    else [self play];
}

- (void)playFirstFromCurrentSource {
    if (self.source == LLLPlaySourceCloud || self.source == LLLPlaySourceNone) {
        if (self.cloudSongs.count) {
            NSInteger idx = (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.cloudSongs.count)
                            ? self.currentIndex : 0;
            [self playCloudAtIndex:idx];
            return;
        }
    }
    if (self.localPaths.count) {
        NSInteger idx = (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.localPaths.count)
                        ? self.currentIndex : 0;
        [self playLocalAtIndex:idx];
        return;
    }
    ShowToast(@"队列是空的", 1.5, YES, YES);
}

- (void)next {
    NSInteger n = (self.source == LLLPlaySourceCloud) ? (NSInteger)self.cloudSongs.count
                                                      : (NSInteger)self.localPaths.count;
    if (n <= 0) return;

    NSInteger idx = self.currentIndex;
    if (self.mode == LLLPlayModeShuffle && n > 1) {
        NSInteger r = idx;
        for (int guard = 0; guard < 24 && r == idx; guard++) r = (NSInteger)arc4random_uniform((uint32_t)n);
        idx = r;
    } else {
        idx = (idx < 0) ? 0 : (idx + 1);
        if (idx >= n) idx = 0;
    }
    [self playAtUnifiedIndex:idx];
}

- (void)previous {
    NSInteger n = (self.source == LLLPlaySourceCloud) ? (NSInteger)self.cloudSongs.count
                                                      : (NSInteger)self.localPaths.count;
    if (n <= 0) return;

    NSInteger idx = self.currentIndex;
    if (self.mode == LLLPlayModeShuffle && n > 1) {
        NSInteger r = idx;
        for (int guard = 0; guard < 24 && r == idx; guard++) r = (NSInteger)arc4random_uniform((uint32_t)n);
        idx = r;
    } else {
        idx = (idx <= 0) ? (n - 1) : (idx - 1);
    }
    [self playAtUnifiedIndex:idx];
}

- (void)playAtUnifiedIndex:(NSInteger)idx {
    if (self.source == LLLPlaySourceCloud) [self playCloudAtIndex:idx];
    else                                   [self playLocalAtIndex:idx];
}

- (void)advanceAutomatically {
    if (self.mode == LLLPlayModeSingleLoop) {
        [self seekTo:0];
        [self play];
        return;
    }
    NSInteger n = (self.source == LLLPlaySourceCloud) ? (NSInteger)self.cloudSongs.count
                                                      : (NSInteger)self.localPaths.count;
    if (n <= 0) return;

    if (self.mode == LLLPlayModeSequential && self.currentIndex + 1 >= n) {
        /* 顺序模式到头：停了，别偷偷跳回第一首装作循环 */
        [self pause];
        [self seekTo:0];
        return;
    }
    [self next];
}

- (void)seekTo:(NSTimeInterval)seconds {
    if (seconds < 0) seconds = 0;
    if (_audio) {
        if (seconds > _audio.duration) seconds = _audio.duration;
        _audio.currentTime = seconds;
    }
    if (_cloud) {
        [_cloud seekToTime:CMTimeMakeWithSeconds(seconds, 600)
           toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
    if (_video) {
        [_video seekToTime:CMTimeMakeWithSeconds(seconds, 600)
           toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
    _elapsed = seconds;
    [[LLLNowPlaying shared] updateElapsed:seconds duration:self.duration];
    [self broadcast];
}

- (void)setMode:(LLLPlayMode)mode {
    if (mode < 0 || mode > 2) mode = 0;
    _mode = mode;
    [NSUserDefaults.standardUserDefaults setInteger:mode forKey:kModeKey];
    [self broadcast];
}

- (void)cycleMode {
    LLLPlayMode m = (LLLPlayMode)(((NSInteger)self.mode + 1) % 3);
    [self setMode:m];
    ShowToast(m == LLLPlayModeSingleLoop ? @"单曲循环"
            : (m == LLLPlayModeShuffle ? @"随机播放" : @"顺序播放"), 1.2, YES, NO);
}

- (void)setDoubleSpeed:(BOOL)fast {
    _doubleSpeed = fast;
    [NSUserDefaults.standardUserDefaults setBool:fast forKey:kSpeedKey];
    if (_audio) _audio.rate = fast ? 2.0f : 1.0f;
    if (_video) _video.rate = fast ? 2.0f : 1.0f;
    [self broadcast];
}

- (void)toggleDoubleSpeed {
    [self setDoubleSpeed:!self.doubleSpeed];
}

- (void)setVolume:(float)volume {
    if (volume < 0) volume = 0;
    if (volume > 1) volume = 1;
    [NSUserDefaults.standardUserDefaults setFloat:volume forKey:kVolKey];
    _audio.volume = volume;
    _cloud.volume = volume;
    _video.volume = volume;
}

- (void)stop {
    [self teardownPlaybackKeepQueue:NO];
    [self broadcast];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (!flag) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self advanceAutomatically];
    });
}

@end
