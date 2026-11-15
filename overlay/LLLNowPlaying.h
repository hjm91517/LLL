//
//  LLLNowPlaying.h
//  播放状态中枢：本地音乐 / 网易云都往这里写，灵动岛只从这里读。
//  4.0：新增 source 标记与 artworkURL，让灵动岛能确认封面是不是"当前这首"的。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LLLNPCommand) {
    LLLNPCommandTogglePlay = 0,
    LLLNPCommandNext,
    LLLNPCommandPrevious,
    LLLNPCommandSeek,
    LLLNPCommandVolume,
    LLLNPCommandCycleMode,   ///< 4.0：岛上直接切顺序/单曲/随机
};

/// 状态变化（歌名 / 封面 / 播放态）时发出，userInfo 为空
extern NSString * const LLLNowPlayingDidChange;

@interface LLLNowPlaying : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly, nullable) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *artist;
@property (nonatomic, strong, readonly, nullable) UIImage *artwork;
/// 4.0：封面来源地址（网易云曲图），用来判断"图是不是这首歌的"
@property (nonatomic, copy, readonly, nullable) NSString *artworkURL;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) BOOL playing;
@property (nonatomic, assign, readonly) BOOL hasTrack;
/// 4.0：YES 表示当前是网易云曲目（岛上据此切图标/文案）
@property (nonatomic, assign, readonly) BOOL cloudSource;

/// 已播秒数：播放中按时间插值，暂停就停在最后一次上报的值
@property (nonatomic, assign, readonly) NSTimeInterval elapsed;

/// 灵动岛上的按钮回调（主线程）
+ (void)setCommandHandler:(void (^ _Nullable)(LLLNPCommand cmd, double value))handler;

- (void)beginTrack:(nullable NSString *)title
            artist:(nullable NSString *)artist
           artwork:(nullable UIImage *)artwork
          duration:(NSTimeInterval)duration
           elapsed:(NSTimeInterval)elapsed;

/// 4.0：带封面地址与来源的完整上报
- (void)beginTrack:(nullable NSString *)title
            artist:(nullable NSString *)artist
           artwork:(nullable UIImage *)artwork
        artworkURL:(nullable NSString *)artworkURL
          duration:(NSTimeInterval)duration
           elapsed:(NSTimeInterval)elapsed
             cloud:(BOOL)cloud;

- (void)updateElapsed:(NSTimeInterval)elapsed duration:(NSTimeInterval)duration;
- (void)setPlaying:(BOOL)playing;
- (void)updateArtwork:(nullable UIImage *)artwork;
- (void)updateArtwork:(nullable UIImage *)artwork url:(nullable NSString *)url;
- (void)stop;

/// 岛上的按钮最终回到这里，再转给 commandHandler
- (void)send:(LLLNPCommand)cmd value:(double)value;

@end

NS_ASSUME_NONNULL_END
