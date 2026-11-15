//
//  ui/LLLCloudLogin.h  — 4.0
//  网易云入口：四种登录方式 + 队列播放（全部转 LLLPlayerCore）
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLogin)

/// 常驻宿主：灵动岛等"没有面板"的入口全部走这里，保证回调有活着的接收者
+ (MainViewController *)cloudHost;
+ (void)registerCloudHost:(MainViewController *)vc;

/// 统一入口：未登录弹登录方式选择，已登录弹账号菜单
- (void)openCloudMusic;

/// 4.0：播放交给内核，这里只负责把人塞进队列再起播
- (void)playCloudSong:(NSDictionary *)song;
- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs;
- (void)cloudStep:(NSInteger)delta;

- (void)dismissCloudLoginCard;

#pragma mark - 登录方式

- (void)cloudLoginWeb;
- (void)doHarvestWebCookies;
- (void)cloudLoginQR;
- (void)cloudLoginPhone;
- (void)cloudLoginCookie;
- (void)doSendCode;
- (void)doPhoneLogin;
- (void)doCookieLogin;

- (void)loginHint:(NSString *)text;
- (void)loginDone:(BOOL)ok msg:(NSString *)msg;

@end

NS_ASSUME_NONNULL_END
