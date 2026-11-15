//
//  LLLCloudMusic.h
//  网易云音乐：扫码 / 短信 / Cookie / 网页四种登录，歌单、搜索、取流
//  4.0：请求节流 + 失败退避 + 登录态保活，避免被风控判成机器
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 登录/请求类错误码，UI 层可以据此给不同提示
typedef NS_ENUM(NSInteger, LLLCloudError) {
    LLLCloudErrorNone = 0,
    LLLCloudErrorNetwork,
    LLLCloudErrorRisk,        ///< 触发风控（需要人机/验证码）
    LLLCloudErrorAuth,        ///< Cookie 失效
    LLLCloudErrorRateLimited, ///< 本地节流中，稍后再试
    LLLCloudErrorAPI,
};

@interface LLLCloudMusic : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL loggedIn;
@property (nonatomic, copy, readonly, nullable) NSString *nickname;
@property (nonatomic, assign, readonly) long long uid;
/// VIP 等级（0 非会员，>0 会员）
@property (nonatomic, assign, readonly) NSInteger vipType;

#pragma mark - 登录

- (void)startLoginWithQR:(void (^)(UIImage * _Nullable qr, NSString *status))progress
              completion:(void (^)(BOOL ok, NSString *msg))done;

/// 短信验证码登录（密码登录已被网易关闭：503 ursToken或验证码不存在）
- (void)requestSMSCode:(NSString *)phone done:(void (^)(BOOL ok, NSString *msg))done;
- (void)loginWithPhone:(NSString *)phone
               captcha:(NSString *)captcha
            completion:(void (^)(BOOL ok, NSString *msg))done;

/// rawCookie 形如 "MUSIC_U=xxxx; __csrf=yyyy"
- (void)loginWithCookie:(NSString *)rawCookie
             completion:(void (^)(BOOL ok, NSString *msg))done;

/// 网页登录内核直接灌进来的整组 Cookie（WKWebView 那边用）
- (void)adoptCookies:(NSArray<NSHTTPCookie *> *)cookies
          completion:(void (^)(BOOL ok, NSString *msg))done;

- (void)cancelLogin;

/// 登录态保活：启动时、每次进入网易云页时调一次；内部有节流，重复调用无害
- (void)refreshAccountIfNeeded:(void (^ _Nullable)(BOOL ok))done;

#pragma mark - 内容

- (void)loadLikedSongs:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;
- (void)loadPlaylist:(NSNumber *)pid
                done:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;
- (void)searchSongs:(NSString *)keyword
               done:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;

/// 每日推荐 / 心动模式，列表页补内容用
- (void)loadDailyRecommend:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;

/// 返回可直接喂给 AVPlayer 的地址（内部走 LLLCloudVIP 多档回退）
- (void)resolvePlayURL:(NSNumber *)songID done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

/// 异步取封面（走 LLLCloudVIP 的缓存）
- (void)loadArtwork:(nullable NSString *)url done:(void (^)(UIImage * _Nullable img))done;

- (void)logout;

@end

NS_ASSUME_NONNULL_END
