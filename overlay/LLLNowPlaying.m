//
//  LLLNowPlaying.m
//

#import "LLLNowPlaying.h"

NSString * const LLLNowPlayingDidChange = @"LLLNowPlayingDidChange";

static void (^gCmdHandler)(LLLNPCommand, double) = nil;

@interface LLLNowPlaying ()
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, strong) UIImage *artwork;
@property (nonatomic, copy) NSString *artworkURL;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval elapsedBase;
@property (nonatomic, assign) NSTimeInterval stamp;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) BOOL hasTrack;
@property (nonatomic, assign) BOOL cloudSource;
@end

@implementation LLLNowPlaying

@synthesize title = _title, artist = _artist, artwork = _artwork, artworkURL = _artworkURL,
            duration = _duration, elapsedBase = _elapsedBase, stamp = _stamp,
            playing = _playing, hasTrack = _hasTrack, cloudSource = _cloudSource;

+ (instancetype)shared {
    static LLLNowPlaying *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [LLLNowPlaying new]; });
    return m;
}

+ (void)setCommandHandler:(void (^)(LLLNPCommand, double))handler {
    gCmdHandler = [handler copy];
}

- (void)notify {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:LLLNowPlayingDidChange object:nil];
    });
}

- (NSTimeInterval)elapsed {
    NSTimeInterval e = _elapsedBase;
    if (_playing) e += CFAbsoluteTimeGetCurrent() - _stamp;
    if (_duration > 0.5 && e > _duration) e = _duration;
    return MAX(0, e);
}

- (void)beginTrack:(NSString *)title
            artist:(NSString *)artist
           artwork:(UIImage *)artwork
          duration:(NSTimeInterval)duration
           elapsed:(NSTimeInterval)elapsed {
    [self beginTrack:title artist:artist artwork:artwork artworkURL:nil
            duration:duration elapsed:elapsed cloud:NO];
}

- (void)beginTrack:(NSString *)title
            artist:(NSString *)artist
           artwork:(UIImage *)artwork
        artworkURL:(NSString *)artworkURL
          duration:(NSTimeInterval)duration
           elapsed:(NSTimeInterval)elapsed
             cloud:(BOOL)cloud {
    _title = [title copy];
    _artist = [artist copy];
    _artwork = artwork;
    _artworkURL = [artworkURL copy];
    _duration = MAX(0, duration);
    _elapsedBase = MAX(0, elapsed);
    _stamp = CFAbsoluteTimeGetCurrent();
    _playing = YES;
    _hasTrack = (_title.length > 0);
    _cloudSource = cloud;
    [self notify];
}

- (void)updateElapsed:(NSTimeInterval)elapsed duration:(NSTimeInterval)duration {
    if (!_hasTrack) return;
    _elapsedBase = MAX(0, elapsed);
    if (duration > 0.5) _duration = duration;
    _stamp = CFAbsoluteTimeGetCurrent();
}

- (void)setPlaying:(BOOL)playing {
    if (playing == _playing) return;
    if (playing) _stamp = CFAbsoluteTimeGetCurrent();
    else _elapsedBase = self.elapsed;
    _playing = playing;
    [self notify];
}

- (void)updateArtwork:(UIImage *)artwork {
    if (!artwork) return;
    _artwork = artwork;
    [self notify];
}

- (void)updateArtwork:(UIImage *)artwork url:(NSString *)url {
    if (!artwork) return;
    _artwork = artwork;
    if (url.length) _artworkURL = [url copy];
    [self notify];
}

- (void)stop {
    _title = nil;
    _artist = nil;
    _artwork = nil;
    _artworkURL = nil;
    _duration = 0;
    _elapsedBase = 0;
    _playing = NO;
    _hasTrack = NO;
    _cloudSource = NO;
    [self notify];
}

- (void)send:(LLLNPCommand)cmd value:(double)value {
    void (^h)(LLLNPCommand, double) = gCmdHandler;
    if (!h) return;
    dispatch_async(dispatch_get_main_queue(), ^{ h(cmd, value); });
}

@end
