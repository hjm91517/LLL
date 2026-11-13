//
//  LLLLaunchCard.h
//  启动卡片（圆环）与注入进度浮层（圆环 + 日志）。取代旧的滑动验证。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

void LLLShowLaunch(void);
void LLLLaunchSetProgress(CGFloat p, NSString * _Nullable status);

void LLLProgressShow(NSString *title);
void LLLProgressUpdate(NSString *counter);
void LLLProgressLine(NSString *line);
void LLLProgressHide(void);
void LLLProgressSetPercent(CGFloat p);
BOOL LLLProgressCancelled(void);

NS_ASSUME_NONNULL_END
