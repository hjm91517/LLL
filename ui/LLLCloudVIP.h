//
//  LLLCloudVIP.h
//  网易云音源通道：eapi 客户端接口多档回退 + 封面缓存。
//
//  取流顺序（前面的拿不到才试后面的，全程带登录态 Cookie）：
//    1) /api/song/enhance/player/url/v1   level=exhigh/lossless  —— 客户端音质档，会员曲直出
//    2) /api/song/enhance/download/url/v1 level=exhigh            —— 下载通道，权限位和播放通道不同
//    3) /api/song/enhance/player/url      br=320000              —— 老版明文通道兜底
//    4) /song/media/outer/url?id=xxx.mp3                          —— 外链兜底（免费曲可用）
//
//  每一档拿到返回都是先做 HEAD 探测：302 到 403 的假地址会被 AVPlayer 静默吞掉，
//  只有真给 200/206 + audio 的地址才算数。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLCloudVIP : NSObject

+ (instancetype)shared;

/// 已登录时返回 YES（有 MUSIC_U 且账号信息能拿到）
@property (nonatomic, readonly) BOOL hasLogin;

/// 解析可播地址，内部多档回退；回调在主线程
- (void)resolveStreamURL:(NSNumber *)songID
                duration:(NSTimeInterval)duration
                    done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

/// 封面：带内存 LRU + 磁盘缓存，重复取不会二次下载
- (nullable UIImage *)cachedArtwork:(NSString *)urlString;
- (void)artworkFor:(NSString *)urlString done:(void (^)(UIImage * _Nullable img))done;

/// 把一批歌曲按 VIP 可用性打标（song[@"vip"] = @YES/@NO），列表页可以用它画小标
- (void)annotateVIPStatus:(NSArray<NSDictionary *> *)songs
                     done:(void (^)(NSArray<NSDictionary *> *songs))done;

- (void)clearArtworkCache;

@end

NS_ASSUME_NONNULL_END
