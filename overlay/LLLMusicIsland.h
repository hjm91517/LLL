//
//  LLLMusicIsland.h
//  顶部灵动岛胶囊：播放音乐时常驻，显示歌名 + 动态波形
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLMusicIsland : NSObject

/// 更新胶囊内容。playing=NO 时 2 秒后自动收起。
+ (void)updateTitle:(nullable NSString *)title playing:(BOOL)playing;

/// 立即收起
+ (void)hide;

/// 点胶囊时回调（用来切播放/暂停）
+ (void)setTapHandler:(nullable void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
