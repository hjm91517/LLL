//
//  ui/LLLMusicController.h  — 4.0
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

- (NSInteger)rowCount;
- (nullable NSDictionary *)rowInfoAt:(NSInteger)row;

- (void)playRow:(NSInteger)row;

- (void)setCloudQueueDirectly:(NSArray<NSDictionary *> *)songs;
- (void)playCloudRowDirectly:(NSInteger)row;

- (void)reloadLocal;
- (void)reloadCloudLiked;
- (void)reloadCloudDaily;

/// 把本地/云端队列写回宿主 MVC 的老数组（musicNames/musicPaths/cloudSongs），
/// 让 3.12 那套 UITableViewDataSource 与内核保持一致，不再错乱。
- (void)syncHostArrays;

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
