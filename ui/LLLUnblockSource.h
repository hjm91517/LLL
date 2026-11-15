//
//  ui/LLLUnblockSource.h
//  会员曲解锁通道：调用 UnblockNeteaseMusic 兼容的 /match 接口取第三方音源。
//
//  说明：网易的会员鉴权在服务端，客户端无法自行放行。
//  这条通道的工作方式是「换源」——按歌曲 ID 去第三方（酷我/咪咕等）找同名音频，
//  返回一个可直接播放的地址。所以需要一个可用的解锁服务：
//    · 自建 UnblockNeteaseMusic（推荐，稳定）
//    · 或填一个别人维护的公开实例
//  地址在「网易云面板 → 解锁音源」里填，存 NSUserDefaults: LLL.unblockBase
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLUnblockSource : NSObject

+ (instancetype)shared;

/// 用户配置的解锁服务根地址，例如 http://192.168.1.10:8080
@property (nonatomic, copy, readonly, nullable) NSString *baseURL;
- (void)setBaseURL:(nullable NSString *)url;
- (BOOL)isConfigured;

/// 按歌曲 ID 换源，回调主线程
- (void)resolveSongID:(NSNumber *)songID
             duration:(NSTimeInterval)duration
                 done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

/// 给 UI 用的一句话说明
+ (NSString *)helpText;

@end

NS_ASSUME_NONNULL_END
