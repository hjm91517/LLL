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

#pragma mark - 4.0 云端播放控制

/// 云端播放器是否活着
- (BOOL)cloudHasPlayer;

/// 播放/暂停：没在放就从当前队列接着放；队列空就提示
- (void)cloudTogglePlayPause;

/// 切歌，遵守 playMode（顺序到尾部停 / 列表循环回头 / 单曲重复 / 随机不重复）
- (void)cloudAdvance:(NSInteger)delta auto:(BOOL)isAuto;

/// AVPlayer 一首放完
- (void)cloudItemDidFinish:(NSNotification *)note;

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
