//
//  ui/LLLCloudLogin.h  — 4.0
//  网易云入口：四种登录方式 + 队列播放（全部转 LLLPlayerCore）
//
//  注意：所有方法都必须在 LLLCloudLogin.m 里有定义。
//  工程开着 -Werror -Wincomplete-implementation，声明了没实现就编不过。
//

#import "MainViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainViewController (CloudLogin)

/// 常驻宿主：灵动岛等"没有面板"的入口全部走这里
+ (MainViewController *)cloudHost;
+ (void)registerCloudHost:(MainViewController *)vc;

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
