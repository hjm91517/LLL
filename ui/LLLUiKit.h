//
//  LLLUiKit.h
//  自制 UI 组件：启动动画 / 弹层 / 列表选择
//  全部不用 UIAlertController，全部走自己的 window，随便哪层都能弹。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 启动动画（旧，未使用）
void LLLShowSplash(void);

/// 启动序列：卡片 + 圆环进度（实现见 LLLLaunchCard.m）
void LLLShowLaunch(void);

/// 推进启动圆环；p >= 1 自动收起
void LLLLaunchSetProgress(CGFloat p, NSString * _Nullable status);

/// 通用弹层（底部卡片）。buttons 里每一项是一个按钮标题，回调给下标。
void LLLShowSheet(NSString *title,
                  NSString *message,
                  NSArray<NSString *> *buttons,
                  BOOL destructiveLast,
                  void (^ _Nullable cb)(NSInteger index));

/// 列表选择弹层（自带滚动，条数多了也不炸）
void LLLShowList(NSString *title,
                 NSString *message,
                 NSArray<NSString *> *items,
                 void (^ _Nullable cb)(NSInteger index));

/// 自定义卡片：自己往里塞控件，close 传 nil 表示不自动关
void LLLShowCustomCard(CGFloat width, CGFloat maxHeight,
                       void (^build)(UIView *card, void (^close)(void)));

/// 注入进度浮层：标题 + 计数 + 滚动日志
void LLLProgressShow(NSString *title);
void LLLProgressUpdate(NSString *counter);
void LLLProgressLine(NSString *line);
void LLLProgressHide(void);
void LLLProgressSetPercent(CGFloat p);
BOOL LLLProgressCancelled(void);

/// 轻提示（不用系统 HUD）
void LLLShowHUD(NSString *text, NSTimeInterval duration);

NS_ASSUME_NONNULL_END
