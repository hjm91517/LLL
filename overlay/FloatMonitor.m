
#import "FloatMonitor.h"
#import "MainViewController.h"
#import "BaseComponents.h"
#import <mach/mach.h>

static UIView * GetGameRootView(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.windowLevel >= UIWindowLevelAlert) continue;
                    if ([window isKindOfClass:[BaseOverlayWindow class]]) continue;
                    if (window.rootViewController && window.rootViewController.view.bounds.size.width > 100) {
                        return window.rootViewController.view;
                    }
                }
            }
        }
    }
    return nil;
}

static FloatingBallView *g_ballView = nil;

void showFloatingBall(void) {
    if (g_ballView) return;

    UIView *gameView = GetGameRootView();
    if (!gameView) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            showFloatingBall();
        });
        return;
    }

    CGSize size = CGSizeMake(70, 70);
    CGPoint center = [FloatingBallView loadPos:size];

    FloatingBallView *ball = [[FloatingBallView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    ball.center = center;

    ball.layer.zPosition = MAXFLOAT;
    [gameView addSubview:ball];
    g_ballView = ball;
}

void handleOrientationChange(void) {
    if (g_ballView) {
        [g_ballView snap];
    }
}

static UIView *g_mainContainer = nil;
static MainViewController *g_mainVC = nil;

void toggleMainWindow(void) {
    UIView *gameView = GetGameRootView();
    if (!gameView) return;

    BOOL visible = (g_mainContainer && !g_mainContainer.hidden && g_mainContainer.alpha > 0.01);

    if (visible) {

        if (g_mainVC) {
            if ([g_mainVC respondsToSelector:@selector(stopBgTimer)]) {
                [g_mainVC performSelector:@selector(stopBgTimer)];
            }
            if ([g_mainVC respondsToSelector:@selector(stopVideoBackground)]) {
                [g_mainVC performSelector:@selector(stopVideoBackground)];
            }
            if (g_mainVC.audioPlayer && g_mainVC.isPlaying) {
                [g_mainVC.audioPlayer play];
            }
            if (g_mainVC.videoMusicPlayer && g_mainVC.isPlaying) {
                [g_mainVC.videoMusicPlayer play];
            }
        }
        [UIView animateWithDuration:0.25 animations:^{
            g_mainContainer.alpha = 0;
        } completion:^(BOOL finished) {
            g_mainContainer.hidden = YES;
        }];
    } else {

        if (!g_mainVC) g_mainVC = [[MainViewController alloc] init];

        if (!g_mainContainer) {
            g_mainContainer = g_mainVC.view;
            g_mainContainer.frame = gameView.bounds;
            g_mainContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [gameView addSubview:g_mainContainer];
        }

        g_mainContainer.hidden = NO;
        g_mainContainer.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{
            g_mainContainer.alpha = 1;
        } completion:^(BOOL finished) {
            if (g_mainVC) {
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CustomBackgroundEnabled"]) {
                    if ([g_mainVC respondsToSelector:@selector(updateBackground)]) {
                        [g_mainVC performSelector:@selector(updateBackground)];
                    }
                    if (g_mainVC.bgMode == 1) {
                        if ([g_mainVC respondsToSelector:@selector(startBgTimerIfNeeded)]) {
                            [g_mainVC performSelector:@selector(startBgTimerIfNeeded)];
                        }
                    }
                }
                if (g_mainVC.audioPlayer && g_mainVC.isPlaying) {
                    [g_mainVC.audioPlayer pause];
                }
                if (g_mainVC.videoMusicPlayer && g_mainVC.isPlaying) {
                    [g_mainVC.videoMusicPlayer pause];
                }
            }
        }];

        if (g_ballView) {
            [gameView bringSubviewToFront:g_ballView];
        }
    }
}

@implementation FloatingBallView {
    UIButton *_btn;
    UIPanGestureRecognizer *_pan;
    CGPoint _lastCenter;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.autoresizingMask = UIViewAutoresizingNone;

        _btn = [UIButton buttonWithType:UIButtonTypeCustom];
        _btn.frame = self.bounds;
        _btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _btn.layer.cornerRadius = kFloatingBallRadius;
        _btn.clipsToBounds = YES;
        [_btn setImage:floatIcon() forState:UIControlStateNormal];
        _btn.imageView.contentMode = UIViewContentModeScaleAspectFill;
        _btn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.85];
        _btn.layer.shadowColor = UIColor.blackColor.CGColor;
        _btn.layer.shadowOffset = CGSizeMake(0, 4);
        _btn.layer.shadowRadius = 12;
        _btn.layer.shadowOpacity = 0.5;
        [_btn addTarget:self action:@selector(down) forControlEvents:UIControlEventTouchDown];
        [_btn addTarget:self action:@selector(up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [_btn addTarget:self action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_btn];

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        _pan.cancelsTouchesInView = NO;
        [self addGestureRecognizer:_pan];
    }
    return self;
}

- (void)down {
    [UIView animateWithDuration:0.12 animations:^{ _btn.transform = CGAffineTransformMakeScale(0.88, 0.88); }];
}

- (void)up {
    [UIView animateWithDuration:0.12 animations:^{ _btn.transform = CGAffineTransformIdentity; }];
}

- (void)tap { toggleMainWindow(); }

- (void)pan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    if (!superview) return;

    CGPoint translation = [gesture translationInView:superview];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _lastCenter = self.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint center = CGPointMake(_lastCenter.x + translation.x, _lastCenter.y + translation.y);
        UIEdgeInsets safe = UIEdgeInsetsZero;
        if (@available(iOS 11.0, *)) safe = superview.safeAreaInsets;
        CGRect bounds = superview.bounds;
        CGFloat halfW = self.bounds.size.width / 2, halfH = self.bounds.size.height / 2;
        center.x = MAX(halfW + 10, MIN(center.x, bounds.size.width - halfW - 10));
        center.y = MAX(safe.top + halfH + 10, MIN(center.y, bounds.size.height - safe.bottom - halfH - 10));
        self.center = center;
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self snap];
        [NSUserDefaults.standardUserDefaults setObject:@(self.center.x) forKey:@"FB_X"];
        [NSUserDefaults.standardUserDefaults setObject:@(self.center.y) forKey:@"FB_Y"];
    }
}

- (void)snap {
    UIView *superview = self.superview;
    if (!superview) return;
    CGRect bounds = superview.bounds;
    CGFloat targetX = (self.center.x < bounds.size.width / 2)
                        ? 10 + self.bounds.size.width / 2
                        : bounds.size.width - self.bounds.size.width / 2 - 10;
    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) safe = superview.safeAreaInsets;
    CGFloat targetY = MAX(safe.top + self.bounds.size.height / 2 + 10,
                          MIN(self.center.y, bounds.size.height - safe.bottom - self.bounds.size.height / 2 - 10));
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.center = CGPointMake(targetX, targetY);
    } completion:nil];
}

+ (CGPoint)loadPos:(CGSize)size {
    NSNumber *x = [NSUserDefaults.standardUserDefaults objectForKey:@"FB_X"];
    NSNumber *y = [NSUserDefaults.standardUserDefaults objectForKey:@"FB_Y"];
    UIView *gameView = GetGameRootView();
    if (!gameView) return CGPointMake(300, 200);

    CGRect bounds = gameView.bounds;
    CGPoint center = CGPointMake(x ? x.floatValue : bounds.size.width - size.width / 2 - 10,
                                  y ? y.floatValue : 200);
    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) safe = gameView.safeAreaInsets;
    center.x = MAX(size.width / 2 + 10, MIN(center.x, bounds.size.width - size.width / 2 - 10));
    center.y = MAX(size.height / 2 + safe.top + 10, MIN(center.y, bounds.size.height - size.height / 2 - safe.bottom - 10));
    return center;
}
@end

@interface MonitorGraphView : UIView
@property (strong) NSMutableArray *cpu, *fps, *mem;
@end

@implementation MonitorGraphView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _cpu = [NSMutableArray new];
        _fps = [NSMutableArray new];
        _mem = [NSMutableArray new];
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)addCPU:(float)c fps:(float)f mem:(float)m {
    [_cpu addObject:@(c)];
    [_fps addObject:@(f)];
    [_mem addObject:@(m)];
    if (_cpu.count > 60) {
        for (NSMutableArray *a in @[_cpu, _fps, _mem]) [a removeObjectAtIndex:0];
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = rect.size.width, h = rect.size.height, step = w / 59.0;
    if (w <= 0) return;
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1 alpha:0.06].CGColor);
    CGContextSetLineWidth(ctx, 0.5);
    for (int i = 1; i < 5; i++) {
        CGContextMoveToPoint(ctx, 0, h * i / 5.0);
        CGContextAddLineToPoint(ctx, w, h * i / 5.0);
    }
    CGContextStrokePath(ctx);
    [self drawArray:_cpu max:100 color:[UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:0.95] fill:0.10 step:step height:h];
    [self drawArray:_mem max:100 color:[UIColor colorWithRed:0.4 green:0.7 blue:1 alpha:0.90] fill:0.08 step:step height:h];
    [self drawArray:_fps max:60  color:[UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:0.90] fill:0.06 step:step height:h];
}

- (void)drawArray:(NSArray *)arr max:(CGFloat)max color:(UIColor *)color fill:(CGFloat)fillAlpha step:(CGFloat)step height:(CGFloat)h {
    NSInteger n = arr.count;
    if (n < 2) return;
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < n; i++) {
        CGFloat y = h - MIN([arr[i] floatValue], max) / max * h;
        if (i == 0) [path moveToPoint:CGPointMake(0, y)];
        else        [path addLineToPoint:CGPointMake(i * step, y)];
    }
    UIBezierPath *fillPath = [path copy];
    [fillPath addLineToPoint:CGPointMake((n-1)*step, h)];
    [fillPath addLineToPoint:CGPointMake(0, h)];
    [fillPath closePath];
    [[color colorWithAlphaComponent:fillAlpha] setFill];
    [fillPath fill];
    [color setStroke];
    path.lineWidth = 1.5;
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineCapStyle = kCGLineCapRound;
    [path stroke];
    CGFloat lastVal = MIN([arr.lastObject floatValue], max);
    [[UIBezierPath bezierPathWithArcCenter:CGPointMake((n-1)*step, h - lastVal/max*h) radius:2.5 startAngle:0 endAngle:M_PI*2 clockwise:YES] fill];
}
@end

@implementation CPUMonitorPanel {
    UILabel *_cpuL, *_fpsL, *_memL;
    MonitorGraphView *_graph;
    CADisplayLink *_link;
    NSTimer *_timer;
    NSTimeInterval _last;
    NSInteger _frames;
    float _fps, _cpu, _mem;
    BOOL _expanded;
    NSArray<UILabel*> *_names, *_vals;
    NSArray<UIView*> *_bars;
}

+ (instancetype)shared {
    static CPUMonitorPanel *panel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ panel = [[CPUMonitorPanel alloc] init]; });
    return panel;
}

- (instancetype)init {
    if (self = [super initWithFrame:CGRectMake(8, 50, 170, 70)]) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.82];
        self.layer.cornerRadius = 12;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
        self.layer.borderWidth = 0.5;

        UIView *handle = [[UIView alloc] initWithFrame:CGRectMake(75, 4, 20, 3)];
        handle.backgroundColor = [UIColor colorWithWhite:1 alpha:0.25];
        handle.layer.cornerRadius = 1.5;
        [self addSubview:handle];

        NSArray *titles = @[@"CPU", @"MEM", @"FPS"];
        NSArray *colors = @[[UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1],
                            [UIColor colorWithRed:0.4 green:0.7 blue:1 alpha:1],
                            [UIColor colorWithRed:0.3 green:0.85 blue:0.4 alpha:1]];
        NSMutableArray *nameArr = [NSMutableArray new];
        NSMutableArray *valArr  = [NSMutableArray new];
        NSMutableArray *barArr  = [NSMutableArray new];

        for (int i = 0; i < 3; i++) {
            UILabel *name = [[UILabel alloc] init];
            name.text = titles[i];
            name.font = [UIFont systemFontOfSize:8 weight:UIFontWeightMedium];
            name.textColor = [UIColor colorWithWhite:1 alpha:0.45];
            [self addSubview:name];
            [nameArr addObject:name];

            UIView *bar = [[UIView alloc] init];
            bar.backgroundColor = colors[i];
            bar.layer.cornerRadius = 1.5;
            [self addSubview:bar];
            [barArr addObject:bar];

            UILabel *val = [[UILabel alloc] init];
            val.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightBold];
            val.textColor = UIColor.whiteColor;
            val.text = @"--";
            [self addSubview:val];
            [valArr addObject:val];
        }
        _names = nameArr; _vals = valArr; _bars = barArr;
        _cpuL = valArr[0]; _memL = valArr[1]; _fpsL = valArr[2];

        _graph = [[MonitorGraphView alloc] init];
        [self addSubview:_graph];

        [self layoutSubviews];

        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)]];
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)]];

        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLink:)];
        [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(update) userInfo:nil repeats:YES];
        [self update];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    BOOL ex = w > 200;
    CGFloat xs[] = {ex ? 16.0 : 10.0, ex ? 116.0 : 65.0, ex ? 216.0 : 115.0};
    for (int i = 0; i < 3; i++) {
        _names[i].frame = CGRectMake(xs[i], 12, 30, 12);
        _bars[i].frame  = CGRectMake(xs[i], 25, 3, 14);
        _vals[i].frame  = CGRectMake(xs[i] + 6, 25, 58, 14);
    }
    _graph.frame = CGRectMake(6, 42, w - 12, ex ? 122 : 22);
}

- (void)pan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    if (!superview) return;
    CGPoint translation = [gesture translationInView:superview];
    CGRect frame = self.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    CGFloat margin = 4;
    frame.origin.x = MAX(margin, MIN(frame.origin.x, superview.bounds.size.width  - frame.size.width  - margin));
    frame.origin.y = MAX(margin, MIN(frame.origin.y, superview.bounds.size.height - frame.size.height - margin));
    self.frame = frame;
    [gesture setTranslation:CGPointZero inView:superview];
}

- (void)tap:(UITapGestureRecognizer *)gesture {
    _expanded = !_expanded;
    CGRect frame = self.frame;
    frame.size = _expanded ? CGSizeMake(300, 170) : CGSizeMake(170, 70);
    UIView *superview = self.superview;
    if (superview) {
        CGFloat m = 4;
        frame.origin.x = MAX(m, MIN(frame.origin.x, superview.bounds.size.width  - frame.size.width  - m));
        frame.origin.y = MAX(m, MIN(frame.origin.y, superview.bounds.size.height - frame.size.height - m));
    }
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.3 options:0 animations:^{
        self.frame = frame;
        [self layoutSubviews];
    } completion:nil];
}

- (void)displayLink:(CADisplayLink *)link {
    if (!_last) { _last = link.timestamp; return; }
    _frames++;
    NSTimeInterval elapsed = link.timestamp - _last;
    if (elapsed >= 1.0) {
        _fps = MIN(_frames / elapsed, 120);
        _frames = 0;
        _last = link.timestamp;
        [self refreshUI];
    }
}

- (void)update {
    _cpu = [self readCPU];
    _mem = [self readMEM];
    [self refreshUI];
}

- (void)refreshUI {
    _cpuL.text = [NSString stringWithFormat:@"%.1f%%", _cpu];
    _memL.text = [NSString stringWithFormat:@"%.1f%%", _mem];
    _fpsL.text = [NSString stringWithFormat:@"%.0f", _fps];
    _cpuL.textColor = _cpu > 80 ? [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1] : UIColor.whiteColor;
    _memL.textColor = _mem > 80 ? [UIColor colorWithRed:1 green:0.5 blue:0.2 alpha:1] : UIColor.whiteColor;
    _fpsL.textColor = _fps < 30 ? [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1] : UIColor.whiteColor;
    [_graph addCPU:_cpu fps:_fps mem:_mem];
}

- (float)readCPU {
    thread_array_t threads;
    mach_msg_type_number_t threadCount;
    if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) return 0;
    float total = 0;
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        thread_info_data_t info;
        mach_msg_type_number_t infoCount = THREAD_INFO_MAX;
        if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)info, &infoCount) == KERN_SUCCESS) {
            thread_basic_info_t basicInfo = (thread_basic_info_t)info;
            if (!(basicInfo->flags & TH_FLAGS_IDLE))
                total += (basicInfo->cpu_usage / (float)TH_USAGE_SCALE) * 100.0;
        }
    }
    vm_deallocate(mach_task_self(), (vm_offset_t)threads, threadCount * sizeof(thread_t));
    NSUInteger processorCount = NSProcessInfo.processInfo.processorCount;
    return processorCount > 0 ? MIN(total / processorCount, 100.0) : 0;
}

- (float)readMEM {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size) != KERN_SUCCESS) return 0;
    vm_size_t totalMemory = NSProcessInfo.processInfo.physicalMemory;
    return totalMemory > 0 ? (info.resident_size / (float)totalMemory) * 100.0 : 0;
}
@end

void setPerformanceMonitorEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"PerformanceMonitorEnabled"];
    if (enabled) {
        UIView *gameView = GetGameRootView();
        if (gameView) {
            CPUMonitorPanel *panel = [CPUMonitorPanel shared];
            if (!panel.superview) {
                panel.frame = CGRectMake(8, MAX(8, gameView.safeAreaInsets.top), 170, 70);
                [gameView addSubview:panel];
            }
            panel.hidden = NO;
        }
    } else {
        [CPUMonitorPanel shared].hidden = YES;
    }
}

BOOL isPerformanceMonitorEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"PerformanceMonitorEnabled"];
}

__attribute__((constructor)) static void MonitorInit() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (isPerformanceMonitorEnabled()) {
            UIView *gameView = GetGameRootView();
            if (gameView) {
                CPUMonitorPanel *panel = [CPUMonitorPanel shared];
                panel.frame = CGRectMake(8, MAX(8, gameView.safeAreaInsets.top), 170, 70);
                [gameView addSubview:panel];
            }
        }
    });
}