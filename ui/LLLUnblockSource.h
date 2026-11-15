//
//  ui/LLLUnblockSource.h
//  会员曲换源：内置酷我通道（无需任何服务器），可选再叠加一个解锁服务。
//
//  实测（2026-11）：网易外链对会员曲只回 302/空体，明文 player/url 直接 url=null。
//  酷我 search + antiserver convert_url 能返回真实 mp3（206 audio/mpeg，ID3 头正常），
//  所以默认就走它。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLUnblockSource : NSObject

+ (instancetype)shared;

/// 可选的 UnblockNeteaseMusic 服务根地址（留空则只用内置酷我通道）
@property (nonatomic, copy, readonly, nullable) NSString *baseURL;
- (void)setBaseURL:(nullable NSString *)url;
- (BOOL)isConfigured;

/// 会员曲换源：优先外部解锁服务（若配置），否则/失败后走内置酷我
- (void)resolveSongID:(NSNumber *)songID
                 name:(nullable NSString *)name
               artist:(nullable NSString *)artist
             duration:(NSTimeInterval)duration
                 done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

+ (NSString *)helpText;

@end

NS_ASSUME_NONNULL_END
