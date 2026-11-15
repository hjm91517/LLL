//
//  ui/LLLMusicController.h  — 4.0
//  音乐页数据/播放中枢：本地与网易云共用一套队列与播放内核。
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

- (void)bindHost:(MainViewController *)host;

- (LLLMusicSourceKind)sourceKind;
- (void)setSourceKind:(LLLMusicSourceKind)kind;

/// 表格数据源唯一取数入口，越界不可能
- (NSInteger)rowCount;
- (nullable NSDictionary *)rowInfoAt:(NSInteger)row;

- (void)playRow:(NSInteger)row;

/// 外部（登录面板/列表弹层）直接灌网易云队列，不动当前播放
- (void)setCloudQueueDirectly:(NSArray<NSDictionary *> *)songs;
/// 外部直接播网易云队列里的第 row 首
- (void)playCloudRowDirectly:(NSInteger)row;

- (void)reloadLocal;
- (void)reloadCloudLiked;
- (void)reloadCloudDaily;

- (void)togglePlayPause;
- (void)nextTrack;
- (void)previousTrack;
- (void)toggleMode;
- (void)toggleSpeed;
- (void)seekRatio:(float)ratio;

- (NSString *)cardTitle;
- (NSString *)cardSubtitle;
- (NSString *)cardTimeText;
- (BOOL)cardPlaying;
- (LLLPlayMode)playMode;
- (BOOL)isDoubleSpeed;

- (void)syncCloudQueueToCore;

@end

NS_ASSUME_NONNULL_END
