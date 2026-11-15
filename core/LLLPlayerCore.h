//
//  LLLPlayerCore.h
//  统一播放内核：本地音乐、本地视频、网易云共用一套状态机。
//
//  为什么要这个东西：
//    以前本地音乐走 MainViewController.audioPlayer/videoMusicPlayer，
//    网易云走 cloudPlayer，两套播放器 + 两套状态 + 两套通知，
//    结果就是 —— 切源跳页、卡片按钮只管本地、顺序播放对网易云完全失效。
//    现在所有播放请求都进这里，外面只读 core.state，按键只发命令。
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
    LLLPlayModeSequential = 0, ///< 顺序播放（列表尾回到列表头）
    LLLPlayModeSingleLoop,     ///< 单曲循环
    LLLPlayModeShuffle,        ///< 随机
};

/// 核心状态变化（标题 / 播放态 / 队列切换 / 进度锚点跳变）都发这条
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
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) NSTimeInterval elapsed;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign, readonly) NSUInteger queueCount;

/// 当前曲目在队列里的字典（网易云才有，本地为 nil）
@property (nonatomic, strong, readonly, nullable) NSDictionary *currentSong;

/// 本地视频画面（只有 LLLPlaySourceLocalVideo 时非空，供灵动岛/封面位挂 layer）
@property (nonatomic, strong, readonly, nullable) AVPlayer *videoPlayer;

#pragma mark - 队列

/// 本地队列：names 与 paths 一一对应，index 为起始曲目（-1 表示不自动播）
- (void)setLocalQueueNames:(NSArray<NSString *> *)names
                     paths:(NSArray<NSString *> *)paths
                  startAt:(NSInteger)index;

/// 网易云队列：songs 是 LLLCloudMusic.mapTracks 的输出（id/name/artist/pic/dur）
- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs startAt:(NSInteger)index;

/// 只更新队列不播放（切源时用，避免立刻出声）
- (void)setCloudQueueSilently:(NSArray<NSDictionary *> *)songs;

#pragma mark - 播放控制（卡片、灵动岛、系统遥控都走这些）

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

/// 让外部（灵动岛、进度条）能确认"当前播到哪"而不必自己算时钟
- (void)refreshElapsedAnchor;

@end

NS_ASSUME_NONNULL_END
