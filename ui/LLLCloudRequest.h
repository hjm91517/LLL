//
//  LLLCloudRequest.h
//  网易云请求层：本地节流 + 指数退避 + 风控识别 + 指纹伪装头。
//
//  风控会长什么样：
//    - 同一 IP 短时间大量 api 请求 → 返回 460(篡改)/503(权限)/-460
//    - 登录接口不带客户端标识 → 401 "无权限访问. ENC"
//    - Cookie 里缺 os/appver → 业务直接降级成试听
//  所以这一层干三件事：控速、装客户端、识别风控码并让上层提示换路子。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LLLReqKind) {
    LLLReqKindRead = 0,   ///< 歌单/搜索这类读接口，2 次/秒
    LLLReqKindPlay,       ///< 取流，4 次/秒（切歌频繁）
    LLLReqKindWrite,      ///< 登录/验证码这类敏感接口，1 次/5 秒
};

@interface LLLCloudRequest : NSObject

+ (instancetype)shared;

/// 统一出口。params/body 二选一；返回解析后的 JSON。
- (void)GET:(NSString *)path
     params:(nullable NSDictionary<NSString *, NSString *> *)params
       kind:(LLLReqKind)kind
    retries:(NSInteger)retries
       done:(void (^)(id _Nullable json, NSInteger statusCode, NSError * _Nullable err))done;

- (void)POSTForm:(NSString *)path
            body:(NSString *)body
            kind:(LLLReqKind)kind
         retries:(NSInteger)retries
            done:(void (^)(id _Nullable json, NSInteger statusCode, NSError * _Nullable err))done;

/// 风控码判定，上层据此决定"是否提示用户换登录方式"
+ (BOOL)isRiskCode:(NSInteger)code;
+ (NSString *)friendlyMessageForCode:(NSInteger)code message:(nullable NSString *)msg;

@property (nonatomic, copy, readonly) NSString *cookieHeader;
/// 手动把 cookie 灌进来（网页登录收尾用）
- (void)ingestCookieString:(NSString *)raw;

@end

NS_ASSUME_NONNULL_END
