//
//  FoliaPayload.h
//  Folia 2.1.5 前端整包（29MB，压缩后 ~11MB）内嵌在 dylib 里，
//  首次进音乐页解到 Documents/LLL/folia/www。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 内嵌前端的版本号（对应 Folia.ipa 2.1.5）
extern NSString * const kFoliaBundleVersion;

/// 解包完成后的 www 目录；没解好返回 nil
NSString * _Nullable FoliaWebRoot(void);

/// 确保解包（后台队列，主线程回调）。已是最新版会立刻回调 YES
void FoliaEnsureReady(void (^ _Nullable done)(BOOL ok, NSString * _Nullable root, NSString * _Nullable err));

NS_ASSUME_NONNULL_END
