//
//  ui/MainViewController+GuestPanel4.h
//  免登录面板 + 解锁音源配置
//

#import "MainViewController.h"
#import "MainViewController+Features.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (GuestPanel4)

- (void)lll4_openGuestMusic;
- (void)lll4_guestSearch;
- (void)lll4_doGuestSearch;
- (void)lll4_guestTopList;
- (void)lll4_presentGuestList:(NSArray<NSDictionary *> *)songs title:(NSString *)title;

/// 会员曲换源地址配置
- (void)lll4_setupUnblockSource;

@end

NS_ASSUME_NONNULL_END
