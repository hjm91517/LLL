//
//  MainViewController+CloudLists4.h
//
//  只声明 (CloudLists4) 里真正实现的 showDailyRecommend。
//
//  showLikedSongs / searchCloudMusic / doCloudSearch 的实现在
//  MainViewController+Features.m 的 (Features) 分类里，声明在 +Features.h。
//  在本分类里重复声明会让 -Wincomplete-implementation 判定 CloudDaily4.m 不完整。
//  这里顺带 import Features.h，调用方引本头即可拿到那几个方法。
//

#import "MainViewController.h"
#import "MainViewController+Features.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLists4)

/// 每日推荐：4.0 新增（实现在 MainViewController+CloudDaily4.m）
- (void)showDailyRecommend;

@end

NS_ASSUME_NONNULL_END
