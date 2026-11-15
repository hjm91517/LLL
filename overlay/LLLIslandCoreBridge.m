//
//  LLLIslandCoreBridge.m
//

#import "LLLIslandCoreBridge.h"
#import "LLLPlayerCore.h"
#import "LLLNowPlaying.h"
#import "LLLMusicIsland.h"
#import "BaseComponents.h"

@implementation LLLIslandCoreBridge

+ (instancetype)shared {
    static LLLIslandCoreBridge *b;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ b = [LLLIslandCoreBridge new]; });
    return b;
}

- (void)install {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        /* LLLNowPlaying 的命令回调统一转给内核。
           以前这里分叉：cloudPlayer 在就动 cloudPlayer，不在就 togglePlayPause，
           于是本地/网易云两套状态互相打脸 —— 现在只有一个真相源。 */
        [LLLNowPlaying setCommandHandler:^(LLLNPCommand cmd, double value) {
            LLLPlayerCore *core = [LLLPlayerCore shared];
            switch (cmd) {
                case LLLNPCommandTogglePlay: [core togglePlayPause]; break;
                case LLLNPCommandNext:       [core next]; break;
                case LLLNPCommandPrevious:   [core previous]; break;
                case LLLNPCommandSeek:       [core seekTo:value]; break;
                case LLLNPCommandVolume:     [core setVolume:(float)value]; break;
                case LLLNPCommandCycleMode:  [core cycleMode]; break;
            }
        }];

        /* 内核状态变化 → 岛上刷一遍 */
        [NSNotificationCenter.defaultCenter
         addObserverForName:LLLPlayerCoreDidChange
                     object:nil
                      queue:NSOperationQueue.mainQueue
                 usingBlock:^(NSNotification *note) {
            [LLLMusicIsland refresh];
        }];
    });
}

- (void)togglePlayPause { [[LLLPlayerCore shared] togglePlayPause]; }
- (void)playNext        { [[LLLPlayerCore shared] next]; }
- (void)playPrevious    { [[LLLPlayerCore shared] previous]; }

- (void)seek:(NSTimeInterval)seconds {
    [[LLLPlayerCore shared] seekTo:seconds];
}

- (void)setVolume:(float)volume {
    [[LLLPlayerCore shared] setVolume:volume];
}

- (void)cycleMode {
    [[LLLPlayerCore shared] cycleMode];
}

- (NSString *)modeLabel {
    switch ([LLLPlayerCore shared].mode) {
        case LLLPlayModeSingleLoop: return @"单曲";
        case LLLPlayModeShuffle:    return @"随机";
        default:                    return @"顺序";
    }
}

- (NSString *)modeSymbol {
    switch ([LLLPlayerCore shared].mode) {
        case LLLPlayModeSingleLoop: return @"repeat.1";
        case LLLPlayModeShuffle:    return @"shuffle";
        default:                    return @"repeat";
    }
}

@end
