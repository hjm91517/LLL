//
//  LLLWebLogin.h
//  官方网页登录：WKWebView 打开 music.163.com/login，登录成功后直接捞 MUSIC_U。
//  走网易自己的页面和 Cookie，不经过第三方接口，绕开"登录存在安全风险"那套风控。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LLLWebLogin : NSObject

/// 弹出网页登录；done 在主线程回调
+ (void)presentWithDone:(void (^ _Nullable)(BOOL ok, NSString * _Nullable msg))done;

+ (BOOL)isShowing;
+ (void)dismiss;

@end

NS_ASSUME_NONNULL_END
