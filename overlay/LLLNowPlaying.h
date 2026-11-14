//
//  LLLNowPlaying.h
//  播放状态中枢：本地音乐 / 网易云都往这里写，灵动岛只从这里读。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LLLNPCommand) {
    LLLNPCommandTogglePlay = 0,
    LLLNPCommandNext,
    LLLNPCommandPrevious,
    LLLNPCommandSeek,
    LLLNPCommandVolume,   /// v2.2 灵动岛独立音量（0~1）
};

/// 状态变化（歌名 / 封面 / 播放态）时发出，userInfo 为空
extern NSString * const LLLNowPlayingDidChange;

@interface LLLNowPlaying : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *artist;
@property (nonatomic, strong, readonly, nullable) UIImage *artwork;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) BOOL playing;
@property (nonatomic, assign, readonly) BOOL hasTrack;

/// 已播秒数：播放中按时间插值，暂停就停在最后一次上报的值
@property (nonatomic, assign, readonly) NSTimeInterval elapsed;

/// 灵动岛上的按钮回调（主线程）
+ (void)setCommandHandler:(void (^ _Nullable)(LLLNPCommand cmd, double value))handler;

- (void)beginTrack:(nullable NSString *)title
            artist:(nullable NSString *)artist
           artwork:(nullable UIImage *)artwork
          duration:(NSTimeInterval)duration
           elapsed:(NSTimeInterval)elapsed;

- (void)updateElapsed:(NSTimeInterval)elapsed duration:(NSTimeInterval)duration;
- (void)setPlaying:(BOOL)playing;
- (void)updateArtwork:(nullable UIImage *)artwork;
- (void)stop;

/// 岛上的按钮最终回到这里，再转给 commandHandler
- (void)send:(LLLNPCommand)cmd value:(double)value;

@end

NS_ASSUME_NONNULL_END
