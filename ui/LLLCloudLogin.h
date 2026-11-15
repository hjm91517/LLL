//
//  LLLCloudLogin.h
//  网易云入口：三种登录方式 + 云端播放
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLogin)

/// 常驻宿主：灵动岛等"没有面板"的入口全部走这里，保证回调有活着的接收者
+ (MainViewController *)cloudHost;
+ (void)registerCloudHost:(MainViewController *)vc;

- (void)openCloudMusic;
- (void)playCloudSong:(NSDictionary *)song;
- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs;
- (void)installNowPlayingBridge;
- (void)cloudStep:(NSInteger)delta;
- (void)dismissCloudLoginCard;

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
