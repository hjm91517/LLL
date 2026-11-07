
#import "CacheCleaner.h"
#import "BaseComponents.h"
#import <UIKit/UIKit.h>

static UIImage* si(NSString *name) {
    if (@available(iOS 13.0, *)) {
        return [UIImage systemImageNamed:name];
    }
    return nil;
}

static void sd(NSString *dir, NSRegularExpression *regex, NSFileManager *fm,
               NSMutableArray *ok, NSMutableArray *bad, NSUInteger *found,
               NSString *excludeDir) {
    NSDirectoryEnumerator *e = [fm enumeratorAtPath:dir];
    for (NSString *p in e) {
        NSString *fp = [dir stringByAppendingPathComponent:p];
        if (excludeDir && [fp hasPrefix:excludeDir]) {
            BOOL exDir = NO;
            if ([fm fileExistsAtPath:fp isDirectory:&exDir] && exDir) [e skipDescendants];
            continue;
        }
        BOOL isDir;
        if ([fm fileExistsAtPath:fp isDirectory:&isDir] && !isDir) {
            NSString *n = p.lastPathComponent;
            if ([regex rangeOfFirstMatchInString:n options:0 range:NSMakeRange(0, n.length)].location != NSNotFound) {
                (*found)++;
                NSError *err = nil;
                if ([fm removeItemAtPath:fp error:&err])
                    [ok addObject:fp];
                else {
                    [bad addObject:fp];
                    NSLog(@"[CacheCleaner] 删除失败: %@, 错误: %@", fp, err.localizedDescription);
                }
            }
        }
    }
}

@interface KIV : UIView
@property (nonatomic, strong) UIView *capsule;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
- (void)updateStatus:(NSString *)title count:(NSUInteger)count isError:(BOOL)err;
- (void)present;
- (void)dismiss;
@end

@implementation KIV

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, 220, 38)];
    if (self) {
        self.backgroundColor = UIColor.clearColor;

        _capsule = [[UIView alloc] init];
        _capsule.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.75];
        _capsule.layer.cornerRadius = 19;
        _capsule.layer.masksToBounds = YES;
        _capsule.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_capsule];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [_capsule addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_capsule addSubview:_titleLabel];

        _countLabel = [[UILabel alloc] init];
        _countLabel.textColor = UIColor.whiteColor;
        _countLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        _countLabel.textAlignment = NSTextAlignmentRight;
        _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_capsule addSubview:_countLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_capsule.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_capsule.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_capsule.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_capsule.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [_iconView.leadingAnchor constraintEqualToAnchor:_capsule.leadingAnchor constant:12],
            [_iconView.centerYAnchor constraintEqualToAnchor:_capsule.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:20],
            [_iconView.heightAnchor constraintEqualToConstant:20],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:6],
            [_titleLabel.centerYAnchor constraintEqualToAnchor:_capsule.centerYAnchor],

            [_countLabel.trailingAnchor constraintEqualToAnchor:_capsule.trailingAnchor constant:-12],
            [_countLabel.centerYAnchor constraintEqualToAnchor:_capsule.centerYAnchor],
            [_countLabel.widthAnchor constraintGreaterThanOrEqualToConstant:40]
        ]];

        self.alpha = 0;
        self.transform = CGAffineTransformMakeScale(0.1, 0.1);
    }
    return self;
}

- (void)updateStatus:(NSString *)title count:(NSUInteger)count isError:(BOOL)err {
    _titleLabel.text = title;
    _countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)count];

    UIColor *tint;
    UIImage *img;
    if (err) {
        img = si(@"xmark.circle.fill");
        tint = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:1];
    } else if ([title containsString:@"清理"] || [title containsString:@"完毕"]) {
        img = si(@"checkmark.circle.fill");
        tint = [UIColor colorWithRed:0.2 green:0.9 blue:0.3 alpha:1];
    } else if ([title containsString:@"发现"]) {
        img = si(@"exclamationmark.circle.fill");
        tint = [UIColor colorWithRed:1 green:0.6 blue:0 alpha:1];
    } else {
        img = si(@"sparkles");
        tint = [UIColor colorWithWhite:0.7 alpha:1];
    }
    _iconView.image = img;
    _iconView.tintColor = tint;
    _countLabel.textColor = tint;
}

- (void)present {
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7
          initialSpringVelocity:0.5 options:0
                     animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1;
    } completion:nil];
}

- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.transform = CGAffineTransformMakeScale(0.1, 0.1);
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}
@end

@interface KLM : NSObject
@property (atomic, assign) BOOL run;
@property (atomic, assign) NSUInteger total;
@property (atomic, assign) BOOL busy;
@property (nonatomic, strong) NSTimer *cleanTimer;
@property (nonatomic, strong) KIV *dynamicIslandView;
+ (instancetype)shared;
- (void)start;
- (void)stop;
- (void)clean;
@end

@implementation KLM

+ (instancetype)shared {
    static KLM *m;
    static dispatch_once_t o;
    dispatch_once(&o, ^{ m = [[KLM alloc] init]; });
    return m;
}

- (void)start {
    if (!isCacheCleanerEnabled() || self.run) return;
    self.run = YES;
    self.total = 0;
    self.busy = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self showDynamicIslandWithTitle:@"监控中" count:0 isError:NO];
    });

    [self clean];

    __weak typeof(self) weakSelf = self;
    self.cleanTimer = [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(NSTimer *timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf clean];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.cleanTimer forMode:NSRunLoopCommonModes];
}

- (void)stop {
    self.run = NO;
    [self.cleanTimer invalidate];
    self.cleanTimer = nil;
    [self.dynamicIslandView dismiss];
    self.dynamicIslandView = nil;
}

- (void)clean {
    if (!self.run || self.busy) return;
    self.busy = YES;

    NSString *injectedDir = targetPath();
    if (injectedDir.length == 0) {
        injectedDir = nil;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fm = NSFileManager.defaultManager;
        NSMutableArray *ok = [NSMutableArray new];
        NSMutableArray *bad = [NSMutableArray new];
        NSUInteger found = 0;
        NSRegularExpression *regex = killenRegex();
        NSString *base = neteaseGameBasePath();

        for (NSString *sub in @[@"resource_packs", @"packcache", @"storge"]) {
            NSString *dir = [base stringByAppendingPathComponent:sub];
            if ([fm fileExistsAtPath:dir]) {
                sd(dir, regex, fm, ok, bad, &found, injectedDir);
            }
        }

        self.total += ok.count;

        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            if (found == 0) {
                [self showDynamicIslandWithTitle:@"无缓存" count:0 isError:NO];
            } else {
                [self showDynamicIslandWithTitle:@"发现缓存" count:found isError:NO];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (bad.count > 0) {
                        NSString *title = ok.count > 0 ?
                            [NSString stringWithFormat:@"部分失败 %lu/%lu", (unsigned long)bad.count, (unsigned long)(ok.count + bad.count)] :
                            @"删除失败";
                        [self showDynamicIslandWithTitle:title count:bad.count isError:YES];
                    } else if (ok.count > 0) {
                        [self showDynamicIslandWithTitle:@"清理完毕" count:ok.count isError:NO];
                    }
                });
            }
        });
    });
}

- (UIWindow *)keyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.windowLevel < UIWindowLevelAlert && window.rootViewController) {
                        return window;
                    }
                }
            }
        }
    }
    return nil;
}

- (void)showDynamicIslandWithTitle:(NSString *)title count:(NSUInteger)count isError:(BOOL)err {
    UIWindow *window = [self keyWindow];
    if (!window) return;

    if (!self.dynamicIslandView) {
        self.dynamicIslandView = [[KIV alloc] init];
        CGFloat topInset = window.safeAreaInsets.top > 0 ? window.safeAreaInsets.top : 20;
        CGFloat centerX = window.bounds.size.width / 2;
        self.dynamicIslandView.center = CGPointMake(centerX, topInset + 19);
        [window addSubview:self.dynamicIslandView];
        [self.dynamicIslandView present];
    }

    [self.dynamicIslandView updateStatus:title count:count isError:err];

    CGSize titleSize = [title sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]}];
    CGSize countSize = [[NSString stringWithFormat:@"%lu", (unsigned long)count] sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightBold]}];
    CGFloat width = 12 + 20 + 6 + titleSize.width + 8 + MAX(countSize.width, 40) + 12;
    width = MAX(160, MIN(width, window.bounds.size.width - 40));
    CGRect frame = self.dynamicIslandView.frame;
    frame.size.width = width;
    self.dynamicIslandView.frame = frame;

    CGFloat topInset = window.safeAreaInsets.top > 0 ? window.safeAreaInsets.top : 20;
    self.dynamicIslandView.center = CGPointMake(window.bounds.size.width / 2, topInset + 19);
}
@end

static void autoStartIfEnabled(void) {
    if (isCacheCleanerEnabled()) {
        [[KLM shared] start];
    }
}

__attribute__((constructor))
static void CacheCleanerInit(void) {
    // 20s：等宿主把资源仓库、UI 栈全部拉起来之后再动文件。
    // 启动阶段删 resource_packs 里的 ui json 会让运行中的包栈持有失效引用。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            autoStartIfEnabled();
        } @catch (NSException *e) {
            NSLog(@"[LLL] CacheCleaner 启动异常: %@", e.reason);
        }
    });
}

void setCacheCleanerEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"CacheCleanerEnabled"];
    if (enabled) {
        [[KLM shared] start];
    } else {
        [[KLM shared] stop];
    }
}

BOOL isCacheCleanerEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"CacheCleanerEnabled"];
}