
#import <UIKit/UIKit.h>

@interface FloatingBallView : UIView
- (void)snap;
+ (CGPoint)loadPos:(CGSize)sz;
@end

void toggleMainWindow(void);
void showFloatingBall(void);
void handleOrientationChange(void);

void setPerformanceMonitorEnabled(BOOL enabled);
BOOL isPerformanceMonitorEnabled(void);

@interface CPUMonitorPanel : UIView
+ (instancetype)shared;
@end