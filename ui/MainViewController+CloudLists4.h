//
//  ui/MainViewController+CloudLists4.h
//  列表方法声明。实现在 MainViewController+Features.m（3.12 就有）。
//  LLLCloudLogin.m 与 LLLGuestPanel.m 会调这些，所以单独抽个头。
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLists4)

- (void)showLikedSongs;
- (void)searchCloudMusic;
- (void)doCloudSearch;

/// 每日推荐：4.0 新增（原 +Features 里没有）
- (void)showDailyRecommend;

@end

NS_ASSUME_NONNULL_END
