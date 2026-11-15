//
//  LLLMusicController.h
//  音乐页控制器：本地 / 网易云两个数据源，共用一套播放卡片与一个播放内核。
//
//  解决的老问题：
//    · 切「本地/网易云」时分段控件和表格数组不同步 → numberOfRows 与 cellForRow 取到两套
//      数据，越界后 UIKit 直接把人踢到别的页。现在数组和数据源 index 绑死在一个枚举上。
//    · 卡片播放键以前只认 audioPlayer/videoMusicPlayer，网易云在放也点不动。
//      现在按键一律转 LLLPlayerCore，模式（顺序/单曲/随机）对两种源都生效。
//

#import <UIKit/UIKit.h>
#import "LLLPlayerCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LLLMusicSourceKind) {
    LLLMusicSourceKindLocal = 0,
    LLLMusicSourceKindCloud = 1,
};

@class MainViewController;

@interface LLLMusicController : NSObject

+ (instancetype)shared;

/// 宿主页面注册（音乐页的播放卡片、表格都在它身上）
- (void)bindHost:(MainViewController *)host;

- (LLLMusicSourceKind)sourceKind;
- (void)setSourceKind:(LLLMusicSourceKind)kind;

/// 当前数据源的行数 / 行内容，表格数据源只用这两个方法取值，杜绝越界
- (NSInteger)rowCount;
- (nullable NSDictionary *)rowInfoAt:(NSInteger)row;

/// 点某一行播放
- (void)playRow:(NSInteger)row;

/// 重新扫本地目录
- (void)reloadLocal;
/// 重新拉网易云「我喜欢的音乐」
- (void)reloadCloudLiked;
- (void)reloadCloudDaily;

/// 宿主在页面上按卡片键时调这些
- (void)togglePlayPause;
- (void)nextTrack;
- (void)previousTrack;
- (void)toggleMode;
- (void)toggleSpeed;
- (void)seekRatio:(float)ratio;

/// 卡片文案（标题/副标题/时间/模式图标）——宿主直接拿去刷 UI
- (NSString *)cardTitle;
- (NSString *)cardSubtitle;
- (NSString *)cardTimeText;
- (BOOL)cardPlaying;
- (LLLPlayMode)playMode;
- (BOOL)isDoubleSpeed;

/// 登录后把队列灌进内核（不动当前播放）
- (void)syncCloudQueueToCore;

@end

NS_ASSUME_NONNULL_END
