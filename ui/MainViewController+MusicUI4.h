//
//  ui/MainViewController+MusicUI4.h
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (MusicUI4)

/// 播放卡片右上角：登录键 + 免登录键（幂等）
- (void)lll4_installLoginButton;
- (void)lll4_tapCloudLogin;
- (void)lll4_tapGuestMusic;
- (void)lll4_refreshLoginButton;

#pragma mark - 免登录面板（实现在 LLLGuestPanel.m）

- (void)lll4_openGuestMusic;
- (void)lll4_guestSearch;
- (void)lll4_doGuestSearch;
- (void)lll4_guestTopList;
- (void)lll4_presentGuestList:(NSArray<NSDictionary *> *)songs title:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
