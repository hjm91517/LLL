//
//  ui/LLLCloudLogin.h  — 4.0
//  只留"别人要调"的接口。列表相关方法（showLikedSongs 等）
//  在 +Features 里已有实现，不在这里再声明，避免重复实现冲突。
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLogin)

/// 常驻宿主：灵动岛等"没有面板"的入口全部走这里
+ (MainViewController *)cloudHost;
+ (void)registerCloudHost:(MainViewController *)vc;

/// 3.12 兼容：命令桥入口（4.0 内部转 LLLIslandCoreBridge）
- (void)installNowPlayingBridge;

/// 统一入口：未登录 → 弹登录方式选择；已登录 → 弹账号菜单
- (void)openCloudMusic;
- (void)presentLoginChooser;

/// 4.0：播放交给内核
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
