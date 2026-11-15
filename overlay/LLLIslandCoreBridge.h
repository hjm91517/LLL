//
//  LLLIslandCoreBridge.h
//  灵动岛 ↔ LLLPlayerCore 的桥：岛上所有按键都只调这里，不直接摸播放器。
//  这样「卡片按钮不管用 / 顺序播放失效」这类问题只可能出现在一处。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLIslandCoreBridge : NSObject

+ (instancetype)shared;

/// 装上命令桥（幂等）。核心状态变化会自动同步到 LLLNowPlaying。
- (void)install;

/// 岛上的播放/暂停
- (void)togglePlayPause;
- (void)playNext;
- (void)playPrevious;
- (void)seek:(NSTimeInterval)seconds;
- (void)setVolume:(float)volume;
/// 顺序 → 单曲 → 随机
- (void)cycleMode;
- (NSString *)modeLabel;
- (NSString *)modeSymbol;

/// 网易云登录入口回调（由 MainViewController 注册）
@property (nonatomic, copy, nullable) void (^openLoginHandler)(void);

@end

NS_ASSUME_NONNULL_END
