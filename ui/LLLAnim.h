//
//  LLLAnim.h
//  统一动效基座
//
//  全工程共用一套曲线和时长，别再各写各的 UIView animateWithDuration。
//

#import <UIKit/UIKit.h>

#pragma mark - 时长

static const NSTimeInterval kLLLFast   = 0.16;
static const NSTimeInterval kLLLNormal = 0.30;
static const NSTimeInterval kLLLSlow   = 0.44;

#pragma mark - 弹簧

static inline void LLLSpring(NSTimeInterval duration, CGFloat damping, void (^anim)(void)) {
    [UIView animateWithDuration:duration
                          delay:0
         usingSpringWithDamping:damping
          initialSpringVelocity:0.55
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:anim
                     completion:nil];
}

static inline void LLLEase(NSTimeInterval duration, void (^anim)(void), void (^done)(BOOL)) {
    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseOut
                     animations:anim
                     completion:done];
}

#pragma mark - 按压反馈

static inline void LLLPressDown(UIView *v) {
    if (!v) return;
    LLLSpring(kLLLFast, 1.0, ^{ v.transform = CGAffineTransformMakeScale(0.955, 0.955); });
}

static inline void LLLPressUp(UIView *v) {
    if (!v) return;
    LLLSpring(kLLLFast, 0.72, ^{ v.transform = CGAffineTransformIdentity; });
}

// 点了直接回弹一下，用于「加入队列」这种瞬时反馈
static inline void LLLPop(UIView *v) {
    if (!v) return;
    [UIView animateWithDuration:0.12 animations:^{
        v.transform = CGAffineTransformMakeScale(1.22, 1.22);
    } completion:^(BOOL f) {
        LLLSpring(0.28, 0.55, ^{ v.transform = CGAffineTransformIdentity; });
    }];
}

#pragma mark - 入场 / 退场

static inline void LLLFadeIn(UIView *v, CGFloat dy) {
    if (!v) return;
    v.alpha = 0;
    v.transform = CGAffineTransformMakeTranslation(0, dy);
    LLLSpring(kLLLNormal, 0.88, ^{
        v.alpha = 1;
        v.transform = CGAffineTransformIdentity;
    });
}
