//
//  LLLCloudMusic.h
//  网易云音乐：扫码 / 手机号 / 手动 Cookie 三种登录，歌单、搜索、取流
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLCloudMusic : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL loggedIn;
@property (nonatomic, copy, readonly, nullable) NSString *nickname;
@property (nonatomic, assign, readonly) long long uid;

#pragma mark - 登录

- (void)startLoginWithQR:(void (^)(UIImage * _Nullable qr, NSString *status))progress
              completion:(void (^)(BOOL ok, NSString *msg))done;

- (void)loginWithPhone:(NSString *)phone
              password:(NSString *)password
            completion:(void (^)(BOOL ok, NSString *msg))done;

/// rawCookie 形如 "MUSIC_U=xxxx; __csrf=yyyy"
- (void)loginWithCookie:(NSString *)rawCookie
             completion:(void (^)(BOOL ok, NSString *msg))done;

- (void)cancelLogin;

#pragma mark - 内容

- (void)loadLikedSongs:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;
- (void)loadPlaylist:(NSNumber *)pid
                done:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;
- (void)searchSongs:(NSString *)keyword
               done:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;

/// 返回可直接喂给 AVPlayer 的地址
- (void)resolvePlayURL:(NSNumber *)songID done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

/// 异步取封面
- (void)loadArtwork:(nullable NSString *)url done:(void (^)(UIImage * _Nullable img))done;

- (void)logout;

@end

NS_ASSUME_NONNULL_END
