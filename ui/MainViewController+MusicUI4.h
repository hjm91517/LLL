//
//  ui/MainViewController+MusicUI4.h
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (MusicUI4)

/// 在播放卡片右上角装"网易云登录"按钮（幂等）
- (void)lll4_installLoginButton;
- (void)lll4_tapCloudLogin;
- (void)lll4_refreshLoginButton;

@end

NS_ASSUME_NONNULL_END
