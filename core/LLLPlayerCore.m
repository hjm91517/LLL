//
//  core/LLLPlayerCore.m  — 4.0
//
//  4.0：取流按"登录态"分两条路 ——
//    已登录 → LLLCloudVIP（eapi 多档，含会员音质）
//    未登录 → LLLGuestMusic（游客通道，免费曲可用）
//  这样不登录也能听，登录了能听更多，不用两套 UI。
//

#import "LLLPlayerCore.h"
#import "LLLNowPlaying.h"
#import "LLLCloudVIP.h"
#import "LLLGuestMusic.h"
#import "LLLCloudMusic.h"
#import "LLLMusicIsland.h"
#import "BaseComponents.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

NSString * const LLLPlayerCoreDidChange = @"LLLPlayerCoreDidChange";

static NSString * const kVolKey   = @"LLL.volume";
static NSString * const kModeKey  = @"LLL.playMode";
static NSString * const kSpeedKey = @"LLL.doubleSpeed";

@interface LLLPlayerCore () <AVAudioPlayerDelegate>
@property (nonatomic, assign, readwrite) LLLPlaySource source;
@property (nonatomic, assign, readwrite) LLLPlayMode mode;
@property (nonatomic, assign, readwrite) BOOL playing;
@property (nonatomic, assign, readwrite) BOOL hasTrack;
@property (nonatomic, assign, readwrite) BOOL doubleSpeed;
@property (nonatomic, copy, readwrite, nullable) NSString *title;
@property (nonatomic, copy, readwrite, nullable) NSString *artist;
@property (nonatomic, strong, readwrite, nullable) UIImage *artwork;
@property (nonatomic, copy, readwrite, nullable) NSString *artworkURL;
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
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
        _localNames   = [NSMutableArray array];
        _localPaths   = [NSMutableArray array];
        _cloudSongs   = [NSMutableArray array];
        _currentIndex = -1;
        _source       = LLLPlaySourceNone;

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
        [s setActive:YES error:NO];
    } @catch (__unused NSException *e) { }
}

- (float)currentVolume {
    float v = [NSUserDefaults.standardUserDefaults floatForKey:kVolKey];
    if (v <= 0.001f) v = 0.8f;
    return v;
}

#pragma mark - 通知

- (void)broadcast {
    [self pushToNowPlaying];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:LLLPlayerCoreDidChange object:nil];
    });
}

- (void)pushToNowPlaying {
    LLLNowPlaying *np = [LLLNowPlaying shared];
    if (!self.hasTrack) {
        [np stop];
        return;
    }
    BOOL cloud = (self.source == LLLPlaySourceCloud);
    if (![np.title isEqualToString:(self.title ?: @"")]) {
        [np beginTrack:self.title
                artist:self.artist
               artwork:self.artwork
            artworkURL:self.artworkURL
              duration:self.duration
               elapsed:[self currentElapsed]
                 cloud:cloud];
    } else {
        [np updateElapsed:[self currentElapsed] duration:self.duration];
        if (self.artwork) [np updateArtwork:self.artwork url:self.artworkURL];
    }
    [np setPlaying:self.playing];
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

    @try { [_audio stop]; } @catch (__unused NSException *e) { }
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
        _artworkURL = nil;
        _duration = 0;
        _hasTrack = NO;
        _currentSong = nil;
        _currentIndex = -1;
    }
}

- (void)observeItemEnd:(AVPlayerItem *)item {
    if (!item) return;

    __weak typeof(self) w = self;
    _endObserver = [NSNotificationCenter.defaultCenter
                    addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                object:item
                                 queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification *note) {
        __strong typeof(w) s = w;
        if (s) [s advanceAutomatically];
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
        [self broadcast];
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
    NSString *name = (index < (NSInteger)self.localNames.count)
                     ? self.localNames[(NSUInteger)index]
                     : path.lastPathComponent;
    NSString *ext = path.pathExtension.lowercaseString;
    BOOL isVideo = ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]);

    self.title = name;
    self.artist = isVideo ? @"本地视频" : @"本地音乐";
    self.artwork = nil;
    self.artworkURL = nil;
    self.hasTrack = YES;

    if (isVideo) {
        NSURL *u = [NSURL fileURLWithPath:path];
        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:u];
        self.video = [AVPlayer playerWithPlayerItem:item];
        self.videoPlayer = self.video;
        self.video.volume = [self currentVolume];
        self.video.rate = self.doubleSpeed ? 2.0f : 1.0f;
        [self observeItemEnd:item];
        [self.video play];
        self.source = LLLPlaySourceLocalVideo;
        self.playing = YES;
        self.duration = 0;
        [LLLMusicIsland attachVideo:self.video];
        [self startHoldTimer];

        __weak typeof(self) wv = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(wv) sv = wv;
            if (!sv) return;
            double d = CMTimeGetSeconds(item.duration);
            if (isfinite(d) && d > 0.1) {
                sv.duration = d;
                [sv broadcast];
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
            self.playing = NO;
            [self broadcast];
            return;
        }
        ap.delegate = self;
        ap.enableRate = YES;
        ap.meteringEnabled = YES;
        ap.volume = [self currentVolume];
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

#pragma mark - 网易云播放（登录 / 免登录两条路）

- (void)playCloudAtIndex:(NSInteger)index {
    if (self.cloudSongs.count == 0) return;
    if (index < 0 || index >= (NSInteger)self.cloudSongs.count) index = 0;

    [self teardownPlaybackKeepQueue:YES];

    self.source = LLLPlaySourceCloud;
    self.currentIndex = index;
    NSDictionary *song = self.cloudSongs[(NSUInteger)index];
    self.currentSong = song;

    self.title    = song[@"name"] ?: @"网易云";
    self.artist   = song[@"artist"] ?: @"网易云音乐";
    self.artwork  = nil;
    self.artworkURL = [song[@"pic"] isKindOfClass:NSString.class] ? song[@"pic"] : nil;
    self.duration = [song[@"dur"] doubleValue];
    self.hasTrack = YES;
    self.playing  = NO;

    NSString *pic = self.artworkURL;
    UIImage *cached = pic.length ? [[LLLCloudVIP shared] cachedArtwork:pic] : nil;
    if (cached) self.artwork = cached;
    [LLLMusicIsland attachVideo:nil];

    [self broadcast];

    self.seekToken++;
    NSUInteger token = self.seekToken;
    NSNumber *sid = song[@"id"];
    __weak typeof(self) w = self;

    if (pic.length && !cached) {
        [[LLLCloudVIP shared] artworkFor:pic done:^(UIImage *img) {
            __strong typeof(w) s = w;
            if (!s || !img) return;
            if (s.seekToken != token) return;
            s.artwork = img;
            [s broadcast];
        }];
    }

    void (^onResolved)(NSURL *, NSString *) = ^(NSURL *url, NSString *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        if (s.seekToken != token) return;

        if (!url) {
            s.playing = NO;
            [s broadcast];
            NSString *msg = err.length ? err : @"这首拿不到音源";
            /* 免登录通道拿不到时，把话说清楚，别让人以为卡住了 */
            if (![LLLCloudMusic shared].loggedIn) {
                msg = [msg stringByAppendingString:@"（会员曲需登录）"];
            }
            ShowToast(msg, 2.4, YES, YES);
            [s scheduleAutoSkipAfter:2.0];
            return;
        }

        AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
        s.cloud = [AVPlayer playerWithPlayerItem:item];
        s.cloud.volume = [s currentVolume];
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
    };

    /* 登录态决定走哪条取流路：登录 → eapi 多档；未登录 → 游客通道 */
    if ([LLLCloudMusic shared].loggedIn) {
        [[LLLCloudVIP shared] resolveStreamURL:sid
                                     duration:[song[@"dur"] doubleValue]
                                         done:onResolved];
    } else {
        [[LLLGuestMusic shared] resolveStreamURL:sid
                                       duration:[song[@"dur"] doubleValue]
                                           done:onResolved];
    }
}

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

- (NSTimeInterval)currentElapsed {
    if (_audio && _audio.duration > 0.01) return MAX(0, _audio.currentTime);
    if (_cloud && _cloud.currentItem) {
        double t = CMTimeGetSeconds(_cloud.currentTime);
        if (isfinite(t)) return MAX(0, t);
    }
    if (_video && _video.currentItem) {
        double t = CMTimeGetSeconds(_video.currentTime);
        if (isfinite(t)) return MAX(0, t);
    }
    return 0;
}

- (void)refreshElapsedAnchor {
    NSTimeInterval e = [self currentElapsed];

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
    if (!self.hasTrack) { [self playFirstFromCurrentSource]; return; }
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
        [self playFirstFromCurrentSource];
        return;
    }
    if (self.playing) [self pause];
    else [self play];
}

- (void)playFirstFromCurrentSource {
    if (self.source == LLLPlaySourceCloud && self.cloudSongs.count) {
        NSInteger idx = (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.cloudSongs.count)
                        ? self.currentIndex : 0;
        [self playCloudAtIndex:idx];
        return;
    }
    if (self.localPaths.count) {
        NSInteger idx = (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.localPaths.count)
                        ? self.currentIndex : 0;
        [self playLocalAtIndex:idx];
        return;
    }
    if (self.cloudSongs.count) {
        [self playCloudAtIndex:0];
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
    [self setMode:(LLLPlayMode)(((NSInteger)self.mode + 1) % 3)];
    ShowToast([self modeLabel], 1.2, YES, NO);
}

- (NSString *)modeLabel {
    switch (self.mode) {
        case LLLPlayModeSingleLoop: return @"单曲循环";
        case LLLPlayModeShuffle:    return @"随机播放";
        default:                    return @"顺序播放";
    }
}

- (void)setDoubleSpeed:(BOOL)fast {
    _doubleSpeed = fast;
    [NSUserDefaults.standardUserDefaults setBool:fast forKey:kSpeedKey];
    if (_audio) _audio.rate = fast ? 2.0f : 1.0f;
    if (_video) _video.rate = fast ? 2.0f : 1.0f;
    [self broadcast];
}

- (void)toggleDoubleSpeed { [self setDoubleSpeed:!self.doubleSpeed]; }

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
    __weak typeof(self) w = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(w) s = w;
        if (s) [s advanceAutomatically];
    });
}

@end
