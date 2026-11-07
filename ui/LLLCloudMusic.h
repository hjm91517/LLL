//
//  LLLCloudMusic.h
//  网易云音乐：扫码登录 + 我喜欢的音乐 + 播放直链
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLCloudMusic : NSObject

+ (instancetype)shared;

@property (nonatomic, assign, readonly) BOOL loggedIn;
@property (nonatomic, copy, readonly, nullable) NSString *nickname;

/// 开始扫码登录。qr 回调在拿到二维码时触发一次；status 每次轮询状态变化都会调。
- (void)startLoginWithQR:(void (^)(UIImage * _Nullable qr, NSString *status))progress
              completion:(void (^)(BOOL ok, NSString *msg))done;

- (void)cancelLogin;

/// 拉「我喜欢的音乐」全部曲目：每项 {id, name, artist}
- (void)loadLikedSongs:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;

/// 拿播放直链（返回后可交给 AVPlayer）
- (void)resolvePlayURL:(NSNumber *)songID done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

- (void)logout;

@end

NS_ASSUME_NONNULL_END
