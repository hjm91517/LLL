//
//  ui/LLLCloudLogin.h  — 4.0
//  网易云入口：四种登录方式 + 队列播放（全部转 LLLPlayerCore）
//
//  说明：installNowPlayingBridge 是 3.12 留下的入口，LLLMusicIsland.m 里会调它。
//  4.0 把它转发到 LLLIslandCoreBridge，声明必须留在这里，否则岛那边编不过。
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

/// 4.0：播放交给内核，这里只负责把歌塞进队列再起播
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

#pragma mark - 列表

- (void)showLikedSongs;
- (void)showDailyRecommend;
- (void)searchCloudMusic;
- (void)doCloudSearch;

@end

NS_ASSUME_NONNULL_END
