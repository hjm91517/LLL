//
//  LLLPlayerCore.h  — 4.0
//  统一播放内核：本地音乐、本地视频、网易云共用一套状态机。
//
//  以前本地音乐走 audioPlayer/videoMusicPlayer，网易云走 cloudPlayer，
//  两套播放器 + 两套状态 + 两套通知 —— 切源跳页、卡片按钮只管本地、
//  顺序播放对网易云完全失效，根子都在这里。
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LLLPlaySource) {
    LLLPlaySourceNone = 0,
    LLLPlaySourceLocalAudio,   ///< Documents/music 下的 mp3/m4a/wav...
    LLLPlaySourceLocalVideo,   ///< Documents/music 下的 mp4/mov
    LLLPlaySourceCloud,        ///< 网易云
};

typedef NS_ENUM(NSInteger, LLLPlayMode) {
    LLLPlayModeSequential = 0, ///< 顺序播放（放到列表尾就停）
    LLLPlayModeSingleLoop,     ///< 单曲循环
    LLLPlayModeShuffle,        ///< 随机
};

/// 核心状态变化（标题 / 播放态 / 队列切换 / 进度跳变）都发这条
extern NSString * const LLLPlayerCoreDidChange;

@interface LLLPlayerCore : NSObject

+ (instancetype)shared;

#pragma mark - 只读状态

@property (nonatomic, assign, readonly) LLLPlaySource source;
@property (nonatomic, assign, readonly) LLLPlayMode mode;
@property (nonatomic, assign, readonly) BOOL playing;
@property (nonatomic, assign, readonly) BOOL hasTrack;
@property (nonatomic, assign, readonly) BOOL doubleSpeed;
@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *artist;
@property (nonatomic, strong, readonly, nullable) UIImage *artwork;
/// 封面来源地址（网易云曲图），供灵动岛校验"图是不是这首歌的"
@property (nonatomic, copy, readonly, nullable) NSString *artworkURL;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign, readonly) NSUInteger queueCount;

/// 当前曲目在队列里的字典（网易云才有，本地为 nil）
@property (nonatomic, strong, readonly, nullable) NSDictionary *currentSong;

/// 本地视频画面（只有 LLLPlaySourceLocalVideo 时非空）
@property (nonatomic, strong, readonly, nullable) AVPlayer *videoPlayer;

/// 已播秒数。**方法，不是属性** —— 播放中实时从底层播放器读，
/// 别缓存成属性，否则切歌 / seek 之后会读到旧值。
- (NSTimeInterval)currentElapsed;

/// 模式中文名（顺序播放 / 单曲循环 / 随机播放）
- (NSString *)modeLabel;

#pragma mark - 队列

/// 本地队列：names 与 paths 一一对应，index 为起始曲目（-1 表示只换队列不播）
- (void)setLocalQueueNames:(NSArray<NSString *> *)names
                     paths:(NSArray<NSString *> *)paths
                   startAt:(NSInteger)index;

/// 网易云队列：songs 是 mapTracks 的输出（id/name/artist/pic/dur）
- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs startAt:(NSInteger)index;

/// 只更新队列不播放（切源时用，避免立刻出声）
- (void)setCloudQueueSilently:(NSArray<NSDictionary *> *)songs;

#pragma mark - 播放控制

- (void)play;
- (void)pause;
- (void)togglePlayPause;
- (void)next;
- (void)previous;
- (void)seekTo:(NSTimeInterval)seconds;
/// 按当前模式推进到下一首；自然播完时调用
- (void)advanceAutomatically;
- (void)setMode:(LLLPlayMode)mode;
- (void)cycleMode;
- (void)setDoubleSpeed:(BOOL)fast;
- (void)toggleDoubleSpeed;
- (void)setVolume:(float)volume;
- (void)stop;

#pragma mark - 进度锚点

/// 把底层播放器的当前时间同步给 LLLNowPlaying（岛和进度条靠它）
- (void)refreshElapsedAnchor;

@end

NS_ASSUME_NONNULL_END
