//
//  ui/MainViewController+CloudLists4.h
//  列表方法声明。实现在 MainViewController+Features.m（3.12 就有）；
//  showDailyRecommend 的实现在 MainViewController+CloudDaily4.m。
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
