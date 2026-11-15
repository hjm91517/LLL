//
//  ui/LLLMusicController.m  — 4.0 定稿
//

#import "LLLMusicController.h"
#import "LLLPlayerCore.h"
#import "LLLCloudMusic.h"
#import "LLLCloudVIP.h"
#import "LLLNowPlaying.h"
#import "LLLMusicIsland.h"
#import "BaseComponents.h"
#import "AppTheme.h"

static NSString * const kSourceKey = @"LLL.musicSource";

@interface LLLMusicController ()
@property (nonatomic, assign) LLLMusicSourceKind kind;
@property (nonatomic, strong) NSMutableArray<NSString *> *localNames;
@property (nonatomic, strong) NSMutableArray<NSString *> *localPaths;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *cloudSongs;
@property (nonatomic, assign) BOOL loadingCloud;
@property (nonatomic, weak) id host;
@end

@implementation LLLMusicController

+ (instancetype)shared {
    static LLLMusicController *c;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [LLLMusicController new]; });
    return c;
}

- (instancetype)init {
    if (self = [super init]) {
        _localNames = [NSMutableArray array];
        _localPaths = [NSMutableArray array];
        _cloudSongs = [NSMutableArray array];
        NSInteger k = [NSUserDefaults.standardUserDefaults integerForKey:kSourceKey];
        _kind = (k == 1) ? LLLMusicSourceKindCloud : LLLMusicSourceKindLocal;
    }
    return self;
}

- (void)bindHost:(MainViewController *)host {
    self.host = host;
}

#pragma mark - 数据源

- (LLLMusicSourceKind)sourceKind { return _kind; }

- (void)setSourceKind:(LLLMusicSourceKind)kind {
    if (kind != LLLMusicSourceKindCloud) kind = LLLMusicSourceKindLocal;
    if (_kind == kind) return;
    _kind = kind;
    [NSUserDefaults.standardUserDefaults setInteger:kind forKey:kSourceKey];

    /* 切源只换队列，不打断正在放的那首。
       以前这里顺手 kill 播放器，音频中断回调把宿主另一条分支带起来，
       表现就是"切换到其他页面"。 */
    if (kind == LLLMusicSourceKindCloud) {
        [[LLLPlayerCore shared] setCloudQueueSilently:_cloudSongs];
    } else {
        [[LLLPlayerCore shared] setLocalQueueNames:_localNames paths:_localPaths startAt:-1];
    }
}

- (NSInteger)rowCount {
    return (_kind == LLLMusicSourceKindCloud) ? (NSInteger)_cloudSongs.count
                                              : (NSInteger)_localNames.count;
}

- (NSDictionary *)rowInfoAt:(NSInteger)row {
    if (row < 0 || row >= [self rowCount]) return nil;
    if (_kind == LLLMusicSourceKindCloud) return _cloudSongs[(NSUInteger)row];
    NSString *name = _localNames[(NSUInteger)row];
    return @{ @"name" : name ?: @"", @"artist" : @"本地音乐", @"row" : @(row) };
}

#pragma mark - 播放

- (void)playRow:(NSInteger)row {
    if (row < 0 || row >= [self rowCount]) return;

    if (_kind == LLLMusicSourceKindCloud) {
        [[LLLPlayerCore shared] setCloudQueue:_cloudSongs startAt:row];
    } else {
        [[LLLPlayerCore shared] setLocalQueueNames:_localNames paths:_localPaths startAt:row];
    }
    [LLLMusicIsland refresh];
}

- (void)togglePlayPause { [[LLLPlayerCore shared] togglePlayPause]; }
- (void)nextTrack { [[LLLPlayerCore shared] next]; }
- (void)previousTrack { [[LLLPlayerCore shared] previous]; }
- (void)toggleMode { [[LLLPlayerCore shared] cycleMode]; }
- (void)toggleSpeed { [[LLLPlayerCore shared] toggleDoubleSpeed]; }

- (void)seekRatio:(float)ratio {
    LLLPlayerCore *core = [LLLPlayerCore shared];
    double d = core.duration;
    if (d <= 0.5) return;
    double target = MAX(0, MIN(1, (double)ratio)) * d;
    [core seekTo:target];
}

#pragma mark - 本地扫描

- (void)reloadLocal {
    __weak typeof(self) w = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSMutableArray *names = [NSMutableArray array];
        NSMutableArray *paths = [NSMutableArray array];
        scanMusicFiles(^(NSString *name, NSString *path) {
            if (name.length && path.length) {
                [names addObject:name];
                [paths addObject:path];
            }
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(w) s = w;
            if (!s) return;
            [s.localNames setArray:names];
            [s.localPaths setArray:paths];
            if (s.kind == LLLMusicSourceKindLocal) {
                [[LLLPlayerCore shared] setLocalQueueNames:s.localNames
                                                     paths:s.localPaths
                                                   startAt:-1];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LLLMusicDataDidChange" object:nil];
        });
    });
}

#pragma mark - 网易云

- (void)reloadCloudLiked {
    if (_loadingCloud) return;
    if (![LLLCloudMusic shared].loggedIn) {
        __weak typeof(self) w = self;
        [[LLLCloudMusic shared] refreshAccountIfNeeded:^(BOOL ok) {
            __strong typeof(w) s = w;
            if (ok && s) [s reloadCloudLiked];
        }];
        return;
    }
    _loadingCloud = YES;

    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loadLikedSongs:^(NSArray<NSDictionary *> *songs, NSString *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        s.loadingCloud = NO;

        if (!songs.count) {
            if (err.length) ShowToast(err, 2.0, YES, YES);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"LLLMusicDataDidChange" object:nil];
            return;
        }

        [s.cloudSongs setArray:songs];
        if (s.kind == LLLMusicSourceKindCloud) {
            [[LLLPlayerCore shared] setCloudQueueSilently:s.cloudSongs];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LLLMusicDataDidChange" object:nil];
        ShowToast([NSString stringWithFormat:@"网易云 · %lu 首", (unsigned long)songs.count],
                  1.6, YES, NO);
    }];
}

- (void)reloadCloudDaily {
    if (_loadingCloud) return;
    if (![LLLCloudMusic shared].loggedIn) { [self reloadCloudLiked]; return; }
    _loadingCloud = YES;

    __weak typeof(self) w = self;
    [[LLLCloudMusic shared] loadDailyRecommend:^(NSArray<NSDictionary *> *songs, NSString *err) {
        __strong typeof(w) s = w;
        if (!s) return;
        s.loadingCloud = NO;
        if (!songs.count) { [s reloadCloudLiked]; return; }

        [s.cloudSongs setArray:songs];
        if (s.kind == LLLMusicSourceKindCloud) {
            [[LLLPlayerCore shared] setCloudQueueSilently:s.cloudSongs];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LLLMusicDataDidChange" object:nil];
    }];
}

- (void)syncCloudQueueToCore {
    [[LLLPlayerCore shared] setCloudQueueSilently:_cloudSongs];
}

#pragma mark - 卡片文案

- (NSString *)cardTitle {
    LLLPlayerCore *core = [LLLPlayerCore shared];
    if (core.hasTrack) return core.title ?: @"未在播放";
    NSInteger n = [self rowCount];
    if (n > 0) return @"未在播放";
    return (_kind == LLLMusicSourceKindCloud) ? @"网易云还没拉取" : @"本地目录是空的";
}

- (NSString *)cardSubtitle {
    LLLPlayerCore *core = [LLLPlayerCore shared];
    if (core.hasTrack) {
        NSString *src = (core.source == LLLPlaySourceCloud) ? @"网易云" :
                        ((core.source == LLLPlaySourceLocalVideo) ? @"本地视频" : @"本地音乐");
        NSString *artist = core.artist.length ? core.artist : src;
        return [NSString stringWithFormat:@"%@ · %@", artist, src];
    }
    return @"点列表里任意一首开始";
}

- (NSString *)cardTimeText {
    LLLPlayerCore *core = [LLLPlayerCore shared];
    NSTimeInterval cur = [core currentElapsed], total = core.duration;
    if (!isfinite(cur) || cur < 0) cur = 0;
    if (!isfinite(total) || total < 0) total = 0;
    return [NSString stringWithFormat:@"%d:%02d / %d:%02d",
            (int)(cur / 60), (int)fmod(cur, 60),
            (int)(total / 60), (int)fmod(total, 60)];
}

- (BOOL)cardPlaying { return [LLLPlayerCore shared].playing; }
- (LLLPlayMode)playMode { return [LLLPlayerCore shared].mode; }
- (BOOL)isDoubleSpeed { return [LLLPlayerCore shared].doubleSpeed; }

@end
