//
//  ui/LLLCloudLogin.h  — 4.0
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// 3.12 兼容入口。声明单独一个分类，与 LLLMusicIslandBridge4.m 的实现分类同名，
/// 否则 (CloudLogin) 会因“声明了却没实现”被判不完整（-Wincomplete-implementation）。
@interface MainViewController (NowPlayingBridgeCompat)
- (void)installNowPlayingBridge;
@end

@interface MainViewController (CloudLogin)

/// 常驻宿主
+ (MainViewController *)cloudHost;
+ (void)registerCloudHost:(MainViewController *)vc;

/// 统一入口：未登录 → 弹登录方式选择；已登录 → 弹账号菜单
- (void)openCloudMusic;
- (void)presentLoginChooser;

/// 播放交给内核
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
