//
//  ui/MainViewController+MusicUI4.h
//
//  只声明「MusicUI4」这个分类里真正实现了的方法。
//  免登录面板的方法属于 (GuestPanel4)，声明在 MainViewController+GuestPanel4.h，
//  绝不能放进这里 —— 否则 -Wincomplete-implementation 会直接判错。
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (MusicUI4)

/// 播放卡片右上角：登录键 + 免登录键（幂等）
- (void)lll4_installLoginButton;
- (void)lll4_tapCloudLogin;
- (void)lll4_tapGuestMusic;
- (void)lll4_refreshLoginButton;

@end

NS_ASSUME_NONNULL_END
