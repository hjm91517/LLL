//
//  ui/LLLGuestMusic.h
//  免登录音源：不登网易云账号也能听歌。
//
//  原理：
//    · 公开搜索用 /api/search/get（不需要 Cookie，走网页 UA 即可）
//    · 取流优先 /song/media/outer/url?id=N.mp3（外链，免费曲直接出音频）
//      失败再试 /api/song/enhance/player/url（无 Cookie 时免费曲仍可用）
//    · 全程不发登录态 Cookie，也不碰会员接口，行为等同"游客"
//
//  这条通道下能听的是**免费曲目**；会员专享曲依旧会拿不到音源，
//  此时会给出一句明确提示，而不是静默失败。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLGuestMusic : NSObject

+ (instancetype)shared;

/// 是否启用免登录模式（默认 YES；UI 上的开关直接改这个）
@property (nonatomic, assign) BOOL enabled;

/// 明确提示文案：给"免登录能听什么"用
+ (NSString *)capabilityNote;

/// 公开搜索（不需要登录）
- (void)search:(NSString *)keyword
          done:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;

/// 热门歌单 / 榜单（不需要登录），用来填"随便听听"
- (void)loadTopList:(void (^)(NSArray<NSDictionary *> * _Nullable songs, NSString * _Nullable err))done;

/// 取流：多档回退，全部走游客路径
- (void)resolveStreamURL:(NSNumber *)songID
                duration:(NSTimeInterval)duration
                    done:(void (^)(NSURL * _Nullable url, NSString * _Nullable err))done;

@end

NS_ASSUME_NONNULL_END
