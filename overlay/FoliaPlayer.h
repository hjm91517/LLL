//
//  FoliaPlayer.h
//  把 Folia 2.1.5 的前端整包塞进音乐页：WKWebView 跑 file:// 里的 SPA。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FoliaPlayer : NSObject

/// 已经建好并挂上去了（用于切页时判断要不要藏）
+ (BOOL)isLoaded;
+ (nullable UIView *)viewIfLoaded;

/// 挂到 host 上并按需解包 + 加载；重复调用只做显示
+ (void)loadInto:(UIView *)host completion:(void (^ _Nullable)(BOOL ok))done;

/// 切到别的页时藏起来（不销毁，播放不断）
+ (void)hide;

/// 重新加载页面
+ (void)reload;

@end

NS_ASSUME_NONNULL_END
