//
//  LLLCloudLogin.h
//  网易云入口：三种登录方式 + 云端播放
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLogin)

- (void)openCloudMusic;
- (void)playCloudSong:(NSDictionary *)song;
- (void)setCloudQueue:(NSArray<NSDictionary *> *)songs;
- (void)installNowPlayingBridge;
- (void)cloudStep:(NSInteger)delta;
- (void)dismissCloudLoginCard;

- (void)cloudLoginQR;
- (void)cloudLoginPhone;
- (void)cloudLoginCookie;
- (void)doPhoneLogin;
- (void)doCookieLogin;
- (void)loginHint:(NSString *)text;
- (void)loginDone:(BOOL)ok msg:(NSString *)msg;

@end

NS_ASSUME_NONNULL_END
